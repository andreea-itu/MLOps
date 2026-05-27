# ML application — data versioning, training, and serving

Insurance claim classifier: version data with **DVC**, run an sklearn pipeline, serve predictions with **FastAPI**, and package with **Docker**. Infrastructure, ECS deployment, and CI/CD are documented in the [repository README](../README.md).

## Glossary (ML-focused)

| Term | Short definition |
|------|------------------|
| **DVC** | Versions datasets and large artifacts in S3; Git only stores small `.dvc` pointer files (hashes). |
| **`.dvc` file** | Metadata for a tracked path (e.g. `data.dvc`); commit this, not the raw data. |
| **`dvc push` / `dvc pull`** | Upload/download actual files to/from the configured S3 remote. |
| **Pipeline** | `main.py` orchestration: ingest → clean → train → evaluate. |
| **Artifact** | Trained `models/model.pkl` (preprocessor + SMOTE + classifier). |
| **MLflow** | Optional: log/register models when `MLFLOW_TRACKING_URI` is set during training; production serve can load `models:/name/Production`. |
| **Inference API** | `app.py` — loads model via `model_loader.py` (local file or MLflow). |

## Prerequisites

- Python 3.12–3.13
- [Poetry](https://python-poetry.org/) (dependencies and lockfile in this directory)
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose (local containers)
- [AWS CLI](https://aws.amazon.com/cli/) (for `dvc pull` from S3)

## Project structure

```text
src/
├── app.py                 # FastAPI inference API
├── main.py                # Full ML pipeline entrypoint
├── model_loader.py        # Local pkl vs MLflow registry
├── config.yml             # Data paths, model hyperparameters
├── pyproject.toml         # Poetry deps (dvc, sklearn, fastapi, mlflow, ruff)
├── Dockerfile             # Production/CI image (COPY models/ into image)
├── docker-compose.yml     # Local multi-stage: ingest → clean → train → serve
├── data/                  # Dataset (DVC-tracked; not in Git)
├── models/                # model.pkl output (gitignored; created by train)
├── pipelines/
│   ├── ingest.py
│   ├── clean.py
│   ├── train.py           # Optional MLflow registration
│   └── predict.py
└── docker/
    ├── ingest/Dockerfile
    ├── clean/Dockerfile
    ├── train/Dockerfile          # Production train (MLflow)
    ├── train/Dockerfile_local    # Local train (main.py)
    └── serve/Dockerfile_local    # Local serve (mount models/)
```

## Setup

```bash
cd src
poetry install
```

AWS credentials must allow read access to the DVC remote (`s3://mlops-postgrade-datastore-dev/data` by default in `.dvc/config`).

```bash
poetry run dvc pull
mkdir -p models
```

## DVC workflow

DVC stores file content in S3 and keeps hashes in Git-tracked `.dvc` files.

### Initialize (already done in this repo)

```bash
dvc init --subdir
git add .dvc .dvcignore
```

### Remote (matches Terraform dev bucket)

```bash
# Example — actual URL is in .dvc/config
dvc remote add -d storage s3://mlops-postgrade-datastore-dev/data
```

### Track and share data

```bash
dvc add data/
git add data.dvc .gitignore
git commit -m "track dataset"
dvc push
```

Teammates: `git pull` then `poetry run dvc pull`.

### Update a dataset version

```bash
# edit files under data/
dvc add data/
git add data.dvc && git commit -m "dataset v2"
dvc push
```

## ML pipeline

Configuration (`config.yml`):

```yaml
data:
  train_path: data/train.csv
  test_path: data/test.csv

model:
  name: DecisionTreeClassifier
  params:
    criterion: entropy
    max_depth: null
  store_path: models/
```

Stages:

1. **Ingest** — load CSVs  
2. **Clean** — drop columns, impute, IQR outliers, premium parsing  
3. **Train** — `ColumnTransformer` + SMOTE + classifier; save `models/model.pkl`  
4. **Evaluate** — accuracy, ROC-AUC, classification report  

Run locally:

```bash
poetry run python main.py
```

Optional MLflow registration (training only):

```bash
export MLFLOW_TRACKING_URI=http://your-mlflow:5000
export MLFLOW_REGISTERED_MODEL_NAME=insurance-classifier
poetry run python main.py
```

## Model serving

| Mode | How the model is loaded |
|------|-------------------------|
| **Local / Compose** | `models/model.pkl` mounted into the container (`MLFLOW_*` unset) |
| **CI → ECS** | `model.pkl` baked into image via root `Dockerfile` after CI training step |
| **EKS + MLflow** | Set `MLFLOW_TRACKING_URI` (+ registry name/stage); see [k8s/README.md](../k8s/README.md) |

`model_loader.py` chooses MLflow when `MLFLOW_TRACKING_URI` or `MLFLOW_MODEL_URI` is set; otherwise `MODEL_PATH` (default `models/model.pkl`).

## Docker

### Image roles

| File | Use |
|------|-----|
| `Dockerfile` | **CI / ECS**: includes `app.py`, `models/`, exported `requirements.txt` |
| `docker/serve/Dockerfile_local` | **Local serve**: mount `models/` at runtime |
| `docker/train/Dockerfile_local` | **Local train**: runs `main.py` with mounted `data/`, `models/` |
| `docker-compose.yml` | Chains ingest → clean → train → serve |

### Local workflow (Docker Compose)

Recommended from `src/`:

```bash
mkdir -p models
poetry run dvc pull   # or: docker compose run --rm ingest  # if using compose-only data flow

docker compose build
docker compose run --rm train
docker compose up -d serve
```

### Local workflow (single images)

```bash
# Train
docker build -f docker/train/Dockerfile_local -t mlops-train-local .
docker run --rm \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/models:/app/models" \
  mlops-train-local

# Serve
docker build -f docker/serve/Dockerfile_local -t mlops-serve-local .
docker run -d --name mlops-serve -p 8080:80 \
  -v "$(pwd)/models:/app/models" \
  mlops-serve-local
```

## Testing

### 1. Lint (same as CI)

```bash
poetry run ruff check .
poetry run ruff format --check .
```

### 2. Pipeline + metrics

```bash
poetry run dvc pull
poetry run python main.py
```

Expect log lines for ingest/clean/train/evaluate and a printed classification report.

### 3. API smoke tests

With the server on port **8080** (Compose or `docker run` above):

```bash
# Health
curl -s http://127.0.0.1:8080/ | jq .

# Prediction
curl -s -X POST "http://127.0.0.1:8080/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "Gender": "Male",
    "Age": 49,
    "HasDrivingLicense": 1,
    "RegionID": 28,
    "Switch": 0,
    "PastAccident": "1-2 Year",
    "AnnualPremium": 1885.05
  }' | jq .
```

Interactive docs: http://127.0.0.1:8080/docs

### 4. Verify response shape

- `GET /` → `{"health_check":"OK"}`
- `POST /predict` → `{"predicted_class": <0|1>}`

### 5. CI parity

The **Application Build & Release** workflow runs: lint → `dvc pull` → `main.py` → `docker build -t app:ci .` using the root `Dockerfile`. Reproduce failures locally with the same commands from `src/`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `FileNotFoundError` for `data/*.csv` | Run `poetry run dvc pull` (or obtain data from teammate’s `dvc push`) |
| `dvc: command not found` | Use `poetry run dvc …` |
| S3 access denied on `dvc pull` | Configure AWS CLI; confirm bucket in `.dvc/config` exists for your account |
| `ImportError: cannot import name '_DIR_MARK' from 'pathspec'` | Reinstall with Poetry (`pathspec < 1.0` is pinned for DVC 3.59) |
| `docker build` fails: `models/` not found | Run `poetry run python main.py` first, or use `Dockerfile_local` with a volume mount |
| `/predict` 500 or crash on startup | Ensure `models/model.pkl` exists and is mounted (local) or copied (root `Dockerfile`) |
| Wrong predictions after retrain | Restart serve container so it reloads `model.pkl` |
| MLflow model not found in prod | Promote version to **Production**; set `MLFLOW_TRACKING_URI` and registry env vars |
| Compose `train` exits immediately | Check logs: `docker compose logs train`; ensure `data/` is populated |

## CI/CD (summary)

On merge to `main`, GitHub Actions (see [../README.md](../README.md)) retrains, builds `Dockerfile`, pushes to ECR, and redeploys ECS. You do not need to push images manually for dev unless debugging.

## Related docs

- [../README.md](../README.md) — Terraform, ECS, GitHub variables, infra troubleshooting  
- [../k8s/README.md](../k8s/README.md) — ECR push and EKS manifests for MLflow-based serving
