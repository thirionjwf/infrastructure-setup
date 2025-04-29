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

# Delete IAM Bootstrap Stack
echo "Deleting IAM Bootstrap stack..."
aws cloudformation delete-stack \
  --stack-name iam-bootstrap \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >delete-stack-output.log

# Check if the stack creation command was successful
if [ $? -ne 0 ]; then
  echo "Failed to delete the stack. Check delete-stack-output.log for details."
  exit 1
fi

echo "Waiting for stack deletion to complete..."

# Wait for the stack deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name iam-bootstrap \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >wait-output.log

# Check if the stack deletion was successful
if [ $? -eq 0 ]; then
  echo "Stack creation complete. Proceeding to the next steps."
else
  echo "Stack creation failed. Please check the CloudFormation console for errors."
  exit 1
fi
