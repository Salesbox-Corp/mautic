# Security Group para o EFS
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [local.ecs_tasks_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-efs-sg"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# EFS File System
resource "aws_efs_file_system" "mautic" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-efs"
  })
}

# Mount targets em cada subnet
resource "aws_efs_mount_target" "mautic" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.mautic.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# Access Point para o Mautic
resource "aws_efs_access_point" "mautic" {
  file_system_id = aws_efs_file_system.mautic.id

  posix_user {
    gid = 33  # www-data group
    uid = 33  # www-data user
  }

  root_directory {
    path = "/mautic"
    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "755"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ap"
  })
} 