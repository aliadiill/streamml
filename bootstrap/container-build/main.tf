terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "Use a short lowercase environment name."
  }
}
variable "source_archive" {
  type        = string
  default     = null
  description = "Optional absolute path to the zip produced by scripts/package_container_source.py."
}
provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "StreamML", Environment = var.environment, Owner = "Portfolio", Purpose = "BoundedContainerTest" }
  }
}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
locals {
  name        = "streamml-container-${var.environment}"
  archive     = var.source_archive == null ? "${path.module}/../../build/container-source.zip" : var.source_archive
  source_hash = filesha256(local.archive)
}
resource "aws_s3_bucket" "build" {
  bucket        = "${local.name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
}
resource "aws_s3_bucket_public_access_block" "build" {
  bucket                  = aws_s3_bucket.build.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "build" {
  bucket = aws_s3_bucket.build.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_versioning" "build" {
  bucket = aws_s3_bucket.build.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "build" {
  bucket = aws_s3_bucket.build.id
  rule {
    id     = "expire-short-demonstration-evidence"
    status = "Enabled"
    filter {}
    expiration {
      days = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
resource "aws_s3_bucket_policy" "build" {
  bucket = aws_s3_bucket.build.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Deny", Principal = "*", Action = "s3:*",
      Resource  = [aws_s3_bucket.build.arn, "${aws_s3_bucket.build.arn}/*"],
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}
resource "aws_s3_object" "source" {
  bucket                 = aws_s3_bucket.build.id
  key                    = "source/${local.source_hash}.zip"
  source                 = local.archive
  source_hash            = local.source_hash
  server_side_encryption = "AES256"
}
resource "aws_ecr_repository" "container" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}
resource "aws_ecr_lifecycle_policy" "container" {
  repository = aws_ecr_repository.container.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1, description = "Only untagged short-lived build images",
      selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 1 },
      action       = { type = "expire" }
    }]
  })
}
resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/${local.name}"
  retention_in_days = 7
}
resource "aws_iam_role" "build" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "codebuild.amazonaws.com" },
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id },
        ArnEquals    = { "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:project/${local.name}" }
      }
    }]
  })
}
resource "aws_iam_role_policy" "build" {
  role = aws_iam_role.build.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.build.arn}:*" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion"], Resource = "${aws_s3_bucket.build.arn}/source/*" },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.build.arn}/builds/*" },
      { Effect = "Allow", Action = ["s3:GetBucketAcl", "s3:GetBucketLocation"], Resource = aws_s3_bucket.build.arn },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:DescribeImages", "ecr:DescribeImageScanFindings"], Resource = aws_ecr_repository.container.arn }
    ]
  })
}
resource "aws_codebuild_project" "container" {
  name           = local.name
  service_role   = aws_iam_role.build.arn
  build_timeout  = 10
  queued_timeout = 10
  source {
    type      = "S3"
    location  = "${aws_s3_bucket.build.id}/${aws_s3_object.source.key}"
    buildspec = "buildspec-container.yml"
  }
  artifacts {
    type                = "S3"
    location            = aws_s3_bucket.build.id
    path                = "builds"
    namespace_type      = "BUILD_ID"
    name                = "evidence.zip"
    packaging           = "ZIP"
    encryption_disabled = false
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "ECR_REPOSITORY"
      value = aws_ecr_repository.container.repository_url
    }
    environment_variable {
      name  = "ECR_NAME"
      value = aws_ecr_repository.container.name
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = substr(local.source_hash, 0, 24)
    }
    environment_variable {
      name  = "SOURCE_HASH"
      value = local.source_hash
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }
  depends_on = [aws_iam_role_policy.build]
}
output "project_name" {
  value = aws_codebuild_project.container.name
}
output "artifact_bucket" {
  value = aws_s3_bucket.build.id
}
output "artifact_prefix" {
  value = "builds/"
}
output "source_hash" {
  value = local.source_hash
}
output "image_uri" {
  value = "${aws_ecr_repository.container.repository_url}:${substr(local.source_hash, 0, 24)}"
}
output "repository_name" {
  value = aws_ecr_repository.container.name
}
output "log_group" {
  value = aws_cloudwatch_log_group.build.name
}

