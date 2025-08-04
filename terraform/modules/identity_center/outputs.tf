output "account_assignments" {
  value = {
    developers_readonly          = aws_ssoadmin_account_assignment.developers_readonly
    developers_poweruser         = aws_ssoadmin_account_assignment.developers_poweruser
    infrastructure_readonly      = aws_ssoadmin_account_assignment.infrastructure_readonly
    infrastructure_poweruser     = aws_ssoadmin_account_assignment.infrastructure_poweruser
    admin_readonly               = aws_ssoadmin_account_assignment.admin_readonly
    admin_poweruser              = aws_ssoadmin_account_assignment.admin_poweruser
    admin_adminaccess            = aws_ssoadmin_account_assignment.admin_adminaccess
    admin_billing                = aws_ssoadmin_account_assignment.admin_billing
    billing_billing_access       = aws_ssoadmin_account_assignment.billing_billing_access
  }
}
