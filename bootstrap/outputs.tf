output "state_bucket_name" {
  description = "Terraform state bucket. Use this in envs/*.backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "deploy_role_arns" {
  description = "Deployment role ARNs. Set these as GitHub repository variables."
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}
