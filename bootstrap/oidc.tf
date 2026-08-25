// GitHub Actions OIDC identity provider.
//
// [sec] Secrets handling: no long-lived AWS access keys exist anywhere in this
// project. GitHub mints a short-lived OIDC token per job and STS exchanges it
// for temporary credentials that expire with the job. Nothing secret is stored
// in the repository, so there is nothing to leak, rotate, or accidentally
// print in a log.

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_oidc_thumbprints
}
