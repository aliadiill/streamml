data "archive_file" "lambda" {

  type        = "zip"
  source_dir  = "${path.module}/../build/lambda"
  output_path = "${path.module}/../build/lambda.zip"

}
resource "aws_cloudwatch_log_group" "lambda" {

  for_each          = local.lambda_permissions
  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = 7

}
resource "aws_lambda_function" "this" {

  for_each         = local.lambda_permissions
  function_name    = "${local.name}-${each.key}"
  role             = aws_iam_role.lambda[each.key].arn
  handler          = "streamml.${each.key}.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = each.key == "ingest" ? 60 : 30
  memory_size      = 256
  # The Free-plan account has a low shared quota; do not reserve concurrency.
  environment {
    variables = {

      LAKE_BUCKET   = aws_s3_bucket.this["lake"].id
      TABLE_NAME    = aws_dynamodb_table.metrics.name
      PIPELINE_NAME = local.name
      AUTO_RETRAIN  = tostring(var.auto_retrain)

    }
  }
  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]

}
resource "aws_lambda_event_source_mapping" "transactions" {

  event_source_arn                   = aws_kinesis_stream.transactions.arn
  function_name                      = aws_lambda_function.this["ingest"].arn
  starting_position                  = "TRIM_HORIZON"
  batch_size                         = 100
  maximum_batching_window_in_seconds = 2
  maximum_retry_attempts             = 3
  maximum_record_age_in_seconds      = 3600
  bisect_batch_on_function_error     = true
  function_response_types            = ["ReportBatchItemFailures"]
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.failed_batches.arn
    }
  }

}
resource "aws_apigatewayv2_api" "dashboard" {

  name          = local.name
  protocol_type = "HTTP"
  cors_configuration {

    allow_origins = ["http://localhost:5173"]
    allow_methods = ["GET"]
    allow_headers = ["authorization", "content-type"]

  }

}
resource "aws_apigatewayv2_integration" "dashboard" {

  api_id                 = aws_apigatewayv2_api.dashboard.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this["api"].invoke_arn
  payload_format_version = "2.0"

}
resource "aws_apigatewayv2_authorizer" "dashboard" {

  api_id           = aws_apigatewayv2_api.dashboard.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {

    audience = [aws_cognito_user_pool_client.dashboard.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.dashboard.id}"

  }

}
resource "aws_apigatewayv2_route" "dashboard" {

  api_id               = aws_apigatewayv2_api.dashboard.id
  route_key            = "GET /api/metrics"
  target               = "integrations/${aws_apigatewayv2_integration.dashboard.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.dashboard.id
  authorization_scopes = ["streamml/read"]

}
resource "aws_cloudwatch_log_group" "api" {

  name              = "/aws/apigateway/${local.name}"
  retention_in_days = 7

}
resource "aws_apigatewayv2_stage" "dashboard" {

  api_id      = aws_apigatewayv2_api.dashboard.id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10

  }
  access_log_settings {

    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId = "$context.requestId", status = "$context.status", route = "$context.routeKey", latency = "$context.responseLatency"
    })

  }

}
resource "aws_lambda_permission" "api" {

  statement_id  = "AllowHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this["api"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.dashboard.execution_arn}/*/*"

}
resource "aws_cognito_user_pool" "dashboard" {

  name                     = local.name
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  password_policy {

    minimum_length    = 14
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true

  }
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1

    }
  }

}
resource "aws_cognito_user_pool_domain" "dashboard" {

  domain       = "${local.name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.dashboard.id

}
resource "aws_cognito_resource_server" "api" {

  identifier   = "streamml"
  name         = "StreamML metrics"
  user_pool_id = aws_cognito_user_pool.dashboard.id
  scope {
    scope_name        = "read"
    scope_description = "Read transaction dashboard metrics"

  }

}
resource "aws_cognito_user_pool_client" "dashboard" {

  name                                 = "dashboard"
  user_pool_id                         = aws_cognito_user_pool.dashboard.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "streamml/read"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["https://${aws_cloudfront_distribution.dashboard.domain_name}/", "http://localhost:5173/"]
  logout_urls                          = ["https://${aws_cloudfront_distribution.dashboard.domain_name}/", "http://localhost:5173/"]
  access_token_validity                = 15
  id_token_validity                    = 15
  token_validity_units {
    access_token = "minutes"
    id_token     = "minutes"

  }
  prevent_user_existence_errors = "ENABLED"
  depends_on                    = [aws_cognito_resource_server.api]

}

