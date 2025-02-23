# Security Group para o RDS
resource "aws_security_group" "rds" {
  name        = "mautic-shared-rds-sg"
  description = "Security group for shared RDS instance"
  vpc_id      = var.vpc_id

  # Permitir acesso MySQL de qualquer lugar (para GitHub Actions)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "mautic-shared-rds-sg"
  })
}

# Subnet group público para o RDS
resource "aws_db_subnet_group" "public" {
  name        = "mautic-shared-rds-subnet-group"
  description = "Public subnet group for shared RDS instance"
  subnet_ids  = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "mautic-shared-rds-subnet-group"
  })
}

# RDS Instance
resource "aws_db_instance" "shared" {
  identifier = var.identifier
  instance_class = var.instance_class
  allocated_storage = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  
  engine = var.engine
  engine_version = var.engine_version
  
  db_name = var.db_name
  username = var.username
  password = random_password.master_password.result
  
  backup_retention_period = var.backup_retention_period
  multi_az = var.multi_az

  # Configurações para acesso público
  publicly_accessible    = true
  db_subnet_group_name  = aws_db_subnet_group.public.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # Parâmetros adicionais
  parameter_group_name = aws_db_parameter_group.main.name
  
  tags = var.tags
}

# Parameter group para configurações específicas
resource "aws_db_parameter_group" "main" {
  family = var.family
  name   = "mautic-shared-params"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  tags = var.tags
}

# Senha aleatória para o RDS
resource "random_password" "master_password" {
  length  = 16
  special = true
  # Caracteres especiais permitidos pelo RDS
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

output "endpoint" {
  value = aws_db_instance.shared.endpoint
}

output "username" {
  value = aws_db_instance.shared.username
}

output "password" {
  value = random_password.master_password.result
  sensitive = true
} 