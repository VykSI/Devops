variable "aws_region" {
  description = "AWS region in which resources will be created"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"
}

variable "db_username" {
  description = "RDS PostgreSQL username"
  type        = string
  default     = "app"
}

variable "db_password" {
  description = "RDS PostgreSQL password"
  type        = string
  sensitive   = true
}