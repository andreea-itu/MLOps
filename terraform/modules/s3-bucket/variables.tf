variable "bucket" {
  description = "Name of the S3 bucket."
  type        = string
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "versioning_enabled" {
  description = "Enable S3 object versioning."
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Apply a fully-restrictive public access block."
  type        = bool
  default     = true
}
