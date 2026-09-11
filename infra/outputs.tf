output "region" {
  value = var.region
}
output "stream_name" {
  value = aws_kinesis_stream.transactions.name
}
output "lake_bucket" {
  value = aws_s3_bucket.this["lake"].id
}
output "web_bucket" {
  value = aws_s3_bucket.this["web"].id
}
output "website_url" {
  value = "https://${aws_cloudfront_distribution.dashboard.domain_name}"
}
output "distribution_id" {
  value = aws_cloudfront_distribution.dashboard.id
}
output "api_url" {
  value = aws_apigatewayv2_api.dashboard.api_endpoint
}
output "cognito_client_id" {
  value = aws_cognito_user_pool_client.dashboard.id
}
output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.dashboard.domain}.auth.${var.region}.amazoncognito.com"
}
output "user_pool_id" {
  value = aws_cognito_user_pool.dashboard.id
}
output "ecr_repository" {
  value = aws_ecr_repository.ml.repository_url
}
output "sagemaker_role" {
  value = aws_iam_role.sagemaker.arn
}
output "pipeline_name" {
  value = local.name
}
output "operations_topic" {
  value = aws_sns_topic.operations.arn
}

