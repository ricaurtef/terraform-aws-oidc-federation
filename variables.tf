variable "platform" {
  description = "The CI/CD platform to configure (github, gitlab, or bitbucket)."
  type        = string

  validation {
    condition     = contains(["github", "gitlab", "bitbucket"], var.platform)
    error_message = "Platform must be one of: github, gitlab, bitbucket."
  }
}

variable "match_field" {
  description = <<-EOT
    The OIDC token claim used as the condition key in the IAM role trust policy.
    Use "sub" (subject) to scope access to specific repositories or projects — this
    is the recommended default. Use "aud" (audience) to scope by the token's intended
    recipient instead. The chosen field must be present in the tokens issued by the
    selected platform.
  EOT
  type        = string
  default     = "sub"
}

variable "match_values" {
  description = <<-EOT
    One or more patterns that the match_field claim must satisfy (AWS StringLike).
    Wildcards (*) are supported. Platform-specific formats:

      GitHub Actions : ["repo:<org>/<repo>:ref:refs/heads/main"]
      GitLab CI      : ["project_path:<group>/<project>:ref_type:branch:ref:main"]
      Bitbucket      : ["{<workspace-uuid>}:{<repo-uuid>}:*"]

    Providing multiple values allows more than one project or branch to assume the role.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.match_values) > 0
    error_message = "You must provide at least one value to match against the OIDC claim."
  }
}

variable "role_name_prefix" {
  description = "Prefix for the IAM role name."
  type        = string
  default     = "OIDC-Assumable-Role-"
}

variable "create_oidc_provider" {
  description = "Whether to create the IAM OIDC identity provider. Set to false to reuse an existing provider."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = <<-EOT
    ARN of an existing IAM OIDC identity provider to reuse. Required when create_oidc_provider
    is false. Ignored when create_oidc_provider is true. AWS enforces one provider per URL per
    account; use this when the provider already exists.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.create_oidc_provider || var.oidc_provider_arn != null
    error_message = "oidc_provider_arn must be provided when create_oidc_provider is false."
  }
}