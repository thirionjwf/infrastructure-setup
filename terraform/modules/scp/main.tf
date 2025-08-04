locals {
  ec2_instance_restriction_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictEC2InstanceTypes"
        Effect = "Deny"
        Action = "ec2:RunInstances"
        Resource = "*"
        Condition = {
          StringNotEqualsIfExists = {
            "ec2:InstanceType" = [
              "t2.nano", "t2.micro", "t2.small", "t2.medium",
              "t3.nano", "t3.micro", "t3.small", "t3.medium",
              "t4g.nano", "t4g.micro", "t4g.small", "t4g.medium"
            ]
          }
        }
      }
    ]
  })

  deny_disallowed_services_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisallowedServices"
        Effect = "Deny"
        Action = [
          "shield:*",
          "ec2:CreateFlowLogs",
          "es:*",
          "redshift:*",
          "guardduty:*",
          "elasticache:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy" "restrict_ec2_types" {
  name        = "RestrictEC2InstanceTypes"
  description = "Restrict EC2 instance types to nano, micro, small, medium"
  content     = local.ec2_instance_restriction_policy
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "deny_disallowed_services" {
  name        = "DenyDisallowedServices"
  description = "Deny AWS services that are not allowed"
  content     = local.deny_disallowed_services_policy
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy_attachment" "attach_restrict_ec2" {
  for_each  = toset(var.target_ou_ids)
  policy_id = aws_organizations_policy.restrict_ec2_types.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "attach_deny_services" {
  for_each  = toset(var.target_ou_ids)
  policy_id = aws_organizations_policy.deny_disallowed_services.id
  target_id = each.value
}
