<!-- BEGIN_TF_DOCS -->
# AWS IAM OIDC Federation for CI/CD

![tag](https://img.shields.io/github/v/tag/ricaurtef/terraform-aws-oidc-federation?label=tag&color=fe8019)
![Terraform](https://img.shields.io/badge/terraform-~%3E1.14-623CE4?logo=terraform&logoColor=white)
![AWS Provider](https://img.shields.io/badge/aws_provider-~%3E6.27-FF9900?logo=amazonaws&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-83a598)

Provisions AWS IAM resources to enable OIDC (OpenID Connect) federation between AWS and a CI/CD
platform. The result is a trust relationship that lets CI/CD jobs exchange a short-lived platform
token for temporary AWS credentials — with no long-lived access keys to store, rotate, or leak.

## The problem this solves

Traditional CI/CD pipelines authenticate to AWS with static access keys stored as repository
secrets. These keys:

- **Never expire.** Rotation is manual and often skipped.
- **Have broad blast radius.** A leaked key is valid until someone notices and revokes it.
- **Accumulate silently.** Keys are created for a pipeline, the pipeline changes, and the key
  is forgotten but remains active.

OIDC federation eliminates the key entirely. Each job run gets credentials that expire in at most
one hour and are scoped to exactly the role you specify.

## How it works

```
CI/CD job
  │
  ├─ 1. Request OIDC token from platform
  │      └─ Platform mints a signed JWT with claims about the job
  │         (repo, branch, workflow, etc.)
  │
  ├─ 2. Call sts:AssumeRoleWithWebIdentity with the JWT
  │      └─ AWS STS verifies the JWT:
  │            • Signature valid against the registered OIDC provider
  │            • Audience (aud) matches the expected client ID
  │            • Subject (sub) satisfies the role's trust policy conditions
  │
  └─ 3. Receive temporary credentials (max 1 hour)
         └─ Use credentials for AWS API calls — they expire automatically
```

## Resources created

| Resource | Condition | Purpose |
|---|---|---|
| `aws_iam_openid_connect_provider` | `create_oidc_provider = true` (default) | Registers the CI/CD platform as a trusted identity provider. AWS uses this to verify JWT signatures. |
| `aws_iam_role` | Always | The assumable role. Its trust policy allows `sts:AssumeRoleWithWebIdentity` from the registered provider, gated on the claim values you specify. |

> **One provider per platform per account.** AWS enforces a uniqueness constraint on OIDC
> provider URLs. If a provider for the platform already exists in the account, set
> `create_oidc_provider = false` and pass the existing ARN via `oidc_provider_arn`.

## Prerequisites

- AWS credentials with permission to create IAM OIDC providers and IAM roles.
- Terraform `>= 1.14`.
- A CI/CD platform that issues OIDC tokens (GitHub Actions, GitLab CI >= 15.7,
  Bitbucket Pipelines).

## Quick start

### GitHub Actions

```hcl
module "oidc" {
  source = "github.com/ricaurtef/terraform-aws-oidc-federation"

  platform     = "github"
  match_values = ["repo:my-org/my-repo:ref:refs/heads/main"]
}
```

In your GitHub Actions workflow:

```yaml
permissions:
  id-token: write   # required to request the OIDC token
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: <role_arn output>
      aws-region: us-east-1
```

### GitLab CI

```hcl
module "oidc" {
  source = "github.com/ricaurtef/terraform-aws-oidc-federation"

  platform     = "gitlab"
  match_values = ["project_path:my-group/my-project:ref_type:branch:ref:main"]
}
```

In your `.gitlab-ci.yml`:

```yaml
assume_role:
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: https://gitlab.com
  script:
    - >
      aws sts assume-role-with-web-identity
      --role-arn <role_arn output>
      --role-session-name gitlab-ci
      --web-identity-token "$GITLAB_OIDC_TOKEN"
```

### Bitbucket Pipelines

```hcl
module "oidc" {
  source = "github.com/ricaurtef/terraform-aws-oidc-federation"

  platform     = "bitbucket"
  match_values = ["{workspace-uuid}:{repo-uuid}:*"]
}
```

See [Bitbucket's OIDC documentation](https://support.atlassian.com/bitbucket-cloud/docs/deploy-on-aws-using-bitbucket-pipelines-openid-connect/)
for how to retrieve workspace and repository UUIDs and call `AssumeRoleWithWebIdentity` from a
pipeline step.

## Usage

See the [`examples/`](./examples) directory for complete, working configurations per platform:

- [GitHub Actions](./examples/github)
- [GitLab CI](./examples/gitlab)
- [Bitbucket Pipelines](./examples/bitbucket)

### Multiple roles, single provider

When you need multiple IAM roles for the same platform — separate roles for different projects or
permission levels — create the provider once and reuse it for subsequent calls.

```hcl
# First call — creates the OIDC provider and the deploy role.
module "oidc_deploy" {
  source = "github.com/ricaurtef/terraform-aws-oidc-federation"

  platform     = "github"
  match_values = ["repo:my-org/my-repo:ref:refs/heads/main"]
}

# Second call — reuses the existing provider, creates a read-only role.
module "oidc_readonly" {
  source = "github.com/ricaurtef/terraform-aws-oidc-federation"

  platform             = "github"
  match_values         = ["repo:my-org/my-repo:*"]
  create_oidc_provider = false
  oidc_provider_arn    = module.oidc_deploy.provider_arn
}
```

### Attaching permissions

The module creates the role without any permission policies. Attach policies using the
`role_name` output:

```hcl
module "oidc" {
  source = "github.com/ricaurtef/terraform-aws-oidc-federation"

  platform     = "github"
  match_values = ["repo:my-org/my-repo:ref:refs/heads/main"]
}

data "aws_iam_policy_document" "deploy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::my-deploy-bucket/*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name   = "ci-deploy-policy"
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = module.oidc.role_name
  policy_arn = aws_iam_policy.deploy.arn
}
```

## Scoping access with match_values

The `match_values` list controls which tokens are allowed to assume the role. AWS evaluates them
with `StringLike`, so `*` wildcards are supported. Start as narrow as your use case allows.

| Scope | GitHub Actions example | GitLab CI example |
|---|---|---|
| Entire org / group | `repo:myorg/*` | `project_path:mygroup/*:*` |
| Single repo, any ref | `repo:myorg/myrepo:*` | `project_path:mygroup/myrepo:*` |
| Single repo, main branch | `repo:myorg/myrepo:ref:refs/heads/main` | `project_path:mygroup/myrepo:ref_type:branch:ref:main` |
| Single repo, tags only | `repo:myorg/myrepo:ref:refs/tags/*` | `project_path:mygroup/myrepo:ref_type:tag:ref:*` |

Providing multiple entries lets more than one project or branch assume the same role:

```hcl
match_values = [
  "repo:my-org/service-a:ref:refs/heads/main",
  "repo:my-org/service-b:ref:refs/heads/main",
]
```

> **Bitbucket users:** Bitbucket's `sub` claim uses UUIDs rather than human-readable names.
> There is no name-based wildcard that covers an entire workspace; you must supply the workspace
> UUID explicitly. Find your workspace UUID under **Workspace Settings → General** and your
> repository UUID under **Repository Settings → General**.

## Design decisions

**No policies attached.** Permission boundaries are use-case specific. A module that attaches
policies would either be too permissive or too opinionated. Keeping the module policy-free makes
it composable: callers attach exactly what their pipeline needs.

**`sub` as the default `match_field`.** The subject claim is scoped to a specific
repository/project and ref — the safest default. The audience claim (`aud`) is often shared
across an entire organisation; matching on it grants access to every repo in that org.

**Thumbprint fetched at apply time.** The TLS thumbprint for the OIDC provider endpoint is
fetched dynamically via the `tls` provider rather than hardcoded. This keeps the module correct
if the platform rotates its TLS certificate, with no module update required.

**Conditional provider creation.** AWS enforces one OIDC provider per URL per account. Allowing
callers to skip creation (`create_oidc_provider = false`) is what makes multiple module calls
for the same platform viable in a single account.

## Releasing

Releases are driven by semantic version tags and triggered via GitHub Actions.

1. Open a pull request — `validate` runs automatically as the merge gate.
2. Merge to main once approved.
3. Go to **Actions → Release → Run workflow → Branch: main** and select the bump type:

| Type | When to use |
|------|-------------|
| `patch` | Backwards-compatible bug fixes (default) |
| `minor` | New backwards-compatible functionality |
| `major` | Breaking changes |

The workflow bumps the version tag, regenerates `README.md` if the docs are stale, and publishes
a GitHub Release with auto-generated release notes. The first release always starts at `v1.0.0`.

## Security considerations

- **Prefer `sub` over `aud` for `match_field`.** See [Design decisions](#design-decisions).
- **Avoid bare wildcards.** A `match_values` entry of `["*"]` allows _any_ token issued by the
  platform to assume the role. Always include at least the org or group prefix.
- **Attach least-privilege policies.** Attach only the actions and resources your pipeline needs.
- **One provider per account per URL.** If a provider already exists, use
  `create_oidc_provider = false` rather than creating a duplicate.
- **Temporary credentials expire in at most 1 hour.** AWS STS enforces this maximum on
  `AssumeRoleWithWebIdentity`. Each job run must request a fresh token.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.14 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.27 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.1 |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.27 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.1 |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Whether to create the IAM OIDC identity provider. Set to false to reuse an existing provider. | `bool` | `true` | no |
| <a name="input_match_field"></a> [match\_field](#input\_match\_field) | The OIDC token claim used as the condition key in the IAM role trust policy.<br/>Use "sub" (subject) to scope access to specific repositories or projects — this<br/>is the recommended default. Use "aud" (audience) to scope by the token's intended<br/>recipient instead. The chosen field must be present in the tokens issued by the<br/>selected platform. | `string` | `"sub"` | no |
| <a name="input_match_values"></a> [match\_values](#input\_match\_values) | One or more patterns that the match\_field claim must satisfy (AWS StringLike).<br/>Wildcards (*) are supported. Platform-specific formats:<br/><br/>  GitHub Actions : ["repo:<org>/<repo>:ref:refs/heads/main"]<br/>  GitLab CI      : ["project\_path:<group>/<project>:ref\_type:branch:ref:main"]<br/>  Bitbucket      : ["{<workspace-uuid>}:{<repo-uuid>}:*"]<br/><br/>Providing multiple values allows more than one project or branch to assume the role. | `list(string)` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of an existing IAM OIDC identity provider to reuse. Required when create\_oidc\_provider<br/>is false. Ignored when create\_oidc\_provider is true. AWS enforces one provider per URL per<br/>account; use this when the provider already exists. | `string` | `null` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | The CI/CD platform to configure (github, gitlab, or bitbucket). | `string` | n/a | yes |
| <a name="input_role_name_prefix"></a> [role\_name\_prefix](#input\_role\_name\_prefix) | Prefix for the IAM role name. | `string` | `"OIDC-Assumable-Role-"` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_provider_arn"></a> [provider\_arn](#output\_provider\_arn) | The ARN of the OIDC identity provider. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The ARN of the IAM role created for OIDC federation. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the IAM role created for OIDC federation. |
## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
<!-- END_TF_DOCS -->