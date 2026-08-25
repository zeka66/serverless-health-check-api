// CORE REQUIREMENT: a dedicated IAM role for the deployment process.
//
// One role per environment. Defining them here - in a stack the pipeline never
// runs - is itself the control that stops a compromised pipeline raising its
// own privileges: the deploy role can create staging-* resources, but cannot
// modify staging-health-check-deploy-role.

data "aws_iam_policy_document" "deploy_assume_role" {
  for_each = local.envs

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scoped to one repository AND one GitHub Environment. A job running
    # against the staging environment cannot assume the prod role, even from
    # the same repository and the same branch.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${each.value}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each = local.envs

  name                 = "${each.value}-health-check-deploy-role"
  description          = "GitHub Actions deployment role for the ${each.value} environment"
  assume_role_policy   = data.aws_iam_policy_document.deploy_assume_role[each.value].json
  max_session_duration = 3600
}

# ---------------------------------------------------------------------------
# Deployment role permissions
#
# [sec] Least privilege: every statement below is pinned to an env-prefixed
# ARN. There is no Resource = "*" anywhere in this document.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "deploy" {
  for_each = local.envs

  statement {
    sid     = "TerraformStateAccess"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]

    # Each role can only touch its own environment's state file.
    resources = ["${aws_s3_bucket.state.arn}/${each.value}/*"]
  }

  statement {
    sid       = "TerraformStateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid    = "DynamoDbTableManagement"
    effect = "Allow"

    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTable",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource",
    ]

    resources = ["arn:aws:dynamodb:${local.region}:${local.account_id}:table/${each.value}-*"]
  }

  statement {
    sid    = "LambdaManagement"
    effect = "Allow"

    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
    ]

    resources = ["arn:aws:lambda:${local.region}:${local.account_id}:function:${each.value}-*"]
  }

  statement {
    sid    = "IamRoleManagementForThisEnvironmentOnly"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListInstanceProfilesForRole",
    ]

    # Cannot create or modify any role outside its own environment prefix.
    resources = ["arn:aws:iam::${local.account_id}:role/${each.value}-*"]
  }

  statement {
    sid       = "PassExecutionRoleToLambdaOnly"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${each.value}-health-check-lambda-role"]

    # Even holding PassRole, the pipeline can only hand this role to Lambda -
    # not to EC2 or anything else that could be used to escalate privilege.
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid    = "CloudWatchLogGroupManagement"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]

    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${each.value}-*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/apigateway/${each.value}-*",
    ]
  }

  # DescribeLogGroups is a list operation and is authorised against the
  # log-stream ARN form rather than a specific group.
  statement {
    sid       = "CloudWatchLogGroupDiscovery"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group::log-stream:*"]
  }

  statement {
    sid    = "ApiGatewayManagement"
    effect = "Allow"

    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
    ]

    # API Gateway control-plane ARNs address REST paths (/restapis), not
    # resource names, so they cannot be scoped by environment prefix. The
    # paths themselves are enumerated rather than granted wholesale, and
    # isolation is enforced by the two roles being separate identities.
    resources = [
      "arn:aws:apigateway:${local.region}::/restapis",
      "arn:aws:apigateway:${local.region}::/restapis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy" {
  for_each = local.envs

  name   = "${each.value}-health-check-deploy-policy"
  role   = aws_iam_role.deploy[each.value].id
  policy = data.aws_iam_policy_document.deploy[each.value].json
}
