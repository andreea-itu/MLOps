variable "name" {
  description = "Resource name suffix."
  type        = string
}

variable "prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "eks"
}

variable "delimiter" {
  description = "Resource name delimiter."
  type        = string
  default     = "-"
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to attach to resources."
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Public subnets only (no NAT gateway) to keep costs low."
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.31"
}

variable "instance_types" {
  description = "EC2 instance types for the managed node group (t3.micro is free-tier eligible)."
  type        = list(string)
  default     = ["t3.micro"]
}

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 1
}

variable "disk_size" {
  description = "Disk size in GiB for worker nodes."
  type        = number
  default     = 20
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API server is reachable from the public internet."
  type        = bool
  default     = true
}
