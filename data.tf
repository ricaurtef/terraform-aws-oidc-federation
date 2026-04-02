data "tls_certificate" "oidc_provider" {
  count = var.create_oidc_provider ? 1 : 0
  url   = local.tls_url
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(local.url, "https://", "")}:${var.match_field}"
      values   = var.match_values
    }
  }
}