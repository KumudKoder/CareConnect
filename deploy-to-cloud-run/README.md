# CareConnect Deployment Runbook

This README documents **only the current working CareConnect setup** and gives you the exact commands you can run from:

- **Local Windows PowerShell**
- **Google Cloud Shell / Google Cloud Console terminal**

It also lists the **required APIs, IAM access, runtime access, and direct console links**.

---

## Current live services

### 1. MCP server

- Service: `careconnect-mcp-server`
- Base URL: `https://careconnect-mcp-server-1023139347696.us-central1.run.app`
- MCP endpoint: `https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp`
- Source: `mcp-server/server.py`
- Deploy method: Docker image via Cloud Build + Cloud Run

Current MCP tools:

- `analyze_prescription`
- `summarize_medical_report`
- `check_medicine_interactions`
- `set_medicine_reminder`

### 2. ADK Web UI

- Service: `careconnect-adk-ui`
- URL: `https://careconnect-adk-ui-1023139347696.us-central1.run.app`
- Source: `myAgent/agent.py`
- Deploy method: `adk deploy cloud_run --with_ui`

Current behavior:

- uses `LlmAgent`
- connects to MCP using `MCPToolset`
- reads `MCP_SERVER_URL`
- reads `GOOGLE_API_KEY` from Secret Manager

### 3. A2A service

- Service: `careconnect-a2a`
- URL: `https://careconnect-a2a-1023139347696.us-central1.run.app`
- Agent card: `https://careconnect-a2a-1023139347696.us-central1.run.app/.well-known/agent.json`
- Agent source: `myAgent/agent.py`
- A2A wrapper: `myAgent/a2a_main.py`
- Deploy method: Docker image via Cloud Build + Cloud Run

Current behavior:

- exposes the same ADK agent over A2A
- connects to the same MCP server

---

## Current repository layout

- `mcp-server/`
  - `server.py`
  - `Dockerfile`
  - `.gcloudignore`

- `myAgent/`
  - `agent.py`
  - `a2a_main.py`
  - `__init__.py`
  - `Dockerfile`
  - `.gcloudignore`

- `.env`
  - local placeholder values for local runs

- deployment automation
  - `deploy_all.ps1`
  - `deploy_all.sh`

---

## Automated cloud deployment evidence

If you need to show proof that deployment is automated with scripts / deployment code, use these files and sections:

- `deploy-to-cloud-run/deploy_all.ps1` → one-command PowerShell deployment for Windows
- `deploy-to-cloud-run/deploy_all.sh` → one-command Bash deployment for Cloud Shell / Linux
- `deploy-to-cloud-run/mcp-server/Dockerfile` → codified MCP container build
- `deploy-to-cloud-run/myAgent/Dockerfile` → codified agent / A2A container build

These automation files do the following:

1. enable required Google Cloud APIs
2. create/update Secret Manager values
3. grant runtime secret access
4. build container images with Cloud Build
5. deploy MCP to Cloud Run
6. deploy ADK UI to Cloud Run
7. deploy A2A to Cloud Run
8. attach secrets and environment variables automatically

For submission answers, the strongest file link is:

- `deploy-to-cloud-run/deploy_all.ps1`

or, if Bash / Cloud Shell is preferred:

- `deploy-to-cloud-run/deploy_all.sh`

---

## Current architecture

### MCP server responsibilities

The MCP server is the **tool layer**.

It is responsible for:

- prescription analysis support
- medical report summarization support
- medicine caution checks
- reminder preparation

### ADK agent responsibilities

The ADK agent is the **reasoning and orchestration layer**.

It is responsible for:

- talking to the user
- choosing when to call MCP tools
- combining tool output into user-facing responses

### A2A responsibilities

The A2A service exposes the same agent to other systems using the A2A protocol.

---

## Project values used now

- Project ID: `agent-490407`
- Region: `us-central1`
- Runtime service account: `1023139347696-compute@developer.gserviceaccount.com`
- Secret name: `GOOGLE_API_KEY`
- MCP URL: `https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp`
- ADK UI URL: `https://careconnect-adk-ui-1023139347696.us-central1.run.app`
- A2A URL: `https://careconnect-a2a-1023139347696.us-central1.run.app`

Runtime environment values:

- `GOOGLE_API_KEY`
- `GOOGLE_GENAI_USE_VERTEXAI=false`
- `MCP_SERVER_URL=https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp`
- `GOOGLE_CLOUD_PROJECT=agent-490407`
- `GOOGLE_CLOUD_LOCATION=us-central1`

---

## Required access

### Access needed for the person running deploy commands

The user or admin account running these commands should have these practical roles on project `agent-490407`:

