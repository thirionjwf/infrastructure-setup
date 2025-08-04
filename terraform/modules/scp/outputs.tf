output "scp_policy_ids" {
  value = {
    restrict_ec2_types         = aws_organizations_policy.restrict_ec2_types.id
    deny_disallowed_services   = aws_organizations_policy.deny_disallowed_services.id
  }
}
