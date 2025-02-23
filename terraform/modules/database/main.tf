module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  identifier = "${var.project_name}-db"

  engine               = "mariadb"
  engine_version       = "11.4.4"
  family              = "mariadb11.4"
  major_engine_version = "11.4"
  instance_class       = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  port     = 3306

  multi_az               = var.multi_az
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  maintenance_window      = var.maintenance_window
  backup_window          = var.backup_window
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot    = var.skip_final_snapshot

  tags = var.tags
} 