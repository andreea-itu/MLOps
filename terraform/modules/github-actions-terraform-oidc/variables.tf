variable "role_name" {
  description = "IAM role name for GitHub Actions Terraform workflows."
  type        = string
}

variable "allowed_subjects" {
  description = "GitHub OIDC 'sub' claim patterns allowed to assume this role."
  type        = list(string)
}

variable "terraform_state_bucket_name" {
  description = "S3 bucket used for Terraform remote state."
  type        = string
}

variable "attach_administrator_access" {
  description = "Attach AdministratorAccess so plan/apply can manage all resources (matches cicd-user)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}
