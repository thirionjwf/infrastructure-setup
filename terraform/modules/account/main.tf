resource "aws_iam_account_alias" "alias" {
  account_alias = var.account_alias
}

resource "aws_account_alternate_contact" "billing" {
  alternate_contact_type = "BILLING"
  email_address          = var.billing_contact.email
  name                   = var.billing_contact.full_name
  title                  = var.billing_contact.title
  phone_number           = var.billing_contact.phone_number
}

resource "aws_account_alternate_contact" "operations" {
  alternate_contact_type = "OPERATIONS"
  email_address          = var.operations_contact.email
  name                   = var.operations_contact.full_name
  title                  = var.operations_contact.title
  phone_number           = var.operations_contact.phone_number
}

resource "aws_account_alternate_contact" "security" {
  alternate_contact_type = "SECURITY"
  email_address          = var.security_contact.email
  name                   = var.security_contact.full_name
  title                  = var.security_contact.title
  phone_number           = var.security_contact.phone_number
}

resource "aws_iam_account_password_policy" "main" {
  minimum_password_length         = var.minimum_password_length
  max_password_age               = var.max_password_age
  password_reuse_prevention      = var.password_reuse_prevention
  require_uppercase_characters   = var.require_uppercase_characters
  require_lowercase_characters   = var.require_lowercase_characters
  require_symbols                = var.require_symbols
  require_numbers                = var.require_numbers
  allow_users_to_change_password = var.allow_users_to_change_password
}