- `roles/run.admin`
- `roles/cloudbuild.builds.editor`
- `roles/iam.serviceAccountUser`
- `roles/secretmanager.admin`
- `roles/serviceusage.serviceUsageAdmin`

Notes:

- `roles/run.admin` is needed to create and update Cloud Run services.
- `roles/cloudbuild.builds.editor` is needed to submit builds.
- `roles/iam.serviceAccountUser` is needed when deploying services that run as the runtime service account.
- `roles/secretmanager.admin` is the simplest role for creating the secret and adding new secret versions.
- `roles/serviceusage.serviceUsageAdmin` is needed if you want to enable APIs yourself.

If your organization uses stricter IAM, an admin may also need to grant additional permissions for the Cloud Build staging bucket or Artifact Registry access.

### Access needed for the runtime service account

The Cloud Run runtime service account must have:

- `roles/secretmanager.secretAccessor`

This is required so the ADK UI service and A2A service can read `GOOGLE_API_KEY` from Secret Manager at runtime.

### Access needed for Cloud Build

Cloud Build usually works with the default project configuration once APIs are enabled.

If builds fail due to organization restrictions, check:

- Cloud Build service account permissions
- Artifact Registry / Container Registry access
- project storage bucket access for build source upload

---

## APIs that must be enabled

Enable these APIs in project `agent-490407`:

- `run.googleapis.com`
- `cloudbuild.googleapis.com`
- `secretmanager.googleapis.com`
- `artifactregistry.googleapis.com`

Recommended additional API for general project management and IAM workflows:

- `iam.googleapis.com`

---

## Direct console links

### Google Cloud Console links

- Project dashboard: `https://console.cloud.google.com/home/dashboard?project=agent-490407`
- Cloud Run services: `https://console.cloud.google.com/run?project=agent-490407`
- Cloud Build history: `https://console.cloud.google.com/cloud-build/builds?project=agent-490407`
- Secret Manager: `https://console.cloud.google.com/security/secret-manager?project=agent-490407`
- IAM page: `https://console.cloud.google.com/iam-admin/iam?project=agent-490407`
- Service Accounts: `https://console.cloud.google.com/iam-admin/serviceaccounts?project=agent-490407`
- APIs library: `https://console.cloud.google.com/apis/library?project=agent-490407`
- Enabled APIs: `https://console.cloud.google.com/apis/dashboard?project=agent-490407`
- Logs Explorer: `https://console.cloud.google.com/logs/query?project=agent-490407`

### Current app links

- MCP endpoint: `https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp`
- ADK UI: `https://careconnect-adk-ui-1023139347696.us-central1.run.app`
- A2A service: `https://careconnect-a2a-1023139347696.us-central1.run.app`
- A2A agent card: `https://careconnect-a2a-1023139347696.us-central1.run.app/.well-known/agent.json`

---

## Local Windows PowerShell commands

Use this section when you are running commands from your own Windows machine.

### Local prerequisites

Make sure these are installed locally:

- Python 3.11+
- Google Cloud SDK (`gcloud`)
- an authenticated Google account with the required IAM access

Optional but recommended:

- a local virtual environment `.venv` for the ADK CLI flow

### 1. Set variables

```powershell
$GCLOUD = 'C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'
$PROJECT_ID = 'agent-490407'
$REGION = 'us-central1'
$RUNTIME_SA = '1023139347696-compute@developer.gserviceaccount.com'
$MCP_SERVICE = 'careconnect-mcp-server'
$UI_SERVICE = 'careconnect-adk-ui'
$A2A_SERVICE = 'careconnect-a2a'
$MCP_URL = 'https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp'
```

### 2. Authenticate and select project

```powershell
& $GCLOUD auth login
& $GCLOUD config set project $PROJECT_ID
& $GCLOUD auth list
& $GCLOUD config list
```

### 3. Enable required APIs

```powershell
& $GCLOUD services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com iam.googleapis.com --project=$PROJECT_ID
```

### 4. Create or update the API key secret

Create secret once:

```powershell
& $GCLOUD secrets create GOOGLE_API_KEY --project=$PROJECT_ID --replication-policy=automatic
```

Add a secret version:

```powershell
$tmp = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp -Value 'YOUR_GOOGLE_API_KEY' -NoNewline
& $GCLOUD secrets versions add GOOGLE_API_KEY --project=$PROJECT_ID --data-file=$tmp
Remove-Item $tmp
```

### 5. Grant runtime secret access

```powershell
& $GCLOUD projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$RUNTIME_SA" --role="roles/secretmanager.secretAccessor"
```

### 6. Deploy MCP server

Run from `deploy-to-cloud-run/mcp-server`:

