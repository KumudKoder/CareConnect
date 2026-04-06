# CareConnect From-Scratch Setup Guide (GCP + AlloyDB + Cloud Run)

This guide helps anyone set up and run CareConnect from zero.

---

## 1) What this deploys

This repository deploys 3 services:

1. `careconnect-main-backend` (FastAPI + ADK runner + AlloyDB writes/reads)
2. `careconnect-mcp-server` (MCP tool service)
3. `careconnect-adk-ui` (ADK web UI)

---

## 2) Prerequisites

- Google Cloud project with billing enabled
- Project Owner or equivalent IAM permissions
- Installed locally:
  - Google Cloud SDK (`gcloud`)
  - Python 3.11+ (recommended 3.13 in this workspace)
- Logged in to gcloud:
  - `gcloud auth login`
- Set project:
  - `gcloud config set project agent-490407`

---

## 3) Enable required APIs

Enable these once:

- `run.googleapis.com`
- `cloudbuild.googleapis.com`
- `secretmanager.googleapis.com`
- `artifactregistry.googleapis.com`
- `aiplatform.googleapis.com`
- `alloydb.googleapis.com`
- `servicenetworking.googleapis.com`
- `compute.googleapis.com`
- `vpcaccess.googleapis.com`

---

## 4) Configure AlloyDB (cluster + instance)

### 4.1 Create private service access (VPC peering)

- Reserve range on default network (example name: `google-managed-services-default`)
- Connect Service Networking peering for `servicenetworking.googleapis.com`

### 4.2 Create AlloyDB resources

Suggested names:

- Cluster: `careconnect-cluster`
- Primary instance: `careconnect-primary`
- Region: `us-central1`
- Network: `default`

Create with postgres password (save it securely).

### 4.3 Create application database

In AlloyDB Studio (connect to `postgres` as user `postgres`):

```sql
CREATE DATABASE careconnectdb;
```

---

## 5) Secret Manager setup

Create/update secret:

- Secret name: `ALLOYDB_DB_PASSWORD`
- Value: your postgres password used for AlloyDB instance

Grant runtime service account access:

- Service account: `1023139347696-compute@developer.gserviceaccount.com`
- Role: `roles/secretmanager.secretAccessor`

---

## 6) Serverless VPC connector

Create connector in `us-central1` on default network:

- Name: `careconnect-vpc-connector`
- CIDR example: `10.8.1.0/28`

State must be `READY`.

---

## 7) Local env file

Use `deploy-to-cloud-run/.env` with values:

- `GOOGLE_CLOUD_PROJECT=agent-490407`
- `GOOGLE_CLOUD_LOCATION=us-central1`
- `GOOGLE_GENAI_USE_VERTEXAI=true`
- `SKIP_TOKEN_VERIFY=true` (local/testing only)
- `ALLOYDB_INSTANCE_URI=projects/agent-490407/locations/us-central1/clusters/careconnect-cluster/instances/careconnect-primary`
- `ALLOYDB_DB_NAME=careconnectdb` (or `postgres` during transition)
- `ALLOYDB_DB_USER=postgres`
- `ALLOYDB_ENABLE_IAM_AUTH=false`

> Do not store plain DB password in `.env` for production. Use Secret Manager.

---

## 8) Deploy services

From `deploy-to-cloud-run/`, run the deployment script:

- `./deploy_new.ps1 -ProjectId agent-490407 -Region us-central1`

This deploys all 3 services.

After deploy, update backend Cloud Run service settings:

- Attach VPC connector: `careconnect-vpc-connector`
- Set egress: `private-ranges-only`
- Ensure env vars include AlloyDB values
- Map secret env var:
  - `ALLOYDB_DB_PASSWORD=ALLOYDB_DB_PASSWORD:latest`

---

## 9) Verify health

### Backend health

- `GET https://careconnect-main-backend-1023139347696.us-central1.run.app/health`

Expected:

- `status: ok`

### UI

- Open:
  - `https://careconnect-adk-ui-1023139347696.us-central1.run.app/dev-ui/`

### MCP endpoint

- Base:
  - `https://careconnect-mcp-server-1023139347696.us-central1.run.app`
- MCP path:
  - `/mcp`

---

## 10) Write real data from app side (no manual SQL)

Use backend workflow endpoint:

- `POST /workflow/run`

Payload for DB-write flow:

```json
{
  "user_id": "U123",
  "workflow_type": "new_prescription",
  "image_base64": "BASE64_IMAGE_STRING_HERE",
  "allergies": ["penicillin", "ibuprofen"]
}
```

This writes records/reminders into AlloyDB.

---

## 11) Verify data in AlloyDB Studio

Run:

```sql
SELECT COUNT(*) FROM health_records;
SELECT COUNT(*) FROM reminders;
SELECT * FROM health_records ORDER BY created_at DESC LIMIT 20;
SELECT * FROM reminders ORDER BY created_at DESC LIMIT 20;
```

If counts are zero, you likely called read-only workflows (`check_schedule` / `review_history`) instead of `new_prescription`.

---

## 12) Monitoring and troubleshooting

### Cloud Run

- Service: `careconnect-main-backend`
  - Revisions (traffic split)
  - Logs (errors)
  - Metrics (latency, 5xx)

### AlloyDB

- Cluster status and instance state must be `READY`
- Check active connections and CPU metrics

### Common issues

1. `database "careconnectdb" does not exist`
   - Create DB in AlloyDB Studio first.

2. Cloud Run cannot reach AlloyDB
   - Ensure VPC connector attached + private egress.

3. Secret type conflict (`ALLOYDB_DB_PASSWORD`)
   - Remove plain env var first, then add as secret env var.

---

## 13) Recommended final production posture

- Keep `SKIP_TOKEN_VERIFY=false`
- Use dedicated DB (`careconnectdb`)
- Restrict Cloud Run ingress/IAM as needed
- Rotate DB password secret periodically
- Add backup strategy for AlloyDB

---

## 14) Current project values (this workspace)

- Project: `agent-490407`
- Region: `us-central1`
- Cluster: `careconnect-cluster`
- Instance: `careconnect-primary`
- Backend service: `careconnect-main-backend`
- MCP service: `careconnect-mcp-server`
- UI service: `careconnect-adk-ui`
