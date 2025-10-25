resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-rds-sg"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.app_name}-db"
  engine         = "mysql"
  engine_version = "8.4.6"
  instance_class = "db.t3.micro"  # 最小・最安のインスタンスタイプ

  db_name  = "myapp_production"
  username = "myapp"
  password = random_password.db_password.result

  allocated_storage     = 20  # 最小ストレージ
  max_allocated_storage = 0   # 自動スケーリング無効（コスト削減）
  storage_type          = "gp2"  # gp3より安い（小容量の場合）

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 1  # 最小バックアップ期間（7日→1日でコスト削減）

  tags = {
    Name = "${var.app_name}-db"
  }
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}