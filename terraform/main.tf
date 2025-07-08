provider "aws" {
  region = var.region
}

resource "aws_ecr_repository" "app_repo" {
  name = "node-app-repo"
}

resource "aws_sns_topic" "notify_topic" {
  name = "image-push-topic"
}

resource "aws_lambda_function" "image_push_handler" {
  filename         = "lambda.zip"
  function_name    = "ECRImagePushHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("lambda.zip")
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.notify_topic.arn
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sns_publish" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_cloudwatch_event_rule" "ecr_push_event" {
  name        = "ecr-image-push-event"
  description = "Trigger Lambda on ECR image push"
  event_pattern = jsonencode({
    source = ["aws.ecr"],
    detail-type = ["ECR Image Action"],
    detail = {
      "action-type" = ["PUSH"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecr_push_target" {
  rule      = aws_cloudwatch_event_rule.ecr_push_event.name
  target_id = "LambdaFunction"
  arn       = aws_lambda_function.image_push_handler.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_push_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_push_event.arn
}

