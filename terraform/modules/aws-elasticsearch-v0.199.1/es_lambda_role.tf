data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_es_role" {
  name               = "${local.name}_lbd"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_es_execution_policy" {
  statement {
    actions   = ["es:ESHttpPost"]
    resources = ["${aws_elasticsearch_domain.es.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_es_execution_policy" {
  name   = "${local.name}_lbd_exe"
  role   = aws_iam_role.lambda_es_role.id
  policy = data.aws_iam_policy_document.lambda_es_execution_policy.json
}
