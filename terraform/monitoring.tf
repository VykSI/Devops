# ============================================================
# CloudWatch Dashboards
# ============================================================

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
          title  = "ECS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.app.name,
              "ServiceName",
              aws_ecs_service.app.name
            ]
          ]

          period = 300
          stat   = "Average"
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ECS Memory Utilization"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "ECS/ContainerInsights",
              "MemoryUtilized",
              "ClusterName",
              aws_ecs_cluster.app.name
            ]
          ]

          period = 300
          stat   = "Average"
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ALB Request Count"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_lb.app.arn_suffix
            ]
          ]

          period = 300
          stat   = "Sum"
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target Response Time"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              aws_lb.app.arn_suffix
            ]
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
          title  = "ALB HTTP 5xx"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer",
              aws_lb.app.arn_suffix
            ]
          ]

          period = 300
          stat   = "Sum"
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "RDS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "AWS/RDS",
              "CPUUtilization",
              "DBInstanceIdentifier",
              aws_db_instance.app.identifier
            ]
          ]

          period = 300
          stat   = "Average"
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "RDS Database Connections"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "AWS/RDS",
              "DatabaseConnections",
              "DBInstanceIdentifier",
              aws_db_instance.app.identifier
            ]
          ]

          period = 300
          stat   = "Average"
        }
      }
    ]
  })
}


# ============================================================
# Application Dashboard
# ============================================================

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
          title  = "HTTP Request Rate"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "Application",
              "http_requests_total"
            ]
          ]

          period = 60
          stat   = "Sum"
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "HTTP Errors"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "Application",
              "http_requests_total",
              "status",
              "500"
            ]
          ]

          period = 60
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
          title  = "HTTP Request Duration"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            [
              "Application",
              "http_request_duration_seconds"
            ]
          ]

          period = 60
          stat   = "Average"
        }
      }
    ]
  })
}


# ============================================================
# CloudWatch Alarms
# ============================================================

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "devops-assignment-${var.environment}-ecs-cpu-high"
  alarm_description   = "ECS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  period             = 300
  threshold          = 80
  metric_name        = "CPUUtilization"
  namespace          = "AWS/ECS"
  statistic          = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = []

  tags = {
    Environment = var.environment
  }
}


resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name        = "devops-assignment-${var.environment}-alb-5xx"
  alarm_description = "ALB is returning server errors"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  period             = 300
  threshold          = 5

  metric_name = "HTTPCode_Target_5XX_Count"
  namespace   = "AWS/ApplicationELB"
  statistic   = "Sum"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = []

  tags = {
    Environment = var.environment
  }
}