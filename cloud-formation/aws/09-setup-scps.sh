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

ROOT_ID=$(aws organizations list-roots --query "Roots[0].Id" --region "$REGION" --profile "$PROFILE" --output text)
SANDBOX_OUID=$(aws organizations list-organizational-units-for-parent --parent-id $ROOT_ID \
  --query "OrganizationalUnits[?Name=='Sandbox'].Id" --region "$REGION" --profile "$PROFILE" --output text)
WORKLOADS_OUID=$(aws organizations list-organizational-units-for-parent --parent-id $ROOT_ID \
  --query "OrganizationalUnits[?Name=='Sandbox'].Id" --region "$REGION" --profile "$PROFILE" --output text)

# Define the path to the parameters.json file
PARAMETERS_FILE="parameters-9.json"

cat <<EOF >$PARAMETERS_FILE
[
  {
    "ParameterKey": "ApprovedRegions",
    "ParameterValue": "$(yq eval '.scp.deny_non_approved_regions.approved_regions | join(",") // "us-east-1"' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "DenyRegionsPolicyName",
    "ParameterValue": "DenyNonApprovedRegions"
  },
  {
    "ParameterKey": "DenyRegionsPolicyDescription",
    "ParameterValue": "Deny actions outside approved regions"
  },
  {
    "ParameterKey": "ForceMFAUsagePolicyName",
    "ParameterValue": "ForceMFAUsage"
  },
  {
    "ParameterKey": "ForceMFAUsagePolicyDescription",
    "ParameterValue": "Force users to authenticate with MFA"
  }
]
EOF

# Check if parameters-9.json was created successfully
if [ -f "$PARAMETERS_FILE" ]; then
  echo "$PARAMETERS_FILE has been created successfully."
else
  echo "Error creating $PARAMETERS_FILE"
  exit 1
fi

# Deploy the AWS Organization StackSet for Step 7
aws cloudformation create-stack \
  --stack-name scps \
  --template-body file://aws/09-scps.yaml \
  --parameters file://$PARAMETERS_FILE \
  --region "$REGION" \
  --profile "$PROFILE" \
  >create-stack-output.log

echo "Waiting for stack creation to complete..."

# Wait for the stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name scps \
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

ROOT_ID=$(aws organizations list-roots --region "$REGION" --profile "$PROFILE" --query "Roots[0].Id" --output text)

# Enable SCPs if not already enabled
echo "Enabling SERVICE_CONTROL_POLICY for the root ($ROOT_ID)..."

aws organizations enable-policy-type \
  --root-id "$ROOT_ID" \
  --policy-type SERVICE_CONTROL_POLICY \
  --region "$REGION" --profile "$PROFILE" \
  >scp-enable-output.log

echo "SCP policy type enabled. Proceeding with policy attachments..."

# Get policy IDs from CloudFormation outputs
DENY_POLICY_ID=$(aws cloudformation describe-stacks \
  --stack-name scps \
  --region "$REGION" --profile "$PROFILE" \
  --query "Stacks[0].Outputs[?OutputKey=='DenyNonApprovedRegionsPolicyId'].OutputValue" \
  --output text)

MFA_POLICY_ID=$(aws cloudformation describe-stacks \
  --stack-name scps \
  --region "$REGION" --profile "$PROFILE" \
  --query "Stacks[0].Outputs[?OutputKey=='ForceMFAUsagePolicyId'].OutputValue" \
  --output text)

# Attach policies
aws organizations attach-policy \
  --policy-id "$DENY_POLICY_ID" \
  --target-id "$SANDBOX_OUID" \
  --region "$REGION" --profile "$PROFILE"

aws organizations attach-policy \
  --policy-id "$MFA_POLICY_ID" \
  --target-id "$WORKLOADS_OUID" \
  --region "$REGION" --profile "$PROFILE"
