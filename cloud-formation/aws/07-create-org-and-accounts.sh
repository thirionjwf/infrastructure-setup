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
PARAMETERS_FILE="parameters-7.json"

# Create parameters-7.json
cat <<EOF >$PARAMETERS_FILE
[
  {
    "ParameterKey": "DevAccountEmail",
    "ParameterValue": "$(yq eval '.organizational_units[] | select(.Workloads) | .Workloads.dev.account_email' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "PrdAccountEmail",
    "ParameterValue": "$(yq eval '.organizational_units[] | select(.Workloads) | .Workloads.prd.account_email' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "QaAccountEmail",
    "ParameterValue": "$(yq eval '.organizational_units[] | select(.Workloads) | .Workloads.qa.account_email' "$CONFIG_FILE")"
  },
  {
    "ParameterKey": "ShdAccountEmail",
    "ParameterValue": "$(yq eval '.organizational_units[] | select(.Workloads) | .Workloads.shd.account_email' "$CONFIG_FILE")"
  }
]
EOF

# Check if parameters-7.json was created successfully
if [ -f "$PARAMETERS_FILE" ]; then
  echo "$PARAMETERS_FILE has been created successfully."
else
  echo "Error creating $PARAMETERS_FILE"
  exit 1
fi

# Deploy the AWS Organization stack for Step 7
aws cloudformation create-stack \
  --stack-name org-and-accounts \
  --template-body file://aws/07-organizations.yaml \
  --parameters file://$PARAMETERS_FILE \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --profile "$PROFILE" \
  >create-stack-output.log

echo "Waiting for stack creation to complete..."

# Wait for the stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name org-and-accounts \
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
