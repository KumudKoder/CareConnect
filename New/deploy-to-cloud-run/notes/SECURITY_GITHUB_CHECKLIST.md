# Security Checklist for GitHub Deployment (CareConnect)

Use this checklist before pushing this repository to GitHub.

---

## 1) Never commit secrets

- Keep real values only in local `.env` (ignored) and Google Secret Manager.
- Do not commit service-account JSON keys.
- Do not commit DB passwords, API keys, or private keys.

This repo now includes root `.gitignore` rules for:

- `.env` and nested env files
- `*key*.json` / service-account credential patterns
- `deploy-to-cloud-run/irrelevant-files/samples-and-secrets/`

---

## 2) Use Secret Manager for runtime secrets

`deploy_new.ps1` now deploys backend with:

- normal non-secret env vars via `--set-env-vars`
- DB password via `--set-secrets`:
  - `ALLOYDB_DB_PASSWORD=ALLOYDB_DB_PASSWORD:latest`

Required secret:

- Name: `ALLOYDB_DB_PASSWORD`

---

## 3) If a key was ever exposed, rotate immediately

If a service-account key was present in this workspace at any time:

1. Go to IAM & Admin → Service Accounts
2. Open affected service account
3. Delete old exposed key(s)
4. Create new key only if absolutely required
5. Prefer Workload Identity / ADC over long-lived JSON keys

---

## 4) Keep app running safely

Cloud Run runtime should include:

- `ALLOYDB_INSTANCE_URI`
- `ALLOYDB_DB_NAME`
- `ALLOYDB_DB_USER`
- `ALLOYDB_ENABLE_IAM_AUTH`
- secret mapping for `ALLOYDB_DB_PASSWORD`
- VPC connector + private egress for AlloyDB private IP connectivity

---

## 5) Pre-push quick check

Before `git push`:

1. Run a search for common secret markers (`private_key`, `BEGIN PRIVATE KEY`, `API_KEY`, `PASSWORD`).
2. Ensure `.env` is not staged.
3. Ensure no `*.json` credential file is staged.
4. Ensure app still healthy at `/health`.

---

## 6) Recommended production hardening

- Set `SKIP_TOKEN_VERIFY=false`
- Restrict Cloud Run ingress/IAM as needed
- Rotate secrets periodically
- Enable audit logging alerts for secret access and IAM changes
