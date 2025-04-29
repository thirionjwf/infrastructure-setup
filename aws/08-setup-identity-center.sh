#!/bin/bash

set -e          # Exit on any error
set -o pipefail # Catch errors in piped commands

# Path to config.yaml
CONFIG_FILE="config.yaml"

# Extract AWS profile and region settings from config.yaml via environment variables
PROFILE=$(yq eval '.preferences_and_settings.default_profile // "default"' "$CONFIG_FILE")
REGION=$(yq eval '.preferences_and_settings.default_region // "us-east-1"' "$CONFIG_FILE")

if [ -z "$PROFILE" ] || [ -z "$REGION" ]; then
  echo "PROFILE or REGION not set in config.yaml. Please verify the configuration."
  exit 1
fi

# Define the path to the parameters.json file
PARAMETERS_FILE="parameters-8.json"

# Step 8.1: Enable SSO Service Access in AWS Organizations
echo "Enabling trusted service access for SSO..."
aws organizations enable-aws-service-access --service-principal sso.amazonaws.com --region "$REGION" --profile "$PROFILE" || echo "Service access already enabled."

# Step 8.2: (Manual step) Go to Console and Enable IAM Identity Center
echo "IMPORTANT: Please go to the AWS Console > IAM Identity Center and click 'Enable'."
echo "After enabling, run the following to fetch your Instance ARN and Identity Store ID. Press Enter to continue."
read
aws sso-admin list-instances --region "$REGION" --profile "$PROFILE" --output text >sso-admin-instances.log

# Get the SSO Instance ARN (assumes you have only 1 SSO instance)
SSO_INSTANCE_ARN=$(aws sso-admin list-instances --query "Instances[0].InstanceArn" --region "$REGION" --profile "$PROFILE" --output text)

# Get the Identity Store ID (linked to the SSO Instance)
IDENTITY_STORE_ID=$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --region "$REGION" --profile "$PROFILE" --output text)

# Debug info (optional)
echo "Detected SSO Instance ARN: $SSO_INSTANCE_ARN"
echo "Detected Identity Store ID: $IDENTITY_STORE_ID"

# Generate parameters-8.json
cat <<EOF >$PARAMETERS_FILE
[
  {
    "ParameterKey": "AccountId",
    "ParameterValue": "$(aws organizations describe-organization --query "Organization.MasterAccountId" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "AccountIdDEV",
    "ParameterValue": "$(aws organizations list-accounts --query "Accounts[?Name=='DEV'].Id" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "AccountIdPRD",
    "ParameterValue": "$(aws organizations list-accounts --query "Accounts[?Name=='PRD'].Id" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "AccountIdQA",
    "ParameterValue": "$(aws organizations list-accounts --query "Accounts[?Name=='QA'].Id" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "AccountIdSHD",
    "ParameterValue": "$(aws organizations list-accounts --query "Accounts[?Name=='SHD'].Id" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "IdentityStoreId",
    "ParameterValue": "$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "InstanceArn",
    "ParameterValue": "$(aws sso-admin list-instances --query "Instances[0].InstanceArn" --region "$REGION" --profile "$PROFILE" --output text)"
  },
  {
    "ParameterKey": "AdministratorAccessPermissionSetName",
    "ParameterValue": "$(yq eval '.iam.permission_sets.administrator_access // "AdministratorAccess"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "PowerUserAccessPermissionSetName",
    "ParameterValue": "$(yq eval '.iam.permission_sets.power_user_access // "PowerUserAccess"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "BillingAccessPermissionSetName",
    "ParameterValue": "$(yq eval '.iam.permission_sets.billing_access // "Billing"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "ReadOnlyAccessPermissionSetName",
    "ParameterValue": "$(yq eval '.iam.permission_sets.read_only_access // "ReadOnlyAccess"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "AdminGroupName",
    "ParameterValue": "$(yq eval '.iam.groups.admin // "admin"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "DeveloperGroupName",
    "ParameterValue": "$(yq eval '.iam.groups.developers // "developers"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "BillingGroupName",
    "ParameterValue": "$(yq eval '.iam.groups.billing // "billing"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "ReadOnlyGroupName",
    "ParameterValue": "$(yq eval '.iam.groups.readonly // "readonly"' "$CONFIG_FILE")"
  }
]
EOF

# Check if parameters-8.json was created successfully
if [ -f "$PARAMETERS_FILE" ]; then
  echo "$PARAMETERS_FILE has been created successfully."
else
  echo "Error creating $PARAMETERS_FILE"
  exit 1
fi

# Deploy the AWS Organization StackSet for Step 7
aws cloudformation create-stack \
  --stack-name identity-center \
  --template-body file://aws/08-identity-center.yaml \
  --parameters file://$PARAMETERS_FILE \
  --region "$REGION" \
  --profile "$PROFILE" \
  >create-stack-output.log

echo "Waiting for stack creation to complete..."

# Wait for the stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name identity-center \
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
