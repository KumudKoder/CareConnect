# Team Onboarding Guide (CareConnect)

Use this guide when a new teammate needs to run the same setup safely.

---

## 1) Access required in Google Cloud

Project: `agent-490407`

Add teammate IAM with minimum practical roles:

- `roles/run.admin` (Cloud Run Admin)
- `roles/cloudbuild.builds.editor` (Cloud Build Editor)
- `roles/artifactregistry.writer` (Artifact Registry Writer)
- `roles/secretmanager.secretAccessor` (Secret Manager accessor)
- `roles/iam.serviceAccountUser` (Service Account User)
- `roles/logging.viewer` (Logs Viewer)
- `roles/viewer` (basic project visibility)

If they manage AlloyDB directly, add:

- `roles/alloydb.admin` (or `roles/alloydb.client` + needed read roles)

---

## 2) Tools they need locally

- Google Cloud SDK (`gcloud`)
- Python 3.11+
- Access to this GitHub repository

Then sign in:

- `gcloud auth login`
- `gcloud config set project agent-490407`

---

## 3) Clone repo and prepare local config

- Clone repository
- Use `deploy-to-cloud-run/.env.example` as template
- Create local `deploy-to-cloud-run/.env` (ignored by git)

Important:

- Never commit `.env`
- Never commit key JSON files
- Never put DB password directly in source-controlled files

---

## 4) Secrets and runtime expectations

Ensure secret exists in project:

- `ALLOYDB_DB_PASSWORD`

`deploy_new.ps1` is hardened to use Secret Manager mapping for DB password.

---

## 5) Deploy command

From `deploy-to-cloud-run/`:

- `./deploy_new.ps1 -ProjectId agent-490407 -Region us-central1`

This deploys:

1. `careconnect-main-backend`
2. `careconnect-mcp-server`
3. `careconnect-adk-ui`

---

## 6) Verify access and health

Check backend health:

- `GET https://careconnect-main-backend-1023139347696.us-central1.run.app/health`

Open UI:

- `https://careconnect-adk-ui-1023139347696.us-central1.run.app/dev-ui/`

Check recent backend errors:

- Cloud Run logs for `careconnect-main-backend`

---

## 7) Data flow expectation

- `new_prescription` workflow writes to AlloyDB (`health_records`, `reminders`)
- `check_schedule` / `review_history` are read workflows

If tables appear empty, run a real `new_prescription` request first.

---

## 8) Security policy for teammates

Before first push:

1. Review `notes/SECURITY_GITHUB_CHECKLIST.md`
2. Confirm `.gitignore` is active
3. Confirm no secrets are staged
4. Rotate/revoke any previously exposed key material

---

## 9) Quick links

- Main setup: `notes/FROM_SCRATCH_SETUP.md`
- Security checklist: `notes/SECURITY_GITHUB_CHECKLIST.md`
- Deployment status snapshot: `notes/DEPLOY_STATUS_2026-04-06.md`
