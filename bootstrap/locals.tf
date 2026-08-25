// One-time bootstrap, applied manually by an administrator with local state.
//
// This stack cannot use the S3 backend because it *creates* the S3 backend.
// Local state for this stack only is the usual answer to that chicken-and-egg
// problem, and keeps the bootstrap reviewable as code rather than as console
// clicks.
//
// It exists for three reasons:
//   1. The state bucket cannot store its own state.
//   2. GitHub Actions cannot authenticate until the OIDC provider and deploy
//      roles exist, and it cannot create them itself.
//   3. The deploy roles must be defined in a stack the pipeline never runs,
//      so a compromised pipeline cannot raise its own privileges.
//
// Split by concern:
//   state.tf         - the S3 bucket holding Terraform state
//   oidc.tf          - the GitHub Actions OIDC identity provider
//   deploy_roles.tf  - one deployment role per environment
//   apigw_account.tf - the account-level API Gateway CloudWatch role

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  envs       = toset(["staging", "prod"])
}
