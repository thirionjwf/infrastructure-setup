variable "organisation" {
  type = list(object({
    ou_name     = string
    ou_accounts = list(object({
      account_name  = string
      account_email = string
    }))
  }))
}
