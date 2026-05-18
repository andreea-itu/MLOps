environment = "dev"
aws_region  = "eu-west-1"

s3_buckets = [
  {
    key = "mlops-postgrade-datastore"
    tags = {
      Environment = "dev"
      Project     = "mlops"
    }
  }
]
