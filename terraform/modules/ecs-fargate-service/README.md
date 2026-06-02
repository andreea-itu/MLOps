# ECS Fargate service module

Runs a single-container API on **ECS Fargate** (no EKS control-plane fee).

## Cost (dev defaults)

| Item | Approx. monthly |
|------|-----------------|
| ECS cluster | $0 |
| Fargate 0.25 vCPU / 512 MiB (1 task, 24/7) | ~$9–12 |
| ALB (`enable_alb = true`) | +~$16 |
| CloudWatch logs (7-day retention) | ~$1 |

**Not free** — but much cheaper than EKS (~$73/mo control plane alone). Fits a **$100 AWS credit** if you tear down when idle.

## Key inputs

| Variable | Default | Notes |
|----------|---------|-------|
| `name` | (required) | Suffix; full name is `{prefix}-{name}` → e.g. `ecs-app-dev` |
| `image` | (required) | Container URI; root module sets ECR URL + `image_tag` from tfvars |
| `container_port` | `80` | Exposed port |
| `cpu` | `256` | Fargate CPU units (0.25 vCPU) |
| `memory` | `512` | MiB |
| `desired_count` | `1` | Running tasks |
| `enable_alb` | `false` | `true` adds ALB + stable DNS; `false` uses task public IP |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | ECS cluster name (same as service name in this module) |
| `service_name` | ECS service name |
| `url` | `http://<alb-dns>` when ALB enabled; otherwise `null` |
| `log_group_name` | CloudWatch log group (e.g. `/ecs/ecs-app-dev`) |

## Defaults

- `enable_alb = false` — task gets a **public IP** (find it in ECS → service → task → networking). No stable DNS.
- `enable_alb = true` — stable `http://<alb-dns>` URL via `terraform output ecs_app_url`.

## First deploy sequence

1. `terraform apply -var-file=environments/dev.tfvars` — creates cluster, service, task definition pointing at ECR `:<image_tag>` (default `latest` in tfvars).
2. Run **Application CI/CD** ([`app-reusable.yml`](../../../.github/workflows/app-reusable.yml)) on `main` — builds image, pushes `:<short-sha>`, registers new task definition, updates service.
3. Set GitHub variables from Terraform outputs:

   | Variable | Source |
   |----------|--------|
   | `ECS_CLUSTER_NAME` | `terraform output ecs_app_cluster_name` → `ecs-app-dev` |
   | `ECS_SERVICE_NAME` | `terraform output ecs_app_service_name` → `ecs-app-dev` |

4. Ensure app OIDC role has ECS IAM permissions — set `ecs_cluster_name` / `ecs_service_name` in tfvars (see [../../README.md](../../README.md)).

## GitHub Actions deploy

When `ECS_CLUSTER_NAME` and `ECS_SERVICE_NAME` repo variables are set, the release job:

1. Describes current task definition → registers new revision with CI image
2. Calls `update-service` (logs rollout state)
3. Waits `services-stable` and prints final status

Requires app OIDC IAM policy in [../github-actions-oidc/](../github-actions-oidc/) — see [../../README.md § OIDC IAM](../../README.md#oidc-iam--app-role).

## Related docs

- [../../README.md](../../README.md) — Terraform layout, outputs, IAM
- [../../../README.md](../../../README.md) — ECS API access and troubleshooting
