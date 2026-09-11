resource "aws_iam_role" "codebuild" {

  for_each = var.enable_ci ? toset(["verify", "deploy"]) : toset([])
  name     = "${local.name}-build-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = "sts:AssumeRole", Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

}
resource "aws_cloudwatch_log_group" "codebuild" {

  for_each          = aws_iam_role.codebuild
  name              = "/aws/codebuild/${local.name}-${each.key}"
  retention_in_days = 7

}
resource "aws_iam_role_policy" "codebuild" {

  for_each = aws_iam_role.codebuild
  role     = each.value.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = concat([
      {
        Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.codebuild[each.key].arn}:*"
      },
      {
        Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Resource = "${aws_s3_bucket.this["artifacts"].arn}/*"
      },
      {
        Effect = "Allow", Action = ["s3:GetBucketLocation", "s3:ListBucket"], Resource = aws_s3_bucket.this["artifacts"].arn
      }
      ], [for statement in [
        {
          Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.this["web"].arn
        },
        {
          Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.this["web"].arn}/*"
        },
        {
          Effect = "Allow", Action = ["lambda:UpdateFunctionCode", "lambda:GetFunctionConfiguration"], Resource = [for fn in aws_lambda_function.this : fn.arn]
        },
        {
          Effect = "Allow", Action = ["cloudfront:CreateInvalidation"], Resource = aws_cloudfront_distribution.dashboard.arn
        },
        {
          Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*"
        },
        {
          Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:DescribeImageScanFindings", "ecr:DescribeImages"], Resource = aws_ecr_repository.ml.arn
        },
        {
          Effect = "Allow", Action = ["sagemaker:UpdatePipeline", "sagemaker:StartPipelineExecution"], Resource = "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:pipeline/${local.name}"
        },
        {
          Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.sagemaker.arn, Condition = {
            StringEquals = {
              "iam:PassedToService" = "sagemaker.amazonaws.com"
            }
          }
        }
    ] : statement if each.key == "deploy"])
  })

}
resource "aws_codebuild_project" "this" {

  for_each       = aws_iam_role.codebuild
  name           = "${local.name}-${each.key}"
  service_role   = each.value.arn
  build_timeout  = 20
  queued_timeout = 15
  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = each.key == "verify" ? "buildspec.yml" : "buildspec-deploy.yml"

  }
  environment {

    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = each.key == "deploy"
    dynamic "environment_variable" {

      for_each = {

        PROJECT_NAME           = local.name, WEB_BUCKET = aws_s3_bucket.this["web"].id,
        LAKE_BUCKET            = aws_s3_bucket.this["lake"].id, ECR_REPOSITORY = aws_ecr_repository.ml.repository_url,
        ECR_NAME               = aws_ecr_repository.ml.name, SAGEMAKER_ROLE = aws_iam_role.sagemaker.arn,
        DISTRIBUTION_ID        = aws_cloudfront_distribution.dashboard.id,
        VITE_COGNITO_DOMAIN    = "https://${aws_cognito_user_pool_domain.dashboard.domain}.auth.${var.region}.amazoncognito.com",
        VITE_COGNITO_CLIENT_ID = aws_cognito_user_pool_client.dashboard.id,
        VITE_REDIRECT_URI      = "https://${aws_cloudfront_distribution.dashboard.domain_name}/",
        RUN_TRAINING           = tostring(var.run_training_after_deploy)

      }
      content {
        name  = environment_variable.key
        value = environment_variable.value

      }

    }

  }
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild[each.key].name
    }
  }

}
resource "aws_iam_role" "pipeline" {

  count = var.enable_ci ? 1 : 0
  name  = "${local.name}-codepipeline"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = "sts:AssumeRole", Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })

}
resource "aws_iam_role_policy" "pipeline" {

  count = var.enable_ci ? 1 : 0
  role  = aws_iam_role.pipeline[0].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["codeconnections:UseConnection", "codestar-connections:UseConnection"], Resource = var.connection_arn
      },
      {
        Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Resource = "${aws_s3_bucket.this["artifacts"].arn}/*"
      },
      {
        Effect = "Allow", Action = ["s3:GetBucketVersioning", "s3:GetBucketLocation"], Resource = aws_s3_bucket.this["artifacts"].arn
      },
      {
        Effect = "Allow", Action = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"], Resource = [for p in aws_codebuild_project.this : p.arn]
      }
    ]
  })

}
resource "aws_codepipeline" "this" {

  count    = var.enable_ci ? 1 : 0
  name     = local.name
  role_arn = aws_iam_role.pipeline[0].arn
  artifact_store {
    location = aws_s3_bucket.this["artifacts"].id
    type     = "S3"

  }
  stage {

    name = "Source"
    action {

      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]
      configuration = {
        ConnectionArn = var.connection_arn, FullRepositoryId = var.github_repository, BranchName = var.branch, DetectChanges = "true"
      }

    }

  }
  stage {

    name = "Verify"
    action {

      name            = "TestsAndValidation"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      configuration = {
        ProjectName = aws_codebuild_project.this["verify"].name
      }

    }

  }
  stage {

    name = "Approve"
    action {

      name     = "ReviewChangesAndCost"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Review tests, immutable ML image change, app changes, infrastructure plan outside this pipeline, and bounded demo cost."
      }

    }

  }
  stage {

    name = "Deploy"
    action {

      name            = "ApplicationAndPipelineDefinition"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      configuration = {
        ProjectName = aws_codebuild_project.this["deploy"].name
      }

    }

  }
  lifecycle {

    precondition {

      condition     = var.connection_arn != "" && var.github_repository != "" && var.ml_image_uri != ""
      error_message = "CI requires an authorized GitHub connection, owner/repository, and an existing ML pipeline image."

    }

  }

}