```powershell
Set-Location 'c:\Users\Kumud\Downloads\careconnect\Agent\deploy-to-cloud-run\mcp-server'

& $GCLOUD builds submit --tag gcr.io/$PROJECT_ID/careconnect-mcp-server

& $GCLOUD run deploy $MCP_SERVICE --image gcr.io/$PROJECT_ID/careconnect-mcp-server --platform managed --region $REGION --allow-unauthenticated
```

### 7. Create local virtual environment for ADK CLI

Run from the repo root `Agent`:

```powershell
Set-Location 'c:\Users\Kumud\Downloads\careconnect\Agent'
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install google-adk
```

### 8. Deploy ADK UI

Run from `deploy-to-cloud-run`:

```powershell
Set-Location 'c:\Users\Kumud\Downloads\careconnect\Agent\deploy-to-cloud-run'
$env:Path = 'C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin;' + $env:Path

& 'c:/Users/Kumud/Downloads/careconnect/Agent/.venv/Scripts/adk.exe' deploy cloud_run --project=$PROJECT_ID --region=$REGION --service_name=$UI_SERVICE --app_name=CareConnectApp --with_ui .\myAgent
```

Attach env vars and secret after deploy:

```powershell
& $GCLOUD run services update $UI_SERVICE --project=$PROJECT_ID --region=$REGION --update-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest --update-env-vars GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$MCP_URL
```

### 9. Deploy A2A service

Run from `deploy-to-cloud-run/myAgent`:

```powershell
Set-Location 'c:\Users\Kumud\Downloads\careconnect\Agent\deploy-to-cloud-run\myAgent'

& $GCLOUD builds submit --tag gcr.io/$PROJECT_ID/careconnect-a2a

& $GCLOUD run deploy $A2A_SERVICE --image gcr.io/$PROJECT_ID/careconnect-a2a --platform managed --region $REGION --allow-unauthenticated --set-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest --set-env-vars GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$MCP_URL
```

### 10. Verify live services

```powershell
Invoke-WebRequest -Uri 'https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp' -Method Get -UseBasicParsing
Invoke-WebRequest -Uri 'https://careconnect-adk-ui-1023139347696.us-central1.run.app' -UseBasicParsing
Invoke-WebRequest -Uri 'https://careconnect-a2a-1023139347696.us-central1.run.app/.well-known/agent.json' -UseBasicParsing
```

Notes:

- `406` on `/mcp` is acceptable for a simple GET and confirms the endpoint exists.
- `200` on the UI URL confirms the UI is up.
- `200` on the agent card confirms the A2A service is up.

### 11. Useful local operations

Show Cloud Run services:

```powershell
& $GCLOUD run services list --project=$PROJECT_ID --region=$REGION
```

Describe one service:

```powershell
& $GCLOUD run services describe $UI_SERVICE --project=$PROJECT_ID --region=$REGION
```

Read recent ADK UI error logs:

```powershell
& $GCLOUD logging read "resource.type=cloud_run_revision AND resource.labels.service_name=careconnect-adk-ui AND severity>=ERROR" --project=$PROJECT_ID --limit=30 --format="value(timestamp,textPayload,jsonPayload.message)"
```

Read recent MCP logs:

```powershell
& $GCLOUD logging read "resource.type=cloud_run_revision AND resource.labels.service_name=careconnect-mcp-server" --project=$PROJECT_ID --limit=30 --format="value(timestamp,textPayload,jsonPayload.message)"
```

Read recent A2A logs:

```powershell
& $GCLOUD logging read "resource.type=cloud_run_revision AND resource.labels.service_name=careconnect-a2a" --project=$PROJECT_ID --limit=30 --format="value(timestamp,textPayload,jsonPayload.message)"
```

List secret versions:

```powershell
& $GCLOUD secrets versions list GOOGLE_API_KEY --project=$PROJECT_ID
```

Get the current service URLs:

```powershell
& $GCLOUD run services describe $MCP_SERVICE --project=$PROJECT_ID --region=$REGION --format="value(status.url)"
& $GCLOUD run services describe $UI_SERVICE --project=$PROJECT_ID --region=$REGION --format="value(status.url)"
& $GCLOUD run services describe $A2A_SERVICE --project=$PROJECT_ID --region=$REGION --format="value(status.url)"
```

---

## Google Cloud Shell / Google Cloud Console terminal commands

Use this section when you are running commands from **Cloud Shell** in the Google Cloud Console.

### Cloud Shell prerequisites

Make sure the source code is available inside Cloud Shell, for example under:

- `~/careconnect/Agent/deploy-to-cloud-run`

If needed, upload the repo or clone it into Cloud Shell first.

### 1. Set variables

