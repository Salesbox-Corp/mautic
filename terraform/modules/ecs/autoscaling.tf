# Target de Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  
  depends_on = [aws_ecs_service.main]
}

# Scaling por CPU
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_cpu_utilization
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
  
  depends_on = [aws_appautoscaling_target.ecs]
}

# Scaling por Memória
resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.project_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_memory_utilization
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
  
  depends_on = [aws_appautoscaling_target.ecs]
}

# Scaling por Requisições do ALB
resource "aws_appautoscaling_policy" "alb" {
  name               = "${var.project_name}-alb-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_alb_request_count
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label        = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.main.arn_suffix}"
    }
  }
  
  depends_on = [aws_appautoscaling_target.ecs, aws_lb.main, aws_lb_target_group.main]
}

# CloudWatch Alarms para monitoramento
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.project_name}-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period             = "60"
  statistic          = "Average"
  threshold          = "85"
  alarm_description  = "CPU utilization high"
  alarm_actions      = var.alarm_actions

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }
  
  depends_on = [aws_ecs_service.main]
}

resource "aws_cloudwatch_metric_alarm" "service_memory_high" {
  alarm_name          = "${var.project_name}-memory-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period             = "60"
  statistic          = "Average"
  threshold          = "85"
  alarm_description  = "Memory utilization high"
  alarm_actions      = var.alarm_actions

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }
  
  depends_on = [aws_ecs_service.main]
} 