output "role_arn" {
  description = <<-EOT
    The ARN of the IAM role created for OIDC federation.
  EOT
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "The name of the IAM role created for OIDC federation."
  value       = aws_iam_role.this.name
}

output "provider_arn" {
  description = "The ARN of the OIDC identity provider."
  value       = local.oidc_provider_arn
}