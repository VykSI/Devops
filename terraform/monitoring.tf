resource "aws_sns_topic" "monitoring" {
  name = "devops-assignment-${var.environment}-monitoring-failures"

  tags = {
    Name = "${var.environment}-monitoring-failures"
  }
}

resource "aws_sns_topic_subscription" "monitoring_email" {
  count = var.alarm_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.monitoring.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "devops-assignment-${var.environment}-application"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix]]
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Response Errors"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.app.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.app.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Target Response Time"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix]]
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS Service CPU and Memory"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.app.name, "ServiceName", aws_ecs_service.app.name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.app.name, "ServiceName", aws_ecs_service.app.name]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "ECS Running Tasks"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", aws_ecs_cluster.app.name, "ServiceName", aws_ecs_service.app.name]]
          period  = 300
          stat    = "Average"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "devops-assignment-${var.environment}-infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS CPU Utilization"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.app.identifier]]
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS Database Connections"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.app.identifier]]
          period  = 300
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS Free Storage"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.app.identifier]]
          period  = 300
          stat    = "Minimum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ECS Service Health"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", aws_ecs_cluster.app.name, "ServiceName", aws_ecs_service.app.name]]
          period  = 300
          stat    = "Average"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "devops-assignment-${var.environment}-ecs-cpu-high"
  alarm_description   = "ECS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = var.ecs_cpu_alarm_threshold
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  statistic           = "Average"
  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.app.name
  }
  alarm_actions = [aws_sns_topic.monitoring.arn]
  tags          = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  alarm_name          = "devops-assignment-${var.environment}-ecs-running-tasks-low"
  alarm_description   = "ECS service has fewer running tasks than required"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = var.ecs_min_running_tasks
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  statistic           = "Minimum"
  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.app.name
  }
  alarm_actions = [aws_sns_topic.monitoring.arn]
  tags          = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "devops-assignment-${var.environment}-alb-5xx"
  alarm_description   = "ALB is returning server errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = var.alb_5xx_alarm_threshold
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  statistic           = "Sum"
  dimensions          = { LoadBalancer = aws_lb.app.arn_suffix }
  alarm_actions       = [aws_sns_topic.monitoring.arn]
  tags                = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "devops-assignment-${var.environment}-alb-latency-high"
  alarm_description   = "ALB target response time is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 300
  threshold           = var.alb_latency_alarm_threshold_seconds
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  extended_statistic  = "p95"
  dimensions          = { LoadBalancer = aws_lb.app.arn_suffix }
  alarm_actions       = [aws_sns_topic.monitoring.arn]
  tags                = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "devops-assignment-${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = var.rds_cpu_alarm_threshold
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.app.identifier }
  alarm_actions       = [aws_sns_topic.monitoring.arn]
  tags                = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "devops-assignment-${var.environment}-rds-free-storage-low"
  alarm_description   = "RDS free storage is too low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = var.rds_free_storage_alarm_threshold_bytes
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  statistic           = "Minimum"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.app.identifier }
  alarm_actions       = [aws_sns_topic.monitoring.arn]
  tags                = { Environment = var.environment }
}
