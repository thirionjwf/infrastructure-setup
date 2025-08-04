#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
TF_STATE_PREFIX="terraform-state-"
TF_VARS_FILE="terraform.tfvars"
TF_VARS_FILE_TMP="${TF_VARS_FILE}.tmp"

# === Helper to read value from tfvars ===
read_tfvar() {
    grep "^$1" "$TF_VARS_FILE" | cut -d'=' -f2 | tr -d ' "'
}

AWS_PROFILE=$(read_tfvar "aws_profile")
AWS_REGION=$(read_tfvar "aws_region")
TF_STATE_S3_BUCKET=$(read_tfvar "tf_state_s3_bucket")
TF_LOCKS_DYNAMODB_TABLE=$(read_tfvar "tf_locks_dynamodb_table")

echo "AWS Profile: $AWS_PROFILE"
echo "AWS Region: $AWS_REGION"
echo "Terraform S3 Bucket: $TF_STATE_S3_BUCKET"
echo "DynamoDB Lock Table: $TF_LOCKS_DYNAMODB_TABLE"

# === Check for existing S3 bucket ===
BUCKET_NAME=""
EXISTING_BUCKETS=$(aws s3api list-buckets --profile "$AWS_PROFILE" --query "Buckets[].Name" --output text --no-verify-ssl)
for BUCKET in $EXISTING_BUCKETS; do
    echo "Checking bucket: $BUCKET"
    if [[ "$BUCKET" == "$TF_STATE_S3_BUCKET"* ]]; then
        BUCKET_NAME="$BUCKET"
        break
    fi
done

# === Generate random bucket if not found ===
if [[ -z "$BUCKET_NAME" ]]; then
    CHARSET="abcdefghijklmnopqrstuvwxyz0123456789"
    BUCKET_NAME="$TF_STATE_PREFIX"
    for i in {1..8}; do
        INDEX=$(( RANDOM % ${#CHARSET} ))
        BUCKET_NAME="$BUCKET_NAME${CHARSET:$INDEX:1}"
    done

    echo "Creating new S3 bucket: $BUCKET_NAME"

    ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$AWS_REGION" --query Account --output text --no-verify-ssl)

    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION" --profile "$AWS_PROFILE" --no-verify-ssl
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" --region "$AWS_REGION" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --profile "$AWS_PROFILE" --no-verify-ssl
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION" --versioning-configuration Status=Enabled --profile "$AWS_PROFILE" --no-verify-ssl

    cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RestrictAccessToAccount",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$ACCOUNT_ID:root"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    }
  ]
}
EOF

    aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --region "$AWS_REGION" --policy file://bucket-policy.json --profile "$AWS_PROFILE" --no-verify-ssl
    rm bucket-policy.json

    echo "Replacing $TF_STATE_S3_BUCKET in tfvars with: $BUCKET_NAME"
    sed "s/$TF_STATE_S3_BUCKET/$BUCKET_NAME/g" "$TF_VARS_FILE" > "$TF_VARS_FILE_TMP"
    mv "$TF_VARS_FILE_TMP" "$TF_VARS_FILE"
    echo "Updated $TF_VARS_FILE with S3 bucket: $BUCKET_NAME"
fi

# === Create DynamoDB table ===
if aws dynamodb describe-table --table-name "$TF_LOCKS_DYNAMODB_TABLE" --region "$AWS_REGION" --profile "$AWS_PROFILE" > /dev/null 2>&1; then
    echo "DynamoDB table "$TF_LOCKS_DYNAMODB_TABLE" already exists."
else
    echo "Creating DynamoDB table "$TF_LOCKS_DYNAMODB_TABLE"..."
    aws dynamodb create-table         --table-name "$TF_LOCKS_DYNAMODB_TABLE"         --attribute-definitions AttributeName=LockID,AttributeType=S         --key-schema AttributeName=LockID,KeyType=HASH         --billing-mode PAY_PER_REQUEST         --region "$AWS_REGION"         --profile "$AWS_PROFILE"         --no-verify-ssl
fi

# === Enable SSO access ===
echo "Enabling trusted service access for SSO..."
aws organizations enable-aws-service-access --service-principal sso.amazonaws.com --region "$AWS_REGION" --profile "$AWS_PROFILE" || echo "Service access already enabled."

# === Write management account ID to tfvars ===
MGMT_ID=$(aws organizations describe-organization --query "Organization.MasterAccountId" --output text --profile "$AWS_PROFILE" --no-verify-ssl)
grep -q "management_account_id" "$TF_VARS_FILE" || echo "management_account_id = "$MGMT_ID"" >> "$TF_VARS_FILE"
echo "Management Account ID: $MGMT_ID"

echo "IMPORTANT: Please go to the AWS Console - IAM Identity Center and click 'Enable'"
read -p "Press Enter once you have enabled IAM Identity Center..."

# === Get Identity Store ID ===
IDENTITY_STORE_ID=$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text --profile "$AWS_PROFILE" --no-verify-ssl)
if [[ -z "$IDENTITY_STORE_ID" ]]; then
    echo "No Identity Store found. Please ensure IAM Identity Center is enabled."
    exit 1
fi
grep -q "identity_store_id" "$TF_VARS_FILE" || echo "identity_store_id = "$IDENTITY_STORE_ID"" >> "$TF_VARS_FILE"

# === Write backend.tf ===
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "global/sso/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$TF_LOCKS_DYNAMODB_TABLE"
    encrypt        = true
  }
}
EOF

# === Enable SCP ===
ROOT_ID=$(aws organizations list-roots --query "Roots[0].Id" --output text --profile "$AWS_PROFILE")
echo "Root ID found: $ROOT_ID"
echo "Enabling SERVICE_CONTROL_POLICY on root ID $ROOT_ID..."
aws organizations enable-policy-type --root-id "$ROOT_ID" --policy-type SERVICE_CONTROL_POLICY --profile "$AWS_PROFILE" && echo "✅ SCP policy type enabled successfully." || echo "⚠️ Could not enable SCP. It may already be enabled or an error occurred."

echo "Initialization complete."
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $TF_LOCKS_DYNAMODB_TABLE"
