# A terraform configuration for a lambda function (and the associated IAM role)

# variables + defaults
variable "aws_region" {
  type                     = string
}

variable "aws_profile" {
  type                     = string
}

provider "aws" {
  region                   = var.aws_region
  profile                  = var.aws_profile
}

variable "ec2bu_event_schedule" {
  type                     = string
  default                  = "cron(0 0 ? * 1 *)"
}

variable "ec2bu_function_name" {
  type                     = string
  default                  = "ec2_backups"
}

variable "ec2bu_tag_generation_1" {
  type                     = string
  default                  = "Current"
}

variable "ec2bu_tag_generation_2" {
  type                     = string
  default                  = "Previous"
}

data "aws_iam_policy_document" "ec2bu_pdoc" {
  statement {
    sid                      = "1"
    effect                   = "Allow"
    actions                  = [
      "ec2:CreateImage",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeregisterImage",
      "ec2:DeleteSnapshot",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumes",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources                = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "ec2bu_policy" {
  name                     = var.ec2bu_function_name
  path                     = "/"
  policy                   = data.aws_iam_policy_document.ec2bu_pdoc.json
}

resource "aws_iam_role" "ec2bu_iamrole" {
  name                     = var.ec2bu_function_name
  path                     = "/"  
  assume_role_policy       = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "ec2bu_policy_attach" {
  name                     = var.ec2bu_function_name
  roles                    = [aws_iam_role.ec2bu_iamrole.name]
  policy_arn               = aws_iam_policy.ec2bu_policy.arn
}

resource "aws_lambda_function" "ec2bu_lambda" {
  filename                 = "${var.ec2bu_function_name}.zip"
  function_name            = var.ec2bu_function_name
  role                     = aws_iam_role.ec2bu_iamrole.arn
  handler                  = "${var.ec2bu_function_name}.lambda_handler"
  source_code_hash         = filebase64sha256("ec2_backups.zip")
  runtime                  = "python3.6"
  timeout                  = 60
  environment {
    variables                = {
      EC2BU_TAG_NAME           = var.ec2bu_function_name
      EC2BU_TAG_GENERATION_1   = var.ec2bu_tag_generation_1
      EC2BU_TAG_GENERATION_2   = var.ec2bu_tag_generation_2
    }
  }
}

resource "aws_cloudwatch_event_rule" "ec2bu_cloudwatch_event_rule" {
  name                     = var.ec2bu_function_name
  description              = "Triggers the ${var.ec2bu_function_name} lambda"
  schedule_expression      = var.ec2bu_event_schedule
}

resource "aws_cloudwatch_event_target" "ec2bu_cloudwatch_event_target" {
  rule                     = aws_cloudwatch_event_rule.ec2bu_cloudwatch_event_rule.name
  target_id                = aws_lambda_alias.ec2bu_lambda_alias.name
  arn                      = aws_lambda_alias.ec2bu_lambda_alias.arn
}

resource "aws_lambda_permission" "ec2bu_lambda_allow_cloudwatch" {
  statement_id             = "AWSEvents_${var.ec2bu_function_name}_${var.ec2bu_function_name}_alias"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.ec2bu_lambda.function_name
  principal                = "events.amazonaws.com"
  source_arn               = aws_cloudwatch_event_rule.ec2bu_cloudwatch_event_rule.arn
  qualifier                = aws_lambda_alias.ec2bu_lambda_alias.name
}

resource "aws_lambda_alias" "ec2bu_lambda_alias" {
  name                     = "${var.ec2bu_function_name}_cloudwatch_alias"
  description              = "Alias for cloudwatch invoke lambda"
  function_name            = aws_lambda_function.ec2bu_lambda.function_name
  function_version         = "$LATEST"
}
