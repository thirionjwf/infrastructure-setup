module "account_config" {
  source                  = "./modules/account"
  account_alias           = var.account_alias
  billing_contact         = var.billing_contact
  operations_contact      = var.operations_contact
  security_contact        = var.security_contact
  minimum_password_length = var.minimum_password_length
  max_password_age        = var.max_password_age
  password_reuse_prevention     = var.password_reuse_prevention
  require_uppercase_characters  = var.require_uppercase_characters
  require_lowercase_characters  = var.require_lowercase_characters
  require_symbols               = var.require_symbols
  require_numbers               = var.require_numbers
  allow_users_to_change_password = var.allow_users_to_change_password
}

module "budgets" {
  source               = "./modules/budgets"
  monthly_budget_amount = var.monthly_budget_amount
  budget_alert_emails   = var.budget_alert_emails
}

module "organisations" {
  source       = "./modules/organisations"
  organisation = var.organisation
}

module "identity_center" {
  source                = "./modules/identity_center"
  management_account_id = var.management_account_id
  identity_store_id     = var.identity_store_id

  accounts = flatten([
    for ou in var.organisation : [
      for acct in ou.ou_accounts : {
        id           = acct.account_id
        account_name = acct.account_name
        ou_name      = ou.ou_name
      }
    ]
  ])
}

module "scp" {
  source        = "./modules/scp"
  target_ou_ids = [
    module.organisations.ou_ids["Workloads"],
    module.organisations.ou_ids["Shared"]
  ]
}
