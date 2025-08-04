variable "accounts" {
  description = "List of flattened accounts with ou_name, account_name, and id"
  type = list(object({
    id           = string
    ou_name      = string
    account_name = string
  }))
}

variable "management_account_id" {
  description = "Management Account ID"
  type        = string
}

variable "identity_store_id" {
  description = "The SSO Identity Store ID (required to create groups)"
  type        = string
}
