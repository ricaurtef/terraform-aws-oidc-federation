locals {
  # Platform defaults.
  platform_configs = {
    github = {
      url     = "https://token.actions.githubusercontent.com"
      tls_url = "tls://token.actions.githubusercontent.com:443"
      aud     = ["sts.amazonaws.com"]
    }
    gitlab = {
      url     = "https://gitlab.com"
      tls_url = "tls://gitlab.com:443"
      aud     = ["https://gitlab.com"]
    }
    bitbucket = {
      url     = "https://bitbucket.org"
      tls_url = "tls://bitbucket.org:443"
      aud     = ["https://bitbucket.org"]
    }
  }

  url            = local.platform_configs[var.platform].url
  tls_url        = local.platform_configs[var.platform].tls_url
  client_id_list = local.platform_configs[var.platform].aud

  oidc_provider_arn = try(
    aws_iam_openid_connect_provider.this[0].arn,
    var.oidc_provider_arn
  )
}