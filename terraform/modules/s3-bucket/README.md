# S3 bucket module

Creates an S3 bucket for DVC remotes and artifact storage. Used as the project **datastore** (`mlops-postgrade-datastore-{env}`).

## Resources created

| Resource | Purpose |
|----------|---------|
| `aws_s3_bucket` | Bucket with configured name |
| `aws_s3_bucket_versioning` | Object versioning (enabled by default) |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE-S3 (AES256) |
| `aws_s3_bucket_public_access_block` | Block public access (enabled by default) |

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `bucket` | (required) | Bucket name |
| `tags` | `{}` | Resource tags |
| `versioning_enabled` | `true` | Enable S3 versioning |
| `block_public_access` | `true` | Apply restrictive public access block |

## Outputs

| Output | Description |
|--------|-------------|
| `bucket_id` | Bucket name (same as input `bucket`) |
| `bucket_arn` | Bucket ARN for IAM policies |

## Usage in this repo

Instantiated from [s3_buckets.tf](../../s3_buckets.tf):

```hcl
module "s3_bucket" {
  for_each = { for s3 in var.s3_buckets : s3.key => s3 }
  source   = "./modules/s3-bucket"

  bucket = join(var.delimiter, [each.value.key, var.environment])
  tags   = merge(try(each.value.tags, {}), { environment = var.environment })
}
```

Dev example: key `mlops-postgrade-datastore` → bucket **`mlops-postgrade-datastore-dev`**.

## DVC remote

Configure the ML app remote to match the bucket (prefix `/data` is conventional):

```text
s3://mlops-postgrade-datastore-dev/data
```

See `src/.dvc/config` and [../../../src/README.md](../../../src/README.md).

Verify bucket name after apply:

```bash
terraform output bucket_ids
```

## IAM

The GitHub Actions app OIDC role ([github-actions-oidc](../github-actions-oidc/)) receives `s3:ListBucket`, `s3:GetObject`, and `s3:PutObject` on this bucket ARN for CI `dvc pull` / `dvc push`.

## Related docs

- [../../README.md](../../README.md) — Terraform layout and outputs
- [../../../docs/dvc-runbook.md](../../../docs/dvc-runbook.md) — operational DVC workflow
