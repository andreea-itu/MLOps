environment = "prd"
aws_region  = "eu-west-1"
account_id  = "082721030339"

ecr_repository_name = "ecr-app-prd"

s3_buckets = [
  {
    key = "mlops-postgrade-datastore"
    tags = {
      Environment = "prd"
      Project     = "mlops"
    }
  },
  # Add second bucket
  {
    key = "mlops-postgrade-datastore-2"
    tags = {
      Environment = "prd"
      Project     = "mlops"
    }
  }
]

ecr_repositories = [
  {
    key = "app"
    image_scanning_configuration = {
      scan_on_push = true
    }
    tags = {
      Environment = "prd"
      Project     = "mlops"
    }
  }
]


ecs_services = [
  {
    key            = "app"
    image_tag      = "latest"
    container_port = 80
    cpu            = 256
    memory         = 512
    desired_count  = 1
    enable_alb     = false
    tags = {
      Environment = "prd"
      Project     = "mlops"
    }
  }
]
