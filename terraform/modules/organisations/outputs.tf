output "organizational_units" {
  description = "Map of created Organizational Units with their IDs"
  value = {
    for ou_name, ou in aws_organizations_organizational_unit.ou :
    ou_name => {
      id   = ou.id
      name = ou.name
    }
  }
}

output "accounts" {
  value = [
    for acct in aws_organizations_account.account :
    {
      account_name = acct.name
      id           = acct.id
      ou_name      = try(acct.tags["ou"], "")
    }
  ]
}

output "ou_ids" {
  description = "Map of OU names to their IDs"
  value = {
    for ou_name, ou in aws_organizations_organizational_unit.ou :
    ou_name => ou.id
  }
}
