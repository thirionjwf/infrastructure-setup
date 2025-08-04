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

# Extract account alias and alternate contacts from config.yaml
ACCOUNT_ALIAS=$(yq eval '.account.account_details.alias' "$CONFIG_FILE")
BILLING_CONTACT_EMAIL=$(yq eval '.account.alternate_contacts.billing.email' "$CONFIG_FILE")
BILLING_CONTACT_NAME=$(yq eval '.account.alternate_contacts.billing.full_name' "$CONFIG_FILE")
BILLING_CONTACT_TITLE=$(yq eval '.account.alternate_contacts.billing.title' "$CONFIG_FILE")
BILLING_CONTACT_PHONE=$(yq eval '.account.alternate_contacts.billing.phone_number' "$CONFIG_FILE")

OPERATIONS_CONTACT_EMAIL=$(yq eval '.account.alternate_contacts.operations.email' "$CONFIG_FILE")
OPERATIONS_CONTACT_NAME=$(yq eval '.account.alternate_contacts.operations.full_name' "$CONFIG_FILE")
OPERATIONS_CONTACT_TITLE=$(yq eval '.account.alternate_contacts.operations.title' "$CONFIG_FILE")
OPERATIONS_CONTACT_PHONE=$(yq eval '.account.alternate_contacts.operations.phone_number' "$CONFIG_FILE")

SECURITY_CONTACT_EMAIL=$(yq eval '.account.alternate_contacts.security.email' "$CONFIG_FILE")
SECURITY_CONTACT_NAME=$(yq eval '.account.alternate_contacts.security.full_name' "$CONFIG_FILE")
SECURITY_CONTACT_TITLE=$(yq eval '.account.alternate_contacts.security.title' "$CONFIG_FILE")
SECURITY_CONTACT_PHONE=$(yq eval '.account.alternate_contacts.security.phone_number' "$CONFIG_FILE")

# Validate that account alias and all contact information are not empty
if [ -z "$ACCOUNT_ALIAS" ] || [ -z "$BILLING_CONTACT_EMAIL" ] || [ -z "$BILLING_CONTACT_NAME" ] || [ -z "$BILLING_CONTACT_TITLE" ] || [ -z "$BILLING_CONTACT_PHONE" ] || [ -z "$OPERATIONS_CONTACT_EMAIL" ] || [ -z "$OPERATIONS_CONTACT_NAME" ] || [ -z "$OPERATIONS_CONTACT_TITLE" ] || [ -z "$OPERATIONS_CONTACT_PHONE" ] || [ -z "$SECURITY_CONTACT_EMAIL" ] || [ -z "$SECURITY_CONTACT_NAME" ] || [ -z "$SECURITY_CONTACT_TITLE" ] || [ -z "$SECURITY_CONTACT_PHONE" ]; then
  echo "Error: Missing essential contact information in config.yaml."
  exit 1
fi

# Create Account Alias
aws iam create-account-alias --account-alias "$ACCOUNT_ALIAS" --region "$REGION" --profile "$PROFILE" || echo "Account alias already exists. Continuing..."

# Set Alternative Contacts
aws account put-alternate-contact --alternate-contact-type BILLING \
  --email-address "$BILLING_CONTACT_EMAIL" \
  --name "$BILLING_CONTACT_NAME" \
  --title "$BILLING_CONTACT_TITLE" \
  --phone-number "$BILLING_CONTACT_PHONE" \
  --region "$REGION" --profile "$PROFILE"

aws account put-alternate-contact --alternate-contact-type OPERATIONS \
  --email-address "$OPERATIONS_CONTACT_EMAIL" \
  --name "$OPERATIONS_CONTACT_NAME" \
  --title "$OPERATIONS_CONTACT_TITLE" \
  --phone-number "$OPERATIONS_CONTACT_PHONE" \
  --region "$REGION" --profile "$PROFILE"

aws account put-alternate-contact --alternate-contact-type SECURITY \
  --email-address "$SECURITY_CONTACT_EMAIL" \
  --name "$SECURITY_CONTACT_NAME" \
  --title "$SECURITY_CONTACT_TITLE" \
  --phone-number "$SECURITY_CONTACT_PHONE" \
  --region "$REGION" --profile "$PROFILE"
