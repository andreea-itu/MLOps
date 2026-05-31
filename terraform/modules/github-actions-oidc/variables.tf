variable "role_name" {
  description = "IAM role name for GitHub Actions."
  type        = string
}

variable "allowed_subjects" {
  description = "GitHub OIDC 'sub' claim patterns allowed to assume this role."
  type        = list(string)
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the workflow may push to."
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs for DVC remote access."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}
variable "ecr_repository_name" {
  description = "ECR repository name."
  type        = string
}
variable "s3_bucket_name" {
  description = "S3 bucket name."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for deploy workflow (empty disables ECS permissions)."
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name for deploy workflow (empty disables ECS permissions)."
  type        = string
  default     = ""
}
