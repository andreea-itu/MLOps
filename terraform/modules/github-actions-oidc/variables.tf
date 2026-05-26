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
