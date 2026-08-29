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

variable "ecs_desired_count" {
  description = "Number of ECS application tasks"
  type        = number
  default     = 1
}

variable "github_repository" {
  description = "GitHub repository in owner/repository format"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "alarm_email" {
  description = "Email address for CloudWatch failure notifications"
  type        = string
  default     = ""
}

variable "ecs_cpu_alarm_threshold" {
  description = "ECS CPU percentage that triggers an alarm"
  type        = number
  default     = 80
}

variable "alb_5xx_alarm_threshold" {
  description = "ALB target 5xx count that triggers an alarm"
  type        = number
  default     = 5
}

variable "alb_latency_alarm_threshold_seconds" {
  description = "ALB target response time in seconds that triggers an alarm"
  type        = number
  default     = 1
}

variable "rds_cpu_alarm_threshold" {
  description = "RDS CPU percentage that triggers an alarm"
  type        = number
  default     = 80
}

variable "rds_free_storage_alarm_threshold_bytes" {
  description = "RDS free storage in bytes below which an alarm triggers"
  type        = number
  default     = 5368709120
}

variable "ecs_min_running_tasks" {
  description = "Minimum running ECS tasks before the service health alarm triggers"
  type        = number
  default     = 1
}