# DVC overview

Short introduction to [DVC](https://dvc.org/) (Data Version Control) and how this project uses it. For day-to-day commands and troubleshooting, see [dvc-runbook.md](dvc-runbook.md).

---

## What is DVC?

DVC is a tool that versions **large files and datasets** alongside Git without storing the actual bytes in the repository. Git keeps small **pointer files** (`.dvc`) that record content hashes; a **remote** (here, S3) stores the real data. You get reproducible datasets: checking out a Git commit and running `dvc pull` restores the exact files that commit referenced.

In this repo, DVC tracks `src/data/` (`train.csv`, `test.csv`, etc.) while training code and CI read paths from `src/config.yml`.

---

## How it works

Three layers cooperate:

| Layer | Role |
|-------|------|
| **Git** | Source code, workflows, `.dvc` pointer files, `src/.dvc/config` |
| **DVC** | Hashes, local cache, sync with the remote (`dvc add`, `push`, `pull`, `fetch`) |
| **Remote (S3)** | Durable storage for dataset blobs |

Typical flow:

1. You change files under `src/data/`.
2. `dvc add data` recomputes hashes and updates `src/data.dvc`.
3. `dvc push` uploads new blobs to S3.
4. You commit `data.dvc` to Git (not the CSVs).
5. Anyone (or CI) on that commit runs `dvc pull` to download matching files from S3.

Git answers *which version* of the data you mean; the remote holds *the bytes*.

---

## Files you need

| File / directory | In Git? | Purpose |
|------------------|---------|---------|
| `src/.dvc/` | Yes (config); cache is local | DVC project root (`dvc init --subdir`) |
| `src/.dvc/config` | Yes | Default remote URL, `autostage`, etc. |
| `src/.dvcignore` | Yes | Patterns to exclude from DVC operations |
| `src/data.dvc` | Yes | Pointer: directory hash, size, file count for `data/` |
| `src/data/` | No (`.gitignore`) | Working copy of the dataset on disk |
| `src/.dvc/cache/` | No | Local content-addressed cache |

Minimum to collaborate: committed `data.dvc`, `.dvc/config`, and blobs on the remote after `dvc push`.

---

## How data is tracked

DVC tracks **content**, not filenames alone. When you run `dvc add data` on the `src/data/` directory:

- Each file is hashed (MD5 in this project).
- A directory manifest (`.dir` hash) summarizes the folder.
- `data.dvc` stores that manifest, e.g. `md5`, `size`, `nfiles`, and `path: data`.

Any change under `data/`—editing a CSV, adding a file, or bumping `VERSION`—changes the hash in `data.dvc`. Git history of `data.dvc` is therefore a **version line** for the dataset.

Raw files stay out of Git (`/data` in `src/.gitignore`). CI and developers use the pointer + remote:

- **Data Verification** (when `src/data.dvc` changes): checks pointer consistency and that S3 has the blobs.
- **Application CI**: `dvc pull` before training on every build.

---

## Remotes besides S3

This project uses **Amazon S3** (`s3://mlops-postgrade-datastore-dev/data` in `src/.dvc/config`). DVC supports many other remotes with the same push/pull model:

| Remote type | Example URL pattern | Notes |
|-------------|---------------------|--------|
| **Local** | `../dvc-storage` or absolute path | Simple sharing on a shared filesystem; no cloud |
| **Google Cloud Storage** | `gs://bucket/path` | `dvc remote add -d storage gs://...` |
| **Azure Blob** | `azure://container/path` | Requires Azure SDK / credentials |
| **SSH / SFTP** | `ssh://user@host/path` | Common for on-prem or lab servers |
| **HDFS** | `hdfs://namespace/path` | Hadoop clusters |
| **HTTP(S)** | Read-only in some setups | Less common for team read/write |

Configure with `dvc remote add` and set `core.remote` in `.dvc/config` (or use `-d` for default). Only the URL and credentials change; pointer files and `dvc add` / `push` / `pull` stay the same.

For environment-specific buckets (dev vs prd), see Terraform outputs and [dvc-and-docker.md](dvc-and-docker.md).

---

## Rollout: publishing a new dataset version

“Rollout” here means making a new dataset version available to the team and to CI/CD.

### 1. Prepare and publish (data owner)

```bash
cd src
# Edit files under data/
poetry run dvc add data
poetry run dvc status          # should be clean
poetry run dvc push            # required before CI can fetch new hashes
cd ..
git add src/data.dvc
git commit -m "Describe dataset change"
git push
```

Open a PR. If `src/data.dvc` changed, **Data Verification** runs and confirms S3 has the new content.

### 2. Merge and sync (everyone else)

```bash
git pull
cd src
poetry run dvc pull
```

Training and tests then use the same files as the merged pointer.

### 3. Application rollout (CI/CD)

Application rollout is separate from uploading blobs but **depends** on them being in S3:

- **Dev**: On push to `main`, `app-reusable.yml` runs `dvc pull` → trains → builds Docker → deploys to ECS.
- **Production**: Promote copies an existing image from dev ECR; it does not re-run `dvc pull` in prd, but the image was built from a commit whose `data.dvc` was already satisfiable in dev.

If you commit `data.dvc` without `dvc push`, rollout fails at verification or at `dvc pull` in Application CI.

### Rollout checklist

- [ ] Changes only under `src/data/`
- [ ] `dvc add` + clean `dvc status`
- [ ] `dvc push` before merge
- [ ] PR includes `src/data.dvc`, not `src/data/*.csv`
- [ ] Teammates run `dvc pull` after merge

---

## See also

- [dvc-flow.md](dvc-flow.md) — visual cheat sheet (Git, DVC, S3 layers)
- [dvc-runbook.md](dvc-runbook.md) — operational guide, CI checks, troubleshooting
- [dvc-and-docker.md](dvc-and-docker.md) — DVC with Docker and environments
- [src/README.md](../src/README.md) — local setup and training
- [DVC documentation](https://dvc.org/doc) — upstream reference
