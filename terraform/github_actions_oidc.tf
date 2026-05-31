module "github_actions_app" {
  source = "./modules/github-actions-oidc"

  role_name = "github-actions-mlops-app-dev"

  allowed_subjects = [
    "repo:andreea-itu/MLOps:pull_request",
    "repo:andreea-itu/MLOps:ref:refs/heads/main",
    "repo:andreea-itu/MLOps:ref:refs/heads/release/*",
    "repo:andreea-itu/MLOps:environment:dev",
    "repo:andreea-itu/MLOps:environment:prd",
  ]

  ecr_repository_arns = [
    module.ecr_repository["app"].repository_arn,
  ]
  ecr_repository_name = module.ecr_repository["app"].repository_name

  s3_bucket_name = module.s3_bucket["mlops-postgrade-datastore"].bucket_id

  account_id = var.account_id

  s3_bucket_arns = [
    module.s3_bucket["mlops-postgrade-datastore"].bucket_arn,
  ]

  ecs_cluster_name = var.ecs_cluster_name
  ecs_service_name = var.ecs_service_name

  tags = {
    Environment = var.environment
    Project     = "mlops"
    ManagedBy   = "terraform"
  }
}
