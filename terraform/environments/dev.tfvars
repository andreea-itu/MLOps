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
