resource "aws_s3_bucket" "this" {
  bucket = "mlopspostgradestate"

  tags = {
    Name        = "state"
    Environment = "dev"
    Project     = "mlops"
  }
}
