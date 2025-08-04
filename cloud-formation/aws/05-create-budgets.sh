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
PARAMETERS_FILE="parameters-5.json"

# Create the parameters-5.json file
cat >$PARAMETERS_FILE <<EOF
[
  {
    "ParameterKey": "MonthlyBudgetAmount",
    "ParameterValue": "$(yq eval '.preferences_and_settings.monthly_budget_amount // 10' "$CONFIG_FILE")"
  }
]
EOF

# Check if parameters-1.json was created successfully
if [ -f "$PARAMETERS_FILE" ]; then
  echo "$PARAMETERS_FILE has been created successfully."
else
  echo "Error creating $PARAMETERS_FILE"
  exit 1
fi

# Deploy the stack using the external parameters file
aws cloudformation create-stack \
  --stack-name budgets \
  --template-body file://aws/05-budgets.yaml \
  --parameters file://$PARAMETERS_FILE \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >create-stack-output.log

echo "Waiting for stack creation to complete..."

# Wait for the stack creation to complete
aws cloudformation wait stack-create-complete \
  --stack-name budgets \
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
