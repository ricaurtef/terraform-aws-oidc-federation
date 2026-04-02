module "github_oidc" {
  source = "../.."

  platform     = "github"
  match_values = ["repo:my-org/my-repo:*"]
}
