data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${var.environment}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role = aws_iam_role.ecs_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.environment}/database/password"

  tags = {
    Name = "${var.environment}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string = var.db_password
}

data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.db_password.arn
    ]
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.environment}-ecs-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

# --------------------------------------------------
# ECS Task Role
# --------------------------------------------------

resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${var.environment}-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_metrics" {
  name = "${var.environment}-ecs-task-metrics"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "cloudwatch:PutMetricData"
        ]

        Resource = "*"
      }
    ]
  })
}