output "account_alias" {
  value = aws_iam_account_alias.alias.account_alias
}

output "alternate_contacts" {
  value = {
    billing    = aws_account_alternate_contact.billing.email_address
    operations = aws_account_alternate_contact.operations.email_address
    security   = aws_account_alternate_contact.security.email_address
  }
}

output "password_policy" {
  description = "Current IAM account password policy settings"
  value = {
    minimum_password_length        = aws_iam_account_password_policy.main.minimum_password_length
    max_password_age              = aws_iam_account_password_policy.main.max_password_age
    password_reuse_prevention     = aws_iam_account_password_policy.main.password_reuse_prevention
    require_uppercase_characters  = aws_iam_account_password_policy.main.require_uppercase_characters
    require_lowercase_characters  = aws_iam_account_password_policy.main.require_lowercase_characters
    require_symbols               = aws_iam_account_password_policy.main.require_symbols
    require_numbers               = aws_iam_account_password_policy.main.require_numbers
    allow_users_to_change_password = aws_iam_account_password_policy.main.allow_users_to_change_password
  }
}
