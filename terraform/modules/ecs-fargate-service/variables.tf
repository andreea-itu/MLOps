variable "name" {
  description = "Resource name suffix."
  type        = string
}

variable "prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "ecs"
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

variable "image" {
  description = "Container image URI (e.g. <account>.dkr.ecr.<region>.amazonaws.com/repo:tag)."
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container."
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 1
}

variable "enable_alb" {
  description = "Create an Application Load Balancer (adds ~$16/month). If false, tasks use a public IP."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Subnet IDs for tasks (and ALB when enabled). Defaults to default VPC subnets."
  type        = list(string)
  default     = null
}
