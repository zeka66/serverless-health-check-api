// API Gateway REST requires one account-wide IAM role to write access logs.
//
// It lives in the bootstrap rather than the per-environment stack because it
// is a global setting: if staging and prod both managed it, each apply would
// overwrite the other's copy.

data "aws_iam_policy_document" "apigw_cloudwatch_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_cloudwatch" {
  name               = "apigateway-cloudwatch-logs-role"
  description        = "Account-level role allowing API Gateway to write access logs"
  assume_role_policy = data.aws_iam_policy_document.apigw_cloudwatch_assume.json
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}
