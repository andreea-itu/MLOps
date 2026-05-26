environment = "dev"
aws_region  = "eu-west-1"

s3_buckets = [
  {
    key = "mlops-postgrade-datastore"
    tags = {
      Environment = "dev"
      Project     = "mlops"
    }
  },
  # Add second bucket
  {
    key = "mlops-postgrade-datastore-2"
    tags = {
      Environment = "dev"
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
      Environment = "dev"
      Project     = "mlops"
    }
  }
]

apprunner_services = [
  # {
  #   key = "app"
  #   source_configuration = {
  #     auto_deployments_enabled = true
  #     image_repository = {
  #       image_identifier      = "082721030339.dkr.ecr.eu-west-1.amazonaws.com/ecr-app-dev:latest"
  #       image_repository_type = "ECR"
  #       image_configuration = {
  #         port = "8080"
  #       }
  #     }
  #   }
  #   tags = {
  #     Project = "mlops"
  #   }
  # }
]
