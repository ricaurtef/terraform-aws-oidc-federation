resource "aws_iam_openid_connect_provider" "this" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = local.url
  client_id_list = local.client_id_list

  thumbprint_list = [
    data.tls_certificate.oidc_provider[0].certificates[0].sha1_fingerprint
  ]
}

resource "aws_iam_role" "this" {
  name_prefix        = var.role_name_prefix
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}