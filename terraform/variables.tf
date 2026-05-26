variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  description = "Specifies the deployment environment of the resources (e.g., sandbox, dev, tst, acc, prd)"
  type        = string
  default     = "sandbox"
}

variable "delimiter" {
  description = "Resource name delimiter"
  type        = string
  default     = "-"
}

variable "s3_buckets" {
  description = "A list of S3 Buckets"
  type        = list(any)
  default     = []
}

variable "ecr_repositories" {
  description = "ECR repositories to create."
  type = list(object({
    key                          = string
    image_tag_mutability         = optional(string, "MUTABLE")
    image_scanning_configuration = optional(map(string), {})
    tags                         = optional(map(string), {})
  }))
  default = []
}

variable "apprunner_services" {
  description = "App Runner services to create."
  type = list(object({
    key                  = string
    source_configuration = any
    tags                 = optional(map(string), {})
  }))
  default = []
}
