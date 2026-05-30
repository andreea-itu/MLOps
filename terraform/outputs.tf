output "github_actions_app_role_arn" {
  description = "IAM role ARN for the application CI/CD workflow."
  value       = module.github_actions_app.role_arn
}

output "github_actions_terraform_role_arn" {
  description = "IAM role ARN for Terraform plan/apply in GitHub Actions."
  value       = module.github_actions_terraform.role_arn
}

output "ecr_app_repository_name" {
  description = "ECR repository name for the application image."
  value       = module.ecr_repository["app"].repository_name
}

output "ecs_app_cluster_name" {
  description = "ECS cluster name for the application service."
  value       = try(module.ecs_service["app"].cluster_name, null)
}

output "ecs_app_service_name" {
  description = "ECS service name for the application."
  value       = try(module.ecs_service["app"].service_name, null)
}

output "ecs_app_url" {
  description = "HTTP URL when ALB is enabled (null = use task public IP in ECS console)."
  value       = try(module.ecs_service["app"].url, null)
}

output "bucket_ids" {
  value       = { for k, b in module.s3_bucket : k => b.bucket_id }
  description = "Bucket names by key."
}
