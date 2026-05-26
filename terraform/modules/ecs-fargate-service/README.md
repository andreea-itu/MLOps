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

## Defaults

- `enable_alb = false` — task gets a **public IP** (find it in ECS → service → task → networking). No stable DNS.
- `enable_alb = true` — stable `http://<alb-dns>` URL.

## First deploy

1. Push an image to ECR (`app-cicd-dev` workflow).
2. `terraform apply -var-file=environments/dev.tfvars`
3. Set GitHub variables: `ECS_CLUSTER_NAME` and `ECS_SERVICE_NAME` = `ecs-app-dev` (from `terraform output`).
