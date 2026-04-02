output "role_arn" {
  description = "The ARN of the IAM role to configure in Bitbucket Pipelines (ROLE_ARN variable)."
  value       = module.bitbucket_oidc.role_arn
}

output "provider_arn" {
  description = "The ARN of the OIDC identity provider."
  value       = module.bitbucket_oidc.provider_arn
}
