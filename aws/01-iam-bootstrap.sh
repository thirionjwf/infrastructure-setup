#!/bin/bash

set -e          # Exit on any error
set -o pipefail # Catch errors in piped commands

# Path to config.yaml
CONFIG_FILE="config.yaml"

# Extract AWS profile and region settings from config.yaml via environment variables
PROFILE=$(yq eval '.preferences_and_settings.default_profile // "default"' "$CONFIG_FILE")
PROFILE="default" # Use another profile (for a user with AdministratorAccess)
REGION=$(yq eval '.preferences_and_settings.default_region // "us-east-1"' "$CONFIG_FILE")

if [ -z "$PROFILE" ] || [ -z "$REGION" ]; then
  echo "PROFILE or REGION not set in config.yaml. Please verify the configuration."
  exit 1
fi

# Define the path to the parameters.json file
PARAMETERS_FILE="parameters-1.json"

# Generate the parameters-1.json file
cat <<EOF >$PARAMETERS_FILE
[
  {
    "ParameterKey": "IAMUserName",
    "ParameterValue": "$(yq eval '.iam.cloudformation_user.user_name // "cloudformation"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "IAMGroupName",
    "ParameterValue": "$(yq eval '.iam.cloudformation_user.group_name // "infrastructure"' "$CONFIG_FILE")"
  }
]
EOF

# Check if parameters-1.json was created successfully
if [ -f "$PARAMETERS_FILE" ]; then
  echo "$PARAMETERS_FILE has been created successfully."
else
  echo "Error creating $PARAMETERS_FILE.json"
  exit 1
fi

# Create IAM Bootstrap Stack
echo "Creating IAM Bootstrap stack..."
aws cloudformation create-stack \
  --stack-name iam-bootstrap \
  --template-body file://aws/01-iam-cloudformation-user.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters file://$PARAMETERS_FILE \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >create-stack-output.log

# Check if the stack creation command was successful
if [ $? -ne 0 ]; then
  echo "Failed to create the stack. Check create-stack-output.log for details."
  exit 1
fi

echo "Waiting for stack creation to complete..."

# Wait for the stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name iam-bootstrap \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >wait-output.log

# Check if the stack creation was successful
if [ $? -eq 0 ]; then
  echo "Stack creation complete. Proceeding to the next steps."
else
  echo "Stack creation failed. Please check the CloudFormation console for errors."
  exit 1
fi

# Display access keys
echo "Fetching stack outputs..."
aws cloudformation describe-stacks \
  --stack-name iam-bootstrap \
  --query "Stacks[0].Outputs" \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >describe-stack-output.log

echo "Stack outputs saved to describe-stack-output.log."

PROFILE_USER=$(yq eval '.preferences_and_settings.default_profile // "default"' "$CONFIG_FILE")

# Configure AWS CLI with the new IAM user
STACK_NAME="iam-bootstrap"
REGION="us-east-1" # Adjust as needed

# Get the CloudFormation stack outputs
ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='AccessKeyId'].OutputValue" --output text --region "$REGION" --profile "$PROFILE")
SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='SecretAccessKey'].OutputValue" --output text --region "$REGION" --profile "$PROFILE")

# Configure the AWS CLI with the retrieved keys
aws configure set aws_access_key_id "$ACCESS_KEY_ID" --region "$REGION" --profile "$PROFILE_USER"
aws configure set aws_secret_access_key "$SECRET_ACCESS_KEY" --region "$REGION" --profile "$PROFILE_USER"
aws configure set output json --region "$REGION" --profile "$PROFILE_USER"
echo "AWS CLI configured successfully with the CloudFormation credentials."
