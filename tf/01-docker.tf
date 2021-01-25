locals {
  name = "acceptessa2-mail-sender"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume-sender" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policy-sender" {
  statement {
    sid     = "1"
    actions = ["logs:CreateLogStream"]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name}:*"
    ]
  }

  statement {
    sid     = "2"
    actions = ["logs:PutLogEvents"]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name}:*:*"
    ]
  }

  statement {
    sid       = "3"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.template.arn}/*"]
  }

  statement {
    sid       = "4"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.attachment.arn}/*"]
  }

  statement {
    sid       = "5"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

resource "aws_ecr_repository" "sender" {
  name                 = "${local.appid}-mail-sender"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "policy" {
  repository = aws_ecr_repository.sender.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 3 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 3
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_iam_role" "sender" {
  name               = "${local.appid}-mail-sender"
  assume_role_policy = data.aws_iam_policy_document.assume-sender.json
}

resource "aws_iam_policy" "sender" {
  name   = "${local.appid}-mail-sender"
  policy = data.aws_iam_policy_document.policy-sender.json
}

resource "aws_iam_role_policy_attachment" "attach-sender" {
  role       = aws_iam_role.sender.name
  policy_arn = aws_iam_policy.sender.arn
}

resource "aws_cloudwatch_log_group" "sender" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "sender" {
  function_name = local.name
  description   = "render template and send mail via SES"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.sender.repository_url}:latest"
  role          = aws_iam_role.sender.arn
  timeout       = 60
  memory_size   = 1024

  lifecycle {
    ignore_changes = [image_uri]
  }
  environment {
    variables = {
      "PAWS_SILENCE_UNSTABLE_WARNINGS" = "1"
    }
  }
}

resource "aws_s3_bucket" "template" {
  bucket = "${local.appid}-mail-template"
  acl    = "private"
}

resource "aws_s3_bucket" "attachment" {
  bucket = "${local.appid}-mail-attachment"
  acl    = "private"

  lifecycle_rule {
    id      = "expire"
    enabled = true

    expiration {
      days = 1
    }
  }
}
