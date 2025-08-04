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

# Extract password policy settings from config.yaml with safe defaults
MINIMUM_PASSWORD_LENGTH=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.minimum_password_length // 32' "$CONFIG_FILE")
REQUIRE_SYMBOLS=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.require_symbols // true' "$CONFIG_FILE")
REQUIRE_NUMBERS=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.require_numbers // true' "$CONFIG_FILE")
REQUIRE_UPPERCASE=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.require_uppercase_characters // true' "$CONFIG_FILE")
REQUIRE_LOWERCASE=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.require_lowercase_characters // true' "$CONFIG_FILE")
ALLOW_CHANGE_PASSWORD=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.allow_users_to_change_password // true' "$CONFIG_FILE")
MAX_PASSWORD_AGE=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.max_password_age // 90' "$CONFIG_FILE")
PASSWORD_REUSE_PREVENTION=$(yq eval '.preferences_and_settings.security_preferences.account_settings.password_policy.remember_passwords // 24' "$CONFIG_FILE")

# Validate critical variables
if [ -z "$MINIMUM_PASSWORD_LENGTH" ] || [ -z "$MAX_PASSWORD_AGE" ] || [ -z "$PASSWORD_REUSE_PREVENTION" ]; then
  echo "Error: One or more critical password policy settings are empty."
  exit 1
fi

# Debug print what we are about to set
echo "Applying IAM Account Password Policy with the following settings:"
echo "MINIMUM_PASSWORD_LENGTH=$MINIMUM_PASSWORD_LENGTH"
echo "REQUIRE_SYMBOLS=$REQUIRE_SYMBOLS"
echo "REQUIRE_NUMBERS=$REQUIRE_NUMBERS"
echo "REQUIRE_UPPERCASE=$REQUIRE_UPPERCASE"
echo "REQUIRE_LOWERCASE=$REQUIRE_LOWERCASE"
echo "ALLOW_CHANGE_PASSWORD=$ALLOW_CHANGE_PASSWORD"
echo "MAX_PASSWORD_AGE=$MAX_PASSWORD_AGE"
echo "PASSWORD_REUSE_PREVENTION=$PASSWORD_REUSE_PREVENTION"
echo "REGION=$REGION"
echo "PROFILE=$PROFILE"

# Build dynamic flags for boolean options
FLAGS=()

[ "$REQUIRE_SYMBOLS" == "true" ] && FLAGS+=("--require-symbols")
[ "$REQUIRE_NUMBERS" == "true" ] && FLAGS+=("--require-numbers")
[ "$REQUIRE_UPPERCASE" == "true" ] && FLAGS+=("--require-uppercase-characters")
[ "$REQUIRE_LOWERCASE" == "true" ] && FLAGS+=("--require-lowercase-characters")
[ "$ALLOW_CHANGE_PASSWORD" == "true" ] && FLAGS+=("--allow-users-to-change-password")

# Update the password policy
aws iam update-account-password-policy \
  --minimum-password-length "$MINIMUM_PASSWORD_LENGTH" \
  --max-password-age "$MAX_PASSWORD_AGE" \
  --password-reuse-prevention "$PASSWORD_REUSE_PREVENTION" \
  "${FLAGS[@]}" \
  --region "$REGION" \
  --profile "$PROFILE"

# Check result
if [ $? -eq 0 ]; then
  echo "Password policy updated successfully."
else
  echo "Failed to update password policy. Please check your AWS account and permissions."
  exit 1
fi
