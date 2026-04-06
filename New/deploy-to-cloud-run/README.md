# CareConnect (New Folder) — Fresh-Machine Deploy Guide

This README is the **single onboarding guide** for running the deployment from `New/deploy-to-cloud-run` on a new device.

It deploys:

1. `careconnect-main-backend` (FastAPI + ADK runner)
2. `careconnect-mcp-server` (MCP tool server)
3. `careconnect-adk-ui` (ADK web UI)

---

## 0) Quick start (if infra already exists)

If your GCP project, AlloyDB, VPC connector, and secrets are already ready:

1. Open PowerShell in this folder: `New/deploy-to-cloud-run`
2. Run:

```powershell
./deploy_new.ps1 `
  -ProjectId agent-490407 `
  -Region us-central1 `
  -AlloydbInstanceUri "projects/agent-490407/locations/us-central1/clusters/careconnect-cluster/instances/careconnect-primary" `
  -AlloydbDbName "careconnectdb" `
  -AlloydbDbUser "postgres" `
  -AlloydbDbPassword "<YOUR_DB_PASSWORD>"
```

---

## 1) Prerequisites on a new machine

Install and verify:

- Git
- Python 3.11+
- Google Cloud SDK (`gcloud`)

Then run:

```powershell
python --version
gcloud --version
gcloud auth login
gcloud auth application-default login
```

Install ADK CLI (required for `adk deploy` in `deploy_new.ps1`):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install google-adk
```

---

## 2) Configure project and APIs (one-time)

Replace values if needed:

```powershell
$PROJECT_ID = "agent-490407"
$REGION = "us-central1"

gcloud config set project $PROJECT_ID
gcloud services enable `
  run.googleapis.com `
  cloudbuild.googleapis.com `
  secretmanager.googleapis.com `
  artifactregistry.googleapis.com `
  aiplatform.googleapis.com `
  alloydb.googleapis.com `
  servicenetworking.googleapis.com `
  compute.googleapis.com `
  vpcaccess.googleapis.com
```

---

## 3) Required cloud resources (one-time)

You must have these resources before deployment:

- AlloyDB cluster + primary instance
- Database created (recommended: `careconnectdb`)
- Serverless VPC connector in `us-central1` (recommended name: `careconnect-vpc-connector`)
- Secret in Secret Manager for DB password (`ALLOYDB_DB_PASSWORD`)

For detailed setup steps, see:

- `notes/FROM_SCRATCH_SETUP.md`

---

## 4) Deploy all services

From this folder (`New/deploy-to-cloud-run`), run:

```powershell
./deploy_new.ps1 `
  -ProjectId agent-490407 `
  -Region us-central1 `
  -AlloydbInstanceUri "projects/agent-490407/locations/us-central1/clusters/careconnect-cluster/instances/careconnect-primary" `
  -AlloydbDbName "careconnectdb" `
  -AlloydbDbUser "postgres" `
  -AlloydbDbPassword "<YOUR_DB_PASSWORD>"
```

What this script deploys:

- `careconnect-main-backend` from `mcp-server/`
- `careconnect-mcp-server` from `mcp-tool-server/`
- `careconnect-adk-ui` from `myAgent/`

---

## 5) Post-deploy backend network + secret checks

After deployment, ensure backend service is configured with:

- VPC connector: `careconnect-vpc-connector`
- Egress: `private-ranges-only`
- Secret mapping (recommended): `ALLOYDB_DB_PASSWORD=ALLOYDB_DB_PASSWORD:latest`

> Note: `deploy_new.ps1` currently passes DB password via env var argument. For production, prefer secret mapping and avoid plaintext passwords in command history.

---

## 6) Verify deployment

```powershell
# Backend health
Invoke-RestMethod -Uri "https://careconnect-main-backend-1023139347696.us-central1.run.app/health"

# UI availability
Invoke-WebRequest -Uri "https://careconnect-adk-ui-1023139347696.us-central1.run.app/dev-ui/" -UseBasicParsing | Select-Object -ExpandProperty StatusCode

# MCP endpoint reachability
Invoke-WebRequest -Uri "https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp" -UseBasicParsing | Select-Object -ExpandProperty StatusCode
```

Expected:

- Backend returns JSON with `status: ok`
- UI returns HTTP `200`
- MCP endpoint responds (status may vary by method, but service should be reachable)

---

## 7) Local `.env` notes

Use `.env` only for local convenience. Keep real secrets out of git.

Recommended values:

- `GOOGLE_CLOUD_PROJECT=agent-490407`
- `GOOGLE_CLOUD_LOCATION=us-central1`
- `GOOGLE_GENAI_USE_VERTEXAI=true`
- `ALLOYDB_INSTANCE_URI=projects/agent-490407/locations/us-central1/clusters/careconnect-cluster/instances/careconnect-primary`
- `ALLOYDB_DB_NAME=careconnectdb`
- `ALLOYDB_DB_USER=postgres`
- `ALLOYDB_ENABLE_IAM_AUTH=false`

---

## 8) Common issues and quick fixes

1. **`gcloud` not recognized**
   - Restart terminal after Cloud SDK install or add Cloud SDK to `PATH`.

2. **Backend root URL shows `Not Found`**
   - Use `/health` instead of `/`.

3. **DB write flows not persisting**
   - Confirm workflow type is `new_prescription` (not only read-only flows).

4. **AlloyDB connection errors from Cloud Run**
   - Verify VPC connector attachment and private egress.

5. **Secret-related runtime error**
   - Ensure runtime service account has `roles/secretmanager.secretAccessor`.

---

## 9) Team onboarding checklist

For teammate handover, share:

1. This README
2. `notes/FROM_SCRATCH_SETUP.md`
3. Required IAM roles and project access
4. Current service URLs

Additional references:

- `notes/TEAM_ONBOARDING.md`
- `notes/SECURITY_GITHUB_CHECKLIST.md`
- `notes/DEPLOY_STATUS_2026-04-06.md`
