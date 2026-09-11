resource "aws_s3_bucket" "this" {

  for_each      = local.buckets
  bucket        = each.value
  force_destroy = false

}
resource "aws_s3_bucket_public_access_block" "this" {

  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {

  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}
resource "aws_s3_bucket_versioning" "this" {

  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }

}
resource "aws_s3_bucket_lifecycle_configuration" "this" {

  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {

    id     = "bounded-retention"
    status = "Enabled"
    filter {
      prefix = each.key == "lake" ? "raw/" : ""
    }
    expiration {
      days = each.key == "web" ? 365 : 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

  }

}
resource "aws_dynamodb_table" "metrics" {

  name         = local.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  attribute {
    name = "pk"
    type = "S"

  }
  attribute {
    name = "timeline"
    type = "S"

  }
  attribute {
    name = "occurred_at"
    type = "S"

  }
  global_secondary_index {

    name            = "timeline"
    hash_key        = "timeline"
    range_key       = "occurred_at"
    projection_type = "ALL"

  }
  ttl {
    attribute_name = "expires_at"
    enabled        = true

  }
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled = true
  }

}
resource "aws_sqs_queue" "failed_batches" {

  name                      = "${local.name}-failed-batches"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

}
resource "aws_sns_topic" "operations" {
  name = "${local.name}-operations"
}
resource "aws_kinesis_stream" "transactions" {

  name             = "${local.name}-transactions"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = "alias/aws/kinesis"
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

}
resource "aws_ecr_repository" "ml" {

  name                 = local.name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }

}
resource "aws_ecr_lifecycle_policy" "ml" {

  repository = aws_ecr_repository.ml.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1, description = "Expire untagged images; retain tagged model dependencies",
      selection = {
        tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14
      },
      action = {
        type = "expire"
      }
    }]
  })

}

