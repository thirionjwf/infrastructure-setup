data "aws_organizations_organization" "org" {}

# Create OUs
resource "aws_organizations_organizational_unit" "ou" {
  for_each = { for org_unit in var.organisation : org_unit.ou_name => org_unit }

  name      = each.key
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

# Flatten account list per OU
locals {
  all_accounts = flatten([
    for ou in var.organisation : [
      for acct in ou.ou_accounts : {
        ou_name       = ou.ou_name
        account_name  = acct.account_name
        account_email = acct.account_email
      }
    ]
  ])
}

# Create accounts
resource "aws_organizations_account" "account" {
  for_each = {
    for acct in local.all_accounts :
    acct.account_name => acct
  }

  name      = each.value.account_name
  email     = each.value.account_email
  parent_id = aws_organizations_organizational_unit.ou[each.value.ou_name].id
}
