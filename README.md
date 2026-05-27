# MLOps — Insurance classifier

End-to-end MLOps project: versioned training data (DVC + S3), a scikit-learn pipeline (ingest → clean → train → evaluate), containerized FastAPI inference, and AWS infrastructure managed with Terraform and GitHub Actions.

| Area | Location | Documentation |
|------|----------|---------------|
| ML code, DVC, Docker (local) | [`src/`](src/) | [src/README.md](src/README.md) |
| Kubernetes (optional, MLflow registry) | [`k8s/`](k8s/) | [k8s/README.md](k8s/README.md) |
| AWS infrastructure | [`terraform/`](terraform/) | This file |

## What is implemented today

```mermaid
flowchart LR
  subgraph dev["Local / CI"]
    DVC[DVC + S3 datastore]
    Train[main.py pipeline]
    Model[models/model.pkl]
    DVC --> Train --> Model
  end
  subgraph aws["AWS (Terraform)"]
    S3[(S3 buckets)]
    ECR[ECR app image]
    ECS[ECS Fargate API]
    OIDC[GitHub OIDC role]
  end
  subgraph cicd["GitHub Actions"]
    PR[PR: plan + lint + build]
    Main[main: apply + deploy dev]
  end
  Train --> ECR
  ECR --> ECS
  DVC --- S3
  OIDC --> ECR
  PR --> ECR
  Main --> ECS
```

- **Application**: Binary insurance claim classifier; FastAPI serves `GET /` (health) and `POST /predict`.
- **Data**: DVC tracks `src/data/`; remote default is `s3://mlops-postgrade-datastore-dev/data` (see `src/.dvc/config`).
- **CI (dev)**: On PR → Terraform plan + app lint/build (no deploy). On merge to `main` → Terraform apply (if `terraform/` changed) + retrain, Docker build, push to ECR, ECS rolling deploy.
- **CI (prd)**: On PR to `release/**` → plan + verify dev ECR image exists for the commit. Production promote/deploy is implemented in `app-promote-reusable.yml` (copy image dev → prd ECR, update ECS task definition).
- **Runtime (AWS)**: **ECS Fargate** hosts the API (cheaper than EKS for coursework). **EKS manifests** under `k8s/` are an optional path when using MLflow Model Registry instead of baking `model.pkl` into the image.

## Repository layout

```text
mlops/
├── .github/workflows/
│   ├── dev-pipeline.yml          # main branch: infra + app CI/CD
│   ├── prd-pipeline.yml          # release/** branches: infra + app verify/promote
│   ├── app-reusable.yml          # lint, dvc pull, train, build, ECR, ECS (dev)
│   └── app-promote-reusable.yml  # verify / promote dev image → prd
├── src/                          # Python app (see src/README.md)
├── terraform/                    # S3, ECR, ECS, GitHub OIDC
├── k8s/                          # Optional EKS + MLflow serving
└── README.md                     # This file
```

## Glossary

| Term | Meaning in this repo |
|------|---------------------|
| **DVC** (Data Version Control) | Tracks large files outside Git via `.dvc` metadata; stores blobs in S3. |
| **Datastore** | S3 bucket prefix used as the DVC remote (`mlops-postgrade-datastore-{env}`). |
| **ML pipeline** | `main.py`: ingest → clean → train → evaluate; configured in `src/config.yml`. |
| **Model artifact** | `src/models/model.pkl` (joblib pipeline: preprocess + SMOTE + classifier). |
| **MLflow** | Optional experiment tracking and Model Registry; training registers when `MLFLOW_TRACKING_URI` is set; serving can load from registry via `model_loader.py`. |
| **ECR** | Amazon container registry; CI pushes `:<short-sha>` and `:latest`. |
| **ECS Fargate** | Serverless containers running the API; GitHub Actions triggers `update-service` after push. |
| **OIDC** | GitHub Actions assumes an IAM role (no long-lived keys in workflows) using `vars.AWS_ROLE_ARN`. |
| **IaC** | Terraform modules for S3, ECR, ECS, and the GitHub Actions IAM role. |

## Prerequisites

