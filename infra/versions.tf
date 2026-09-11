terraform {

  required_version = ">= 1.10, < 2.0"
  required_providers {

    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    archive = {
      source = "hashicorp/archive", version = "~> 2.7"
    }

  }

}
provider "aws" {

  region = var.region
  default_tags {
    tags = {
      Project = "StreamML", Environment = var.environment, Owner = "Portfolio"
    }
  }

}
data "aws_caller_identity" "current" {

}
data "aws_partition" "current" {

}
locals {

  name = "streamml-${var.environment}"
  buckets = {
    lake = "${local.name}-lake-${data.aws_caller_identity.current.account_id}", web = "${local.name}-web-${data.aws_caller_identity.current.account_id}", artifacts = "${local.name}-artifacts-${data.aws_caller_identity.current.account_id}"
  }

}

