variable "account_alias" {
  type        = string
  description = "IAM account alias"
}

variable "billing_contact" {
  type = object({
    email        = string
    full_name    = string
    title        = string
    phone_number = string
  })
}

variable "operations_contact" {
  type = object({
    email        = string
    full_name    = string
    title        = string
    phone_number = string
  })
}

variable "security_contact" {
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
  default     = 14
}

variable "max_password_age" {
  description = "Maximum password age in days"
  type        = number
  default     = 90
}

variable "password_reuse_prevention" {
  description = "Number of previous passwords to prevent reuse"
  type        = number
  default      = 24
}

variable "require_uppercase_characters" {
  description = "Number of previous passwords to prevent reuse"
  type        = bool
  default     = true
}

variable "require_lowercase_characters" {
  description = "Number of previous passwords to prevent reuse"
  type        = bool
  default     = true
}

variable "require_symbols" {
  description = "Number of previous passwords to prevent reuse"
  type        = bool
  default     = true
}

variable "require_numbers" {
  description = "Number of previous passwords to prevent reuse"
  type        = bool
  default     = true
}

variable "allow_users_to_change_password" {
  description = "Whether password changes are allowed"
  type        = bool
  default     = true
}