- [Python](https://www.python.org/) 3.12–3.13, [Poetry](https://python-poetry.org/)
- [Docker](https://docs.docker.com/get-docker/)
- [Terraform](https://www.terraform.io/) ≥ 1.10
- [AWS CLI](https://aws.amazon.com/cli/) configured for your account
- [DVC](https://dvc.org/) with `dvc-s3` (installed via Poetry in `src/`)

## Infrastructure (Terraform)

### Resources (per environment)

| Module | Purpose |
|--------|---------|
| `s3-bucket` | DVC / artifact storage (`mlops-postgrade-datastore-{env}`, etc.) |
| `ecr-repository` | Application Docker images (`app` key → `ecr-app-{env}` naming) |
| `ecs-fargate-service` | FastAPI on Fargate (`app` service) |
| `github-actions-oidc` | IAM role for CI: ECR push, S3/DVC, ECS deploy |

Environments: `terraform/environments/dev.tfvars`, `prd.tfvars`. Backends: `terraform/backends/dev.conf`, `prd.conf`.

### Bootstrap (one-time, local)

```bash
cd terraform
terraform init -backend-config=backends/dev.conf
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

Useful outputs:

```bash
terraform output github_actions_app_role_arn
terraform output ecr_app_repository_name
terraform output ecs_app_cluster_name
terraform output ecs_app_service_name
terraform output bucket_ids
```

### GitHub repository configuration

Set **repository or environment variables** (and secrets only where Terraform still uses keys for `plan`/`apply`):

| Variable | Example source | Used by |
|----------|----------------|---------|
| `AWS_ROLE_ARN` | `terraform output github_actions_app_role_arn` | App workflows (OIDC) |
| `ECR_REPOSITORY` | `terraform output ecr_app_repository_name` | Build / promote |
| `ECS_CLUSTER_NAME` | `terraform output ecs_app_cluster_name` | Deploy |
| `ECS_SERVICE_NAME` | `terraform output ecs_app_service_name` | Deploy |
| `DEV_ECR_REPOSITORY` | Dev repo name (prd only) | `app-promote-reusable.yml` |

GitHub **environments**: `dev`, `prd` (protection rules optional).

OIDC trust subjects are defined in `terraform/github_actions_oidc.tf` (adjust `repo:owner/name` if you fork).

## CI/CD workflows

### Dev (`dev-pipeline.yml`)

| Event | Infra | Application |
|-------|-------|-------------|
| PR to `main` | `fmt`, `plan` (comment on PR) | `app-reusable.yml` with `deploy: false` |
| Push to `main` | `apply` if `terraform/**` changed | `app-reusable.yml` with `deploy: true` |

Application job (`app-reusable.yml`): Ruff → `dvc pull` → `python main.py` → `docker build` → push ECR `<short-sha>` + `:latest` → register ECS task definition with the new image → `update-service`.

Image is built from `src/Dockerfile` (includes `models/model.pkl` produced in the same job).

### Production (`prd-pipeline.yml` + `app-promote-reusable.yml`)

| Event | Behavior |
|-------|----------|
| PR to `release/**` | Terraform plan; **App — Verify** (lint + confirm image exists in dev ECR for commit) |
| Push to `release/**` | Terraform apply (when configured); promote copies dev image to prd ECR and registers new ECS task definition |

Promote flow does **not** rebuild from source: it `docker pull` dev tag → retag → push prd → update ECS.

Manual promote: run **Application Promote** workflow with commit SHA and `release: true`.

## Accessing the deployed API (ECS)

With `enable_alb = false` (current dev/prd tfvars), tasks get a **public IP** on port 80. There is no stable hostname: `terraform output ecs_app_url` is null until you enable an ALB.

| Setting | Effect |
|---------|--------|
| `assign_public_ip = true` | Each Fargate task has a public IPv4 address |
| `enable_alb = false` | Security group allows HTTP from `0.0.0.0/0`; no load balancer |
| `enable_alb = true` | Use `terraform output ecs_app_url` → `http://<alb-dns>/` (~$16/mo extra; see `terraform/modules/ecs-fargate-service/README.md`) |

**Dev resource names** (prd: replace `dev` with `prd` — e.g. `ecs-app-prd`, `ecr-app-prd`, log group `/ecs/ecs-app-prd`):

| Resource | Dev name |
|----------|----------|
| ECS cluster / service | `ecs-app-dev` |
| ECR repository | `ecr-app-dev` |
| CloudWatch log group | `/ecs/ecs-app-dev` |
| Region | `eu-west-1` |

Set shell variables once (adjust for prd):

```bash
export AWS_REGION=eu-west-1
export ECS_CLUSTER=ecs-app-dev
export ECS_SERVICE=ecs-app-dev
export ECR_REPO=ecr-app-dev
```

### Get the task public IP (CLI)

```bash
TASK_ARN=$(aws ecs list-tasks \
  --cluster "$ECS_CLUSTER" \
  --service-name "$ECS_SERVICE" \
  --desired-status RUNNING \
  --region "$AWS_REGION" \
  --query 'taskArns[0]' --output text)

ENI=$(aws ecs describe-tasks \
  --cluster "$ECS_CLUSTER" \
  --tasks "$TASK_ARN" \
  --region "$AWS_REGION" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI" \
  --region "$AWS_REGION" \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

echo "PUBLIC_IP=$PUBLIC_IP"
```

**Console:** ECS → Clusters → **ecs-app-dev** → Services → **ecs-app-dev** → Tasks → running task → **Networking** → **Public IP**.

### Call the API

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Health: `{"health_check":"OK"}` |
| `/predict` | POST | Inference |
| `/docs` | GET | Swagger UI |

```bash
curl "http://${PUBLIC_IP}/"

curl -X POST "http://${PUBLIC_IP}/predict" \
  -H "Content-Type: application/json" \
  -d '{"Gender":"Male","Age":49,"HasDrivingLicense":1,"RegionID":28,"Switch":0,"PastAccident":"1-2 Year","AnnualPremium":1885.05}'

curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://${PUBLIC_IP}/docs"
```

Browser: `http://<PUBLIC_IP>/docs`

## Testing (smoke checks)

1. **Local pipeline** — [src/README.md § Testing](src/README.md#testing)
2. **After CI deploy** — health + predict against ECS task IP (above)
3. **PR validation** — green **Dev — Build on PR** workflow (lint + Docker build)

Automated `pytest` suites are not checked in yet; CI relies on lint, training, and image build.

## Troubleshooting

### ECS (dev / prd)

Use the [environment variables](#accessing-the-deployed-api-ecs) above (`ECS_CLUSTER`, `ECS_SERVICE`, `ECR_REPO`, `AWS_REGION`). Work through these in order.

**A. Service and task health**

```bash
aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,pending:pendingCount,events:events[0:5]}'
```

- `runningCount = 0` → task failed to start; check CloudWatch logs and ECR tags (B–C below).
- `runningCount = 1` but `curl` times out → wrong/stale public IP, security group, or local firewall blocking outbound HTTP to the task IP.

**B. CloudWatch logs**

Log group: `/ecs/ecs-app-dev` (or `/ecs/ecs-app-prd`).

```bash
aws logs tail "/ecs/${ECS_SERVICE}" --region "$AWS_REGION" --since 1h --follow
```

Look for `CannotPullContainerError`, image not found, or Python tracebacks (e.g. missing `models/model.pkl` — the production `src/Dockerfile` copies `models/` at build time; CI must run `python main.py` before `docker build`).

**C. ECR image tags vs task definition**

CI registers a new task definition pointing at `:<short-sha>` (and also pushes `:latest`). If the running task still looks stale, compare tags and the active task definition image:

```bash
aws ecr describe-images \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --query 'imageDetails[*].imageTags' \
  --output table

aws ecs describe-task-definition \
  --task-definition "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text
```

If deploy was skipped (no `src/**` change), re-run the workflow on `main` or push a small `src/` change.

**D. Recent stopped tasks**

```bash
STOPPED=$(aws ecs list-tasks \
  --cluster "$ECS_CLUSTER" \
  --service-name "$ECS_SERVICE" \
  --desired-status STOPPED \
  --region "$AWS_REGION" \
  --max-items 3 \
  --query 'taskArns' --output text)

aws ecs describe-tasks \
  --cluster "$ECS_CLUSTER" \
  --tasks $STOPPED \
  --region "$AWS_REGION" \
  --query 'tasks[*].{stoppedReason:stoppedReason,containers:containers[*].{reason:reason,exitCode:exitCode}}'
```

**E. Force a new deployment**

```bash
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment \
  --region "$AWS_REGION"
```

Or re-run the **Dev — Build on PR, Release on main** workflow on `main` (with `deploy: true` on merge).

**F. Stable URL (optional)**

```bash
# In terraform/environments/dev.tfvars set enable_alb = true, then:
cd terraform
terraform apply -var-file=environments/dev.tfvars
terraform output ecs_app_url
```

With ALB enabled, tasks only accept HTTP from the load balancer, not directly from the task public IP.

**G. Local baseline (app vs AWS)**

If ECS fails but the app is fine locally, see [src/README.md](src/README.md): `dvc pull`, Docker on `localhost:8080`, curl `/` and `/predict`.

### General

| Symptom | Likely cause | What to do |
|---------|----------------|------------|
| `dvc pull` / `403` on S3 | AWS credentials or wrong remote URL | `aws sts get-caller-identity`; check `src/.dvc/config` matches `terraform output bucket_ids` |
| CI: `Set repository variable AWS_ROLE_ARN` | Missing GitHub vars | Apply Terraform; copy outputs to repo/environment variables |
| CI: OIDC assume role failed | Trust policy `sub` mismatch | Compare workflow log `sub=` with `allowed_subjects` in `github_actions_oidc.tf` |
| Docker build: `models/` missing | Train skipped locally | Run `python main.py` or `docker compose run --rm train` before `docker build` |
| API returns 500 on `/predict` | No model in container | Local: mount `models/`; ECS: ensure CI train step ran before image build |
| ECS deploy OK but old behavior | Task still on old image | ECR tags + task definition image (§ C above); force new deployment (§ E) |
| `pathspec` / DVC import error | Incompatible `pathspec` 1.x | Use Poetry lockfile (`pathspec < 1.0` pinned in `pyproject.toml`) |
| Plan/apply fails in GHA | Backend or secrets | Verify `AWS_ACCESS_KEY_ID` / `SECRET` for Terraform jobs; `terraform init -backend-config=...` locally |

## Optional: EKS + MLflow

For registry-based models (no `model.pkl` in the image), see [k8s/README.md](k8s/README.md): build `src/Dockerfile` (production serve) and `src/docker/train/Dockerfile`, push to ECR, set `MLFLOW_*` env vars.

## Further reading

- [src/README.md](src/README.md) — DVC, training, Docker Compose, local API testing, ML troubleshooting
- [terraform/modules/ecs-fargate-service/README.md](terraform/modules/ecs-fargate-service/README.md) — ECS costs and ALB option
