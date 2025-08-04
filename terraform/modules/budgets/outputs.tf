output "monthly_budget_name" {
  value = aws_budgets_budget.monthly_budget.name
}

output "zero_spend_budget_name" {
  value = aws_budgets_budget.zero_spend_budget.name
}
