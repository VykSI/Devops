resource "aws_db_subnet_group" "app" {
  name = "${var.environment}-db-subnet-group"

  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "app" {
  identifier = "${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "17"

  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "app"
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  backup_retention_period = 0

  deletion_protection = false

  skip_final_snapshot = true

  apply_immediately = true

  tags = {
    Name = "${var.environment}-postgres"
  }
}