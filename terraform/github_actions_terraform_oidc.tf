module "github_actions_terraform" {
  source = "./modules/github-actions-terraform-oidc"

  role_name                   = "github-actions-mlops-terraform-dev"
  terraform_state_bucket_name = "tfremotebackendpostgrade"

  allowed_subjects = [
    "repo:andreea-itu/MLOps:pull_request",
    "repo:andreea-itu/MLOps:ref:refs/heads/main",
    "repo:andreea-itu/MLOps:ref:refs/heads/release/*",
    "repo:andreea-itu/MLOps:environment:dev",
    "repo:andreea-itu/MLOps:environment:prd",
  ]

  tags = {
    Environment = var.environment
    Project     = "mlops"
    ManagedBy   = "terraform"
  }
}
