locals {

  assume_lambda = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "lambda.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  assume_sagemaker = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "sagemaker.amazonaws.com"
        }, Action = "sts:AssumeRole", Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }, ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
  lambda_permissions = {

    ingest = [
      {
        Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = ["${aws_s3_bucket.this["lake"].arn}/raw/events/*", "${aws_s3_bucket.this["lake"].arn}/quarantine/*"]
      },
      {
        Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"], Resource = aws_dynamodb_table.metrics.arn
      },
      {
        Effect = "Allow", Action = ["kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:DescribeStreamSummary", "kinesis:ListShards"], Resource = aws_kinesis_stream.transactions.arn
      },
      {
        Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.failed_batches.arn
      },
      {
        Effect = "Allow", Action = ["kms:Decrypt"], Resource = "arn:${data.aws_partition.current.partition}:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*", Condition = {
          StringEquals = {
            "kms:ViaService" = "kinesis.${var.region}.amazonaws.com"
          }
        }
      }
    ]
    api = [
      {
        Effect = "Allow", Action = ["dynamodb:BatchGetItem"], Resource = aws_dynamodb_table.metrics.arn
      },
      {
        Effect = "Allow", Action = ["dynamodb:Query"], Resource = "${aws_dynamodb_table.metrics.arn}/index/timeline"
      }
    ]
    monitor = [
      {
        Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.this["lake"].arn}/ml/baseline/*"
      },
      {
        Effect = "Allow", Action = ["s3:PutObject"], Resource = ["${aws_s3_bucket.this["lake"].arn}/ml/drift/*", "${aws_s3_bucket.this["lake"].arn}/ml/monitoring/*"]
      },
      {
        Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:UpdateItem"], Resource = aws_dynamodb_table.metrics.arn, Condition = {
          "ForAllValues:StringLike" = {
            "dynamodb:LeadingKeys" = ["CONTROL#*"]
          }
        }
      },
      {
        Effect = "Allow", Action = ["dynamodb:Query"], Resource = "${aws_dynamodb_table.metrics.arn}/index/timeline"
      },
      {
        Effect = "Allow", Action = ["sagemaker:StartPipelineExecution"], Resource = "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:pipeline/${local.name}"
      }
    ]

  }

}
resource "aws_iam_role" "lambda" {

  for_each           = local.lambda_permissions
  name               = "${local.name}-${each.key}"
  assume_role_policy = local.assume_lambda

}
resource "aws_iam_role_policy" "lambda" {

  for_each = local.lambda_permissions
  role     = aws_iam_role.lambda[each.key].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = concat(each.value, [
      {
        Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.lambda[each.key].arn}:*"
      }
    ])
  })

}
resource "aws_iam_role" "sagemaker" {

  name               = "${local.name}-sagemaker"
  assume_role_policy = local.assume_sagemaker

}
resource "aws_iam_role_policy" "sagemaker" {

  role = aws_iam_role.sagemaker.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.this["lake"].arn, Condition = {
          StringLike = {
            "s3:prefix" = ["raw/events/*", "ml/*"]
          }
        }
      },
      {
        Effect = "Allow", Action = ["s3:GetObject"], Resource = ["${aws_s3_bucket.this["lake"].arn}/raw/events/*", "${aws_s3_bucket.this["lake"].arn}/ml/*"]
      },
      {
        Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.this["lake"].arn}/ml/*"
      },
      {
        Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*"
      },
      {
        Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = aws_ecr_repository.ml.arn
      },
      {
        Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"
      },
      {
        Effect = "Allow", Action = ["cloudwatch:PutMetricData"], Resource = "*", Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "/aws/sagemaker/TrainingJobs"
          }
        }
      },
      {
        Effect   = "Allow", Action = ["sagemaker:CreateProcessingJob", "sagemaker:DescribeProcessingJob", "sagemaker:StopProcessingJob", "sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob", "sagemaker:StopTrainingJob", "sagemaker:CreateModelPackage", "sagemaker:DescribeModelPackage", "sagemaker:AddTags"],
        Resource = ["arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:processing-job/pipelines-*", "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:training-job/pipelines-*", "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:model-package/${local.name}/*", "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:model-package-group/${local.name}"]
      },
      {
        Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.sagemaker.arn, Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      }
    ]
  })

}

