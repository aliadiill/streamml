resource "aws_sagemaker_model_package_group" "this" {

  model_package_group_name        = local.name
  model_package_group_description = "Chronologically evaluated transaction anomaly models"

}
resource "aws_sagemaker_pipeline" "this" {

  count                 = var.ml_image_uri == "" ? 0 : 1
  pipeline_name         = local.name
  pipeline_display_name = local.name
  role_arn              = aws_iam_role.sagemaker.arn
  pipeline_definition = templatefile("${path.module}/pipeline.json.tftpl", {

    role_arn    = aws_iam_role.sagemaker.arn, image_uri = var.ml_image_uri,
    bucket_name = aws_s3_bucket.this["lake"].id, package_group = aws_sagemaker_model_package_group.this.model_package_group_name

  })

}
resource "aws_cloudwatch_event_rule" "drift" {

  name                = "${local.name}-drift"
  schedule_expression = "rate(1 day)"
  state               = var.enable_monitor ? "ENABLED" : "DISABLED"

}
resource "aws_cloudwatch_event_target" "drift" {

  rule = aws_cloudwatch_event_rule.drift.name
  arn  = aws_lambda_function.this["monitor"].arn

}
resource "aws_lambda_permission" "drift" {

  statement_id  = "AllowScheduledDrift"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this["monitor"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.drift.arn

}
resource "aws_cloudwatch_event_rule" "ml_failure" {

  name = "${local.name}-ml-failure"
  event_pattern = jsonencode({
    source = ["aws.sagemaker"], "detail-type" = ["SageMaker Model Building Pipeline Execution Status Change"],
    detail = {
      pipelineArn = ["arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:pipeline/${local.name}"], currentPipelineExecutionStatus = ["Failed"]
    }
  })

}
resource "aws_cloudwatch_event_target" "ml_failure" {

  rule = aws_cloudwatch_event_rule.ml_failure.name
  arn  = aws_sns_topic.operations.arn

}
resource "aws_sns_topic_policy" "operations" {

  arn = aws_sns_topic.operations.arn
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{

      Effect = "Allow", Principal = {
        Service = ["events.amazonaws.com", "cloudwatch.amazonaws.com"]
      },
      Action = "SNS:Publish", Resource = aws_sns_topic.operations.arn,
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }

    }]
  })

}
resource "aws_glue_catalog_database" "this" {
  name = replace(local.name, "-", "_")
}
resource "aws_glue_catalog_table" "transactions" {

  name          = "transactions"
  database_name = aws_glue_catalog_database.this.name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    EXTERNAL = "TRUE", classification = "json"
  }
  storage_descriptor {

    location      = "s3://${aws_s3_bucket.this["lake"].id}/raw/events/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }
    dynamic "columns" {

      for_each = {
        event_id = "string", occurred_at = "string", card_id = "string", amount_cents = "bigint", distance_km = "double", attempts_1h = "int", merchant_risk = "double", online = "int", fraud_label = "int"
      }
      content {
        name = columns.key
        type = columns.value

      }

    }

  }

}
resource "aws_athena_workgroup" "this" {

  name          = local.name
  force_destroy = false
  configuration {

    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 10485760
    result_configuration {

      output_location = "s3://${aws_s3_bucket.this["lake"].id}/analytics/results/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }

    }

  }

}
resource "aws_athena_named_query" "hourly" {

  name      = "${local.name}-hourly"
  workgroup = aws_athena_workgroup.this.name
  database  = aws_glue_catalog_database.this.name
  query     = "SELECT substr(occurred_at,1,13) AS hour, count(*) AS transactions, sum(amount_cents)/100.0 AS value, sum(fraud_label) AS synthetic_fraud FROM transactions GROUP BY 1 ORDER BY 1 DESC LIMIT 24"

}
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {

  for_each    = aws_lambda_function.this
  alarm_name  = "${local.name}-${each.key}-errors"
  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  dimensions = {
    FunctionName = each.value.function_name
  }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.operations.arn]

}
resource "aws_cloudwatch_metric_alarm" "lag" {

  alarm_name  = "${local.name}-stream-lag"
  namespace   = "AWS/Lambda"
  metric_name = "IteratorAge"
  dimensions = {
    FunctionName = aws_lambda_function.this["ingest"].function_name
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 60000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.operations.arn]

}
resource "aws_cloudwatch_metric_alarm" "failed_batches" {

  alarm_name  = "${local.name}-failed-batches"
  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.failed_batches.name
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.operations.arn]

}

