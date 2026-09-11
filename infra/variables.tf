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
variable "ml_image_uri" {
  type        = string
  default     = ""
  description = "Immutable ECR image URI; empty skips pipeline creation until the image is built."

}
variable "enable_monitor" {
  type    = bool
  default = false

}
variable "auto_retrain" {
  type    = bool
  default = false

}
variable "enable_ci" {
  type    = bool
  default = false

}
variable "connection_arn" {
  type    = string
  default = ""

}
variable "github_repository" {
  type        = string
  default     = ""
  description = "Verified owner/repository, such as your-owner/streamml."

}
variable "branch" {
  type    = string
  default = "main"

}
variable "run_training_after_deploy" {
  type    = bool
  default = false

}

