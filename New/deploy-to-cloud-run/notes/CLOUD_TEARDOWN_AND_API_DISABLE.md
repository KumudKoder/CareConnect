# Cloud Teardown + API Disable Guide (Cloud Shell)

Use this guide to fully clean up CareConnect resources in GCP and reduce/stop billing.

> Project used in this workspace: `agent-490407`
> Region: `us-central1`

---

## 0) Safety first

Before deleting anything:

1. Confirm you do not need existing AlloyDB data.
2. If needed, take a backup/export first.
3. Make sure no other app in this project depends on the same services/APIs.

---

## 1) Cloud Shell commands: set project

Run in Cloud Shell:

```bash
gcloud config set project agent-490407
PROJECT_ID="agent-490407"
REGION="us-central1"
```

---

## 2) Delete Cloud Run services

```bash
gcloud run services delete careconnect-main-backend --region="$REGION" --quiet
gcloud run services delete careconnect-mcp-server --region="$REGION" --quiet
gcloud run services delete careconnect-adk-ui --region="$REGION" --quiet
```

Verify:

```bash
gcloud run services list --region="$REGION"
```

---

## 3) Delete AlloyDB resources

Delete instance first, then cluster:

```bash
gcloud alloydb instances delete careconnect-primary \
  --cluster=careconnect-cluster \
  --region="$REGION" \
  --quiet

gcloud alloydb clusters delete careconnect-cluster \
  --region="$REGION" \
  --quiet
```

Verify:

```bash
gcloud alloydb clusters list --region="$REGION"
```

---

## 4) Delete Serverless VPC connector

```bash
gcloud compute networks vpc-access connectors delete careconnect-vpc-connector \
  --region="$REGION" \
  --quiet
```

Verify:

```bash
gcloud compute networks vpc-access connectors list --region="$REGION"
```

---

## 5) Delete Secret Manager secret(s) (optional)

Only if no other app uses these:

```bash
gcloud secrets delete ALLOYDB_DB_PASSWORD --quiet
```

Verify:

```bash
gcloud secrets list
```

---

## 6) Delete container images (optional but recommended)

List images:

```bash
gcloud container images list --repository="gcr.io/$PROJECT_ID"
```

Delete CareConnect images:

```bash
gcloud container images delete "gcr.io/$PROJECT_ID/careconnect-main-backend" --force-delete-tags --quiet
gcloud container images delete "gcr.io/$PROJECT_ID/careconnect-mcp-server" --force-delete-tags --quiet
```

---

## 7) Disable APIs after resource cleanup

Disable only after deletion to avoid dependency errors.

```bash
gcloud services disable run.googleapis.com --force
gcloud services disable cloudbuild.googleapis.com --force
gcloud services disable artifactregistry.googleapis.com --force
gcloud services disable aiplatform.googleapis.com --force
gcloud services disable alloydb.googleapis.com --force
gcloud services disable vpcaccess.googleapis.com --force
gcloud services disable servicenetworking.googleapis.com --force
gcloud services disable secretmanager.googleapis.com --force
```

Optional (disable if unused by any other workload in this project):

```bash
gcloud services disable compute.googleapis.com --force
```

Verify enabled APIs:

```bash
gcloud services list --enabled
```

---

## 8) (Optional) Remove private service networking range/peering

Do this only if no other managed service uses it.

```bash
gcloud compute addresses delete google-managed-services-default --global --quiet
```

If needed, inspect peering first:

```bash
gcloud services vpc-peerings list --network=default
```

---

## 9) Revoke extra IAM access (recommended)

If you granted temporary access to users/service accounts, remove those IAM bindings when done.

---

## 10) Fastest full stop (nuclear option)

If this project is only for this app, delete the entire project:

```bash
gcloud projects delete agent-490407 --quiet
```

This removes all services/resources and stops billing when deletion completes.

---

## 11) What to disable vs keep (quick table)

- Disable now after cleanup:
  - `run.googleapis.com`
  - `cloudbuild.googleapis.com`
  - `artifactregistry.googleapis.com`
  - `aiplatform.googleapis.com`
  - `alloydb.googleapis.com`
  - `vpcaccess.googleapis.com`
  - `servicenetworking.googleapis.com`
  - `secretmanager.googleapis.com`

- Disable only if sure nothing else needs them:
  - `compute.googleapis.com`

---

## 12) Recovery note

To run the stack again later, re-enable APIs and redeploy using:

- `deploy-to-cloud-run/deploy_new.ps1`
- docs in `notes/FROM_SCRATCH_SETUP.md`
