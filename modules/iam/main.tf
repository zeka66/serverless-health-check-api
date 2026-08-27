
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "LambdaServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:lambda:${var.region}:${var.account_id}:function:${var.function_name}"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name                 = var.role_name
  description          = "Execution role for ${var.function_name}"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "WriteToOwnLogGroupOnly"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${var.log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "${var.name_prefix}-health-check-logs-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.logs.json
}


data "aws_iam_policy_document" "dynamodb" {
  statement {
    sid       = "WriteItemsToRequestsTable"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "dynamodb" {
  name   = "${var.name_prefix}-health-check-dynamodb-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.dynamodb.json
}
