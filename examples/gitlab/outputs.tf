output "role_arn" {
  description = "The ARN of the IAM role to configure in GitLab CI (ROLE_ARN variable)."
  value       = module.gitlab_oidc.role_arn
}

output "provider_arn" {
  description = "The ARN of the OIDC identity provider."
  value       = module.gitlab_oidc.provider_arn
}
