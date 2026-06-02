# Terraform — AWS infrastructure

Provisions S3 (DVC remote), ECR, ECS Fargate, and GitHub OIDC IAM roles for CI/CD. Environment-specific values live in `environments/*.tfvars`; remote state in S3 via `backends/*.conf`.

## Root layout

| File | Purpose |
|------|---------|
| `provider.tf` | AWS provider and region |
| `variables.tf` | Root input variables |
| `outputs.tf` | Values for GitHub repo variables and local ops |
| `s3_buckets.tf` | S3 buckets (`module.s3_bucket`) |
| `ecr_repositories.tf` | ECR repos (`module.ecr_repository`) |
| `ecs_services.tf` | ECS Fargate services (`module.ecs_service`) |
| `github_actions_oidc.tf` | App CI/CD IAM role (ECR, S3, ECS) |
| `github_actions_terraform_oidc.tf` | Terraform CI IAM role |
| `apprunner_services.tf` | Optional App Runner (empty in dev tfvars) |

## Modules

| Module | Directory | Purpose |
|--------|-----------|---------|
| `s3-bucket` | [modules/s3-bucket/](modules/s3-bucket/) | DVC / artifact storage |
| `ecr-repository` | [modules/ecr-repository/](modules/ecr-repository/) | Container image registry |
| `ecs-fargate-service` | [modules/ecs-fargate-service/](modules/ecs-fargate-service/) | FastAPI on Fargate |
| `github-actions-oidc` | [modules/github-actions-oidc/](modules/github-actions-oidc/) | App workflow IAM (OIDC) |
| `github-actions-terraform-oidc` | [modules/github-actions-terraform-oidc/](modules/github-actions-terraform-oidc/) | Terraform workflow IAM (OIDC) |
| `app-runner-service` | [modules/app-runner-service/](modules/app-runner-service/) | Optional; not used in current envs |
| `eks-cluster` | [modules/eks-cluster/](modules/eks-cluster/) | Optional; use `k8s/` manifests instead |

## Naming convention

Resources use `{prefix}-{key}-{environment}` (delimiter `-`, from root `var.delimiter` and `var.environment`):

| Resource | Key in tfvars | Dev example |
|----------|---------------|-------------|
| S3 bucket | `mlops-postgrade-datastore` | `mlops-postgrade-datastore-dev` |
| ECR repo | `app` | `ecr-app-dev` |
| ECS cluster / service | `app` | `ecs-app-dev` |
| CloudWatch logs | (derived) | `/ecs/ecs-app-dev` |

## Environments

| Environment | Var file | Backend config |
|-------------|----------|----------------|
| dev | `environments/dev.tfvars` | `backends/dev.conf` |
| prd | `environments/prd.tfvars` | `backends/prd.conf` |
| tst | `environments/tst.tfvars` | `backends/tst.conf` |

Dev tfvars also set GitHub Actions ECS IAM wiring:

```hcl
ecs_cluster_name = "ecs-app-dev"
ecs_service_name = "ecs-app-dev"
```

These must match the ECS module outputs and are passed into `github-actions-oidc` so the app role receives ECS deploy permissions.

## Bootstrap (local)

```bash
cd terraform
terraform init -backend-config=backends/dev.conf
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

## CI apply (GitHub Actions)

[`terraform-reusable.yml`](../.github/workflows/terraform-reusable.yml) runs on path changes to `terraform/**`:

1. **Format** — `terraform fmt -check -recursive`
2. **Plan** — OIDC via `vars.AWS_TERRAFORM_ROLE_ARN`; posts plan to PR
3. **Apply** — on push to `main` only; manual approval in GitHub environment `dev`; applies saved plan artifact

## Outputs → GitHub variables

| Terraform output | GitHub variable | Used by |
|------------------|-----------------|---------|
| `github_actions_app_role_arn` | `AWS_ROLE_ARN` | App / data workflows |
| `github_actions_terraform_role_arn` | `AWS_TERRAFORM_ROLE_ARN` | `terraform-reusable.yml` |
| `ecr_app_repository_name` | `ECR_REPOSITORY` | Build / promote |
| `ecs_app_cluster_name` | `ECS_CLUSTER_NAME` | ECS deploy |
| `ecs_app_service_name` | `ECS_SERVICE_NAME` | ECS deploy |
| `bucket_ids` | (configure DVC remote) | `src/.dvc/config` |

Prd promote also uses `DEV_ECR_REPOSITORY` (dev ECR repo name).

```bash
terraform output github_actions_app_role_arn
terraform output github_actions_terraform_role_arn
terraform output ecr_app_repository_name
terraform output ecs_app_cluster_name
terraform output ecs_app_service_name
terraform output bucket_ids
```

## OIDC IAM — app role

Defined in [github_actions_oidc.tf](github_actions_oidc.tf) → [modules/github-actions-oidc/](modules/github-actions-oidc/).

Role name: `github-actions-mlops-app-dev` (adjust per environment).

Permissions:

| Area | Actions | Resource scope |
|------|---------|----------------|
| ECR | push/pull, auth token | App repository ARN |
| S3 | ListBucket, GetObject, PutObject | DVC bucket ARN |
| ECS service | DescribeServices, UpdateService | Cluster + service ARNs |
| ECS task definition | DescribeTaskDefinition, RegisterTaskDefinition | `*` (required by AWS) |
| IAM | PassRole | `{ecs_service_name}-execution`, `{ecs_service_name}-task` roles |

**Important:** `DescribeTaskDefinition` and `RegisterTaskDefinition` do not support resource-level permissions. They must use `"Resource": "*"` in a separate IAM statement from cluster/service actions. Without this split, CI fails with `AccessDenied` on describe/register even when `DescribeServices` works.

Trust policy subjects are in `allowed_subjects` in [github_actions_oidc.tf](github_actions_oidc.tf) — update `repo:owner/name` if you fork.

## OIDC IAM — Terraform role

Defined in [github_actions_terraform_oidc.tf](github_actions_terraform_oidc.tf) → [modules/github-actions-terraform-oidc/](modules/github-actions-terraform-oidc/).

Role name: `github-actions-mlops-terraform-dev`.

Permissions:

- Read/write Terraform state bucket (`tfremotebackendpostgrade`)
- `AdministratorAccess` managed policy (for full resource management in CI)

This role is **not** used by application deploy workflows — only by `terraform-reusable.yml`.

## Module READMEs

- [modules/s3-bucket/README.md](modules/s3-bucket/README.md)
- [modules/ecs-fargate-service/README.md](modules/ecs-fargate-service/README.md)

## Related docs

- [../README.md](../README.md) — project overview, ECS API access, troubleshooting
- [../src/README.md](../src/README.md) — ML app, DVC, local Docker
