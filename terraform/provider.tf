terraform {
  required_providers {
    terraform = {
      required_version = ">= 1.10.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
  }
}

provider "aws" {
  region = var.aws_region
}


