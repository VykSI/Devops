resource "aws_ecr_repository" "app" {
  name                 = "${var.environment}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.environment}-app-ecr"
  }
}