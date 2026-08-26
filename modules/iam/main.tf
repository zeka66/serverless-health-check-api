// CORE REQUIREMENT: a dedicated IAM role for the Lambda with least-privilege
// permissions to execute, write logs to CloudWatch, and write items to the
// DynamoDB table.
//
// Exactly one wildcard appears in this module, documented at its statement.

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "LambdaServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    # Confused-deputy protection: assumable only on behalf of this account,
    # and only for this specific function.
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

# ---------------------------------------------------------------------------
# CloudWatch Logs
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "WriteToOwnLogGroupOnly"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    # MANDATORY WILDCARD: the :* suffix addresses log *streams* within this
    # single log group. CloudWatch Logs accepts no narrower form for
    # stream-level writes.
    #
    # logs:CreateLogGroup is deliberately absent: Terraform creates the group,
    # so the function never needs permission to create one.
    resources = ["${var.log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "${var.name_prefix}-health-check-logs-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.logs.json
}

# ---------------------------------------------------------------------------
# DynamoDB
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "dynamodb" {
  statement {
    sid    = "WriteItemsToRequestsTable"
    effect = "Allow"

    # The handler only ever writes. No Scan, no Query, no GetItem, no
    # DeleteItem, and no access to any other table.
    actions   = ["dynamodb:PutItem"]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "dynamodb" {
  name   = "${var.name_prefix}-health-check-dynamodb-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.dynamodb.json
}
