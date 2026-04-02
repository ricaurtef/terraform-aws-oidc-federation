module "gitlab_oidc" {
  source = "../.."

  platform     = "gitlab"
  match_values = ["project_path:mygroup/myproject:ref_type:branch:ref:main"]
}