```bash
export PROJECT_ID='agent-490407'
export REGION='us-central1'
export RUNTIME_SA='1023139347696-compute@developer.gserviceaccount.com'
export MCP_SERVICE='careconnect-mcp-server'
export UI_SERVICE='careconnect-adk-ui'
export A2A_SERVICE='careconnect-a2a'
export MCP_URL='https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp'

gcloud config set project "$PROJECT_ID"
```

### 2. Enable required APIs

```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  --project="$PROJECT_ID"
```

### 3. Create or update the API key secret

Create secret once:

```bash
gcloud secrets create GOOGLE_API_KEY \
  --project="$PROJECT_ID" \
  --replication-policy=automatic
```

Add a secret version:

```bash
printf 'YOUR_GOOGLE_API_KEY' > /tmp/google_api_key.txt
gcloud secrets versions add GOOGLE_API_KEY \
  --project="$PROJECT_ID" \
  --data-file=/tmp/google_api_key.txt
rm /tmp/google_api_key.txt
```

### 4. Grant runtime secret access

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$RUNTIME_SA" \
  --role="roles/secretmanager.secretAccessor"
```

### 5. Deploy MCP server

```bash
cd ~/careconnect/Agent/deploy-to-cloud-run/mcp-server

gcloud builds submit --tag "gcr.io/$PROJECT_ID/careconnect-mcp-server"

gcloud run deploy "$MCP_SERVICE" \
  --image "gcr.io/$PROJECT_ID/careconnect-mcp-server" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated
```

### 6. Create a virtual environment for ADK CLI

```bash
cd ~/careconnect/Agent
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install google-adk
```

### 7. Deploy ADK UI

```bash
cd ~/careconnect/Agent/deploy-to-cloud-run

./../.venv/bin/adk deploy cloud_run \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --service_name="$UI_SERVICE" \
  --app_name=CareConnectApp \
  --with_ui \
  ./myAgent
```

Attach env vars and secret after deploy:

```bash
gcloud run services update "$UI_SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --update-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest \
  --update-env-vars "GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$MCP_URL"
```

### 8. Deploy A2A service

```bash
cd ~/careconnect/Agent/deploy-to-cloud-run/myAgent

gcloud builds submit --tag "gcr.io/$PROJECT_ID/careconnect-a2a"

gcloud run deploy "$A2A_SERVICE" \
  --image "gcr.io/$PROJECT_ID/careconnect-a2a" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest \
  --set-env-vars "GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$MCP_URL"
```

### 9. Verify live services

```bash
curl -i 'https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp'
curl -i 'https://careconnect-adk-ui-1023139347696.us-central1.run.app'
curl -i 'https://careconnect-a2a-1023139347696.us-central1.run.app/.well-known/agent.json'
```

### 10. Useful Cloud Shell operations

```bash
gcloud run services list --project="$PROJECT_ID" --region="$REGION"

gcloud run services describe "$UI_SERVICE" --project="$PROJECT_ID" --region="$REGION"

gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=careconnect-adk-ui AND severity>=ERROR' \
  --project="$PROJECT_ID" \
  --limit=30 \
  --format='value(timestamp,textPayload,jsonPayload.message)'

gcloud secrets versions list GOOGLE_API_KEY --project="$PROJECT_ID"
```

---

## What to run for the most common tasks

### First-time setup only

Run these once:

1. authenticate to Google Cloud
2. set the project
3. enable APIs
4. create `GOOGLE_API_KEY` secret
5. grant `roles/secretmanager.secretAccessor` to the runtime service account

### When you change `mcp-server/server.py`

Run only the MCP deploy commands.

### When you change `myAgent/agent.py` and want the ADK UI updated

Run the ADK UI deploy command, then the Cloud Run service update command for env vars and secrets.

### When you change A2A wrapper or A2A Docker image behavior

Run the A2A deploy commands.

### When you only want to check status

Run the verification or log commands.

---

## Current notes

- `.venv` is recommended for the ADK CLI flow.
- `.venv` is not required for Docker-based Cloud Build deployments.
- `406` on `/mcp` is acceptable for a simple GET check and confirms the MCP endpoint exists.
- If the ADK UI looks stale after redeploy, open a fresh session or use an incognito window.
- `myAgent/agent.py` should define `root_agent` only.
- `myAgent/a2a_main.py` should wrap `root_agent` into `a2a_app` for the A2A container.

---

## Current reference links

- Google ADK codelab inspiration: `https://codelabs.developers.google.com/codelabs/currency-agent#0`
- Google ADK sample inspiration: `https://github.com/google/adk-samples/tree/main/python%2Fagents%2Fcurrency-agent`
