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

# The settings below can't be updated through the `cli or ``cloud `formation as there are no aws billing command

exit

# Enable PDF Invoice Delivery
aws billing update-billing-preferences \
  --enable-pdf-invoice-delivery --region "$REGION" --profile "$PROFILE"
