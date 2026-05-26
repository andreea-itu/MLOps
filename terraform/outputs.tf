output "github_actions_app_role_arn" {
  description = "IAM role ARN for the application CI/CD workflow."
  value       = module.github_actions_app.role_arn
}

output "ecr_app_repository_name" {
  description = "ECR repository name for the application image."
  value       = module.ecr_repository["app"].repository_name
}
