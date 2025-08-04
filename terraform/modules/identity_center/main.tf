provider "aws" {
  alias  = "ssoadmin"
  region = "eu-west-1"
}

data "aws_ssoadmin_instances" "main" {}

resource "aws_identitystore_group" "groups" {
  provider          = aws.ssoadmin
  identity_store_id = var.identity_store_id

  for_each     = toset(["admin", "billing", "developers", "infrastructure"])
  display_name = each.key
}

resource "aws_ssoadmin_permission_set" "permission_sets" {
  provider         = aws.ssoadmin
  for_each         = toset(["ReadOnlyAccess", "Billing", "AdministratorAccess", "PowerUserAccess"])
  name             = each.key
  description      = "${each.key} permission set"
  instance_arn     = data.aws_ssoadmin_instances.main.arns[0]
  session_duration = "PT8H"
}

locals {
  management_account = {
    id           = var.management_account_id
    ou_name      = "Management"
    account_name = "Management"
  }

  sandbox_accounts = [for acct in var.accounts : acct if acct.ou_name == "Sandbox"]
  workloads_accounts = [for acct in var.accounts : acct if acct.ou_name == "Workloads"]
  security_accounts  = [for acct in var.accounts : acct if acct.ou_name == "Security"]
  shared_accounts    = [for acct in var.accounts : acct if acct.ou_name == "Shared"]
  all_accounts       = concat(var.accounts, [local.management_account])

  dev_accounts = [for acct in var.accounts : acct if acct.ou_name == "Workloads" && acct.account_name == "DEV"]
  qa_accounts  = [for acct in var.accounts : acct if acct.ou_name == "Workloads" && acct.account_name == "QA"]
}

### === Developers ===

resource "aws_ssoadmin_account_assignment" "developers_readonly" {
  for_each = {
    for acct in concat(local.sandbox_accounts, local.workloads_accounts, local.security_accounts, local.shared_accounts) :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["developers"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["ReadOnlyAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "developers_poweruser" {
  for_each = {
    for acct in concat(local.sandbox_accounts, local.dev_accounts, local.qa_accounts, local.shared_accounts) :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["developers"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["PowerUserAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

### === Infrastructure ===

resource "aws_ssoadmin_account_assignment" "infrastructure_readonly" {
  for_each = {
    for acct in concat(local.sandbox_accounts, local.workloads_accounts, local.security_accounts, local.shared_accounts, [local.management_account]) :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["infrastructure"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["ReadOnlyAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "infrastructure_poweruser" {
  for_each = {
    for acct in concat(local.sandbox_accounts, local.workloads_accounts, local.security_accounts, local.shared_accounts) :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["infrastructure"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["PowerUserAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

### === Admin ===

resource "aws_ssoadmin_account_assignment" "admin_readonly" {
  for_each = {
    for acct in local.all_accounts :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["admin"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["ReadOnlyAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "admin_poweruser" {
  for_each = {
    for acct in local.all_accounts :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["admin"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["PowerUserAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "admin_adminaccess" {
  for_each = {
    for acct in local.all_accounts :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["admin"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["AdministratorAccess"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "admin_billing" {
  for_each = {
    for acct in local.all_accounts :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["admin"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["Billing"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}

### === Billing ===

resource "aws_ssoadmin_account_assignment" "billing_billing_access" {
  for_each = {
    for acct in local.all_accounts :
    acct.account_name => {
      group_id           = aws_identitystore_group.groups["billing"].group_id
      permission_set_arn = aws_ssoadmin_permission_set.permission_sets["Billing"].arn
      account_id         = acct.id
    }
  }

  instance_arn       = data.aws_ssoadmin_instances.main.arns[0]
  permission_set_arn = each.value.permission_set_arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}
