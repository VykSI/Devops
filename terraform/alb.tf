# --------------------------------------------------
# Application Load Balancer
# --------------------------------------------------

resource "aws_lb" "app" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = aws_subnet.public[*].id

  access_logs {
    bucket  = aws_s3_bucket.alb_access_logs.id
    prefix  = "${var.environment}/alb"
    enabled = true
  }

  tags = {
    Name = "${var.environment}-alb"
  }
}

# --------------------------------------------------
# Target Group
# --------------------------------------------------

resource "aws_lb_target_group" "app" {
  name        = "${var.environment}-app-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.environment}-app-tg"
  }
}

# --------------------------------------------------
# HTTP Listener
# --------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}