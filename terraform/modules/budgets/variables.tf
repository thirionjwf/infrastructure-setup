variable "monthly_budget_amount" {
  type        = number
  description = "Monthly budget amount in USD"
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "List of email addresses for budget alerts"
}
