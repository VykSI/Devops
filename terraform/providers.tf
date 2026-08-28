provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-platform-assignment"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}