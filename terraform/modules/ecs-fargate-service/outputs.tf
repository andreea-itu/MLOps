output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "url" {
  description = "HTTP URL when ALB is enabled; null when using task public IP only."
  value       = var.enable_alb ? "http://${aws_lb.this[0].dns_name}" : null
}

output "log_group_name" {
  description = "CloudWatch log group for container logs."
  value       = aws_cloudwatch_log_group.this.name
}
