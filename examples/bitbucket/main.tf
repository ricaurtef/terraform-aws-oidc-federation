module "bitbucket_oidc" {
  source = "../.."

  platform     = "bitbucket"
  match_values = ["{workspace-uuid}:{repository-uuid}:*"]
}
