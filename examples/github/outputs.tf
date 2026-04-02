output "role_arn" {
  description = "The ARN of the IAM role to configure in GitHub Actions (ROLE_ARN secret)."
  value       = module.github_oidc.role_arn
}

output "provider_arn" {
  description = "The ARN of the OIDC identity provider."
  value       = module.github_oidc.provider_arn
}
