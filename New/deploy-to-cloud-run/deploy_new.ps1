param(
    [string]$ProjectId = "<YOUR_PROJECT_ID>",
  [string]$Region = "<YOUR_REGION>",
  [string]$AlloydbInstanceUri = "projects/<YOUR_PROJECT_ID>/locations/<YOUR_REGION>/clusters/<YOUR_CLUSTER>/instances/<YOUR_INSTANCE>",
  [string]$AlloydbDbName = "<YOUR_DB_NAME>",
  [string]$AlloydbDbUser = "postgres",
  [string]$AlloydbDbPassword = "<YOUR_DB_PASSWORD>"
)

$ErrorActionPreference = "Stop"

Write-Host "Using Project: $ProjectId | Region: $Region" -ForegroundColor Cyan

gcloud config set project $ProjectId

gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com aiplatform.googleapis.com

# -------------------------
# 1) Deploy CareConnect Main Backend
# -------------------------
Set-Location "$PSScriptRoot\mcp-server"
gcloud builds submit --tag "gcr.io/$ProjectId/careconnect-main-backend"
gcloud run deploy careconnect-main-backend `
  --image "gcr.io/$ProjectId/careconnect-main-backend" `
  --platform managed `
  --region $Region `
  --allow-unauthenticated `
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$ProjectId,GOOGLE_CLOUD_LOCATION=$Region,GOOGLE_GENAI_USE_VERTEXAI=true,ALLOYDB_INSTANCE_URI=$AlloydbInstanceUri,ALLOYDB_DB_NAME=$AlloydbDbName,ALLOYDB_DB_USER=$AlloydbDbUser,ALLOYDB_DB_PASSWORD=$AlloydbDbPassword,ALLOYDB_ENABLE_IAM_AUTH=false,SKIP_TOKEN_VERIFY=true"

# -------------------------
# 2) Deploy MCP Tool Server (server.py)
# -------------------------
Set-Location "$PSScriptRoot\mcp-tool-server"
gcloud builds submit --tag "gcr.io/$ProjectId/careconnect-mcp-server"
gcloud run deploy careconnect-mcp-server `
  --image "gcr.io/$ProjectId/careconnect-mcp-server" `
  --platform managed `
  --region $Region `
  --allow-unauthenticated `
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$ProjectId,GOOGLE_CLOUD_LOCATION=$Region,GOOGLE_GENAI_USE_VERTEXAI=true"

# -------------------------
# 3) Deploy ADK Agent UI (myAgent)
# -------------------------
Set-Location $PSScriptRoot
adk deploy cloud_run `
  --project=$ProjectId `
  --region=$Region `
  --service_name=careconnect-adk-ui `
  --app_name=CareConnectApp `
  --with_ui `
  .\myAgent

Write-Host "Deployment completed from New/deploy-to-cloud-run." -ForegroundColor Green
