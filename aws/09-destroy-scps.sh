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

echo "" >detach-policy-output.log
# Step 1: Disable SCPs on root
echo "Disabling SERVICE_CONTROL_POLICY for the root ($ROOT_ID)..."
aws organizations disable-policy-type \
  --root-id "$ROOT_ID" \
  --policy-type SERVICE_CONTROL_POLICY \
  --region "$REGION" --profile "$PROFILE" \
  >>scp-disable-output.log

# Step 2: Now detach policies (SCPs can be removed only after disable)
for OUID in "$WORKLOADS_OUID" "$SANDBOX_OUID"; do
  for policy in $(aws organizations list-policies-for-target \
    --target-id "$OUID" \
    --filter SERVICE_CONTROL_POLICY \
    --query "Policies[].Id" --output text --region "$REGION" --profile "$PROFILE"); do

    echo "Detaching $policy from $OUID..."
    aws organizations detach-policy \
      --policy-id "$policy" --target-id "$OUID" \
      --region "$REGION" --profile "$PROFILE" \
      >>detach-policy-output.log
  done
done

# Destroy IAM Bootstrap Stack
aws cloudformation delete-stack \
  --stack-name scps \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >delete-stack-output.log

echo "Waiting for stack deletion to complete..."

# Wait for the stack deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name scps \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" \
  >wait-output.log

# Check if the stack deletion was successful
if [ $? -eq 0 ]; then
  echo "Stack deletion complete. Proceeding to the next steps."
else
  echo "Stack deletion failed. Please check the CloudFormation console for errors."
  exit 1
fi
