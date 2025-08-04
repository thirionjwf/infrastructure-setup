variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "account_alias" {
  description = "IAM account alias"
  type        = string
}

variable "billing_contact" {
  description = "Billing contact details"
  type = object({
    email        = string
    full_name    = string
    title        = string
    phone_number = string
  })
}

variable "operations_contact" {
  description = "Operations contact details"
  type = object({
    email        = string
    full_name    = string
    title        = string
    phone_number = string
  })
}

variable "security_contact" {
  description = "Security contact details"
  type = object({
    email        = string
    full_name    = string
    title        = string
    phone_number = string
  })
}

variable "minimum_password_length" {
  description = "Minimum length for IAM account password policy"
  type        = number
}

variable "max_password_age" {
  description = "Maximum password age in days"
  type        = number
}

variable "password_reuse_prevention" {
  description = "Number of previous passwords to prevent reuse"
  type        = number
}

variable "require_uppercase_characters" {
  description = "Require uppercase characters in password"
  type        = bool
}

variable "require_lowercase_characters" {
  description = "Require lowercase characters in password"
  type        = bool
}

variable "require_symbols" {
  description = "Require symbols in password"
  type        = bool
}

variable "require_numbers" {
  description = "Require numbers in password"
  type        = bool
}

variable "allow_users_to_change_password" {
  description = "Allow users to change their password"
  type        = bool
}

variable "tf_state_s3_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "tf_locks_dynamodb_table" {
  description = "DynamoDB table for Terraform locking"
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
}

variable "budget_alert_emails" {
  description = "List of email addresses for budget alerts"
  type        = list(string)
}

variable "organisation" {
  type = list(object({
    ou_name     = string
    ou_accounts = list(object({
      account_name  = string
      account_email = string
      account_id    = string
    }))
  }))
}

variable "management_account_id" {
  description = "The AWS Organizations management account ID"
  type        = string
}

variable "identity_store_id" {
  description = "The AWS Identity Center identity store ID"
  type        = string
}
