param(
    [string]$ProjectId = 'agent-490407',
    [string]$Region = 'us-central1',
    [string]$RuntimeServiceAccount = '1023139347696-compute@developer.gserviceaccount.com',
    [string]$McpService = 'careconnect-mcp-server',
    [string]$UiService = 'careconnect-adk-ui',
    [string]$A2AService = 'careconnect-a2a',
    [string]$GoogleApiKey = '',
    [switch]$SkipSecretUpdate,
    [switch]$SkipApiEnable
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$gcloud = 'gcloud'
$mcpImage = "gcr.io/$ProjectId/$McpService"
$a2aImage = "gcr.io/$ProjectId/$A2AService"
$mcpUrl = "https://$McpService-1023139347696.$Region.run.app/mcp"
$adkExe = Join-Path $repoRoot '.venv\Scripts\adk.exe'

function Require-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $name"
    }
}

function Ensure-Secret {
    param([string]$SecretName)

    $exists = & $gcloud secrets describe $SecretName --project=$ProjectId 2>$null
    if (-not $?) {
        & $gcloud secrets create $SecretName --project=$ProjectId --replication-policy=automatic | Out-Host
    }
}

Require-Command $gcloud

if (-not (Test-Path $adkExe)) {
    throw "ADK CLI not found at $adkExe. Create repo-root .venv and install google-adk first."
}

& $gcloud config set project $ProjectId | Out-Host

if (-not $SkipApiEnable) {
    & $gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com iam.googleapis.com --project=$ProjectId | Out-Host
}

if (-not $SkipSecretUpdate) {
    if ([string]::IsNullOrWhiteSpace($GoogleApiKey)) {
        throw 'GoogleApiKey is required unless -SkipSecretUpdate is used.'
    }

    Ensure-Secret -SecretName 'GOOGLE_API_KEY'
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $GoogleApiKey -NoNewline
    & $gcloud secrets versions add GOOGLE_API_KEY --project=$ProjectId --data-file=$tmp | Out-Host
    Remove-Item $tmp -Force

    & $gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$RuntimeServiceAccount" --role='roles/secretmanager.secretAccessor' | Out-Host
}

Push-Location (Join-Path $scriptRoot 'mcp-server')
& $gcloud builds submit --tag $mcpImage | Out-Host
& $gcloud run deploy $McpService --image $mcpImage --platform managed --region $Region --allow-unauthenticated | Out-Host
Pop-Location

Push-Location $scriptRoot
& $adkExe deploy cloud_run --project=$ProjectId --region=$Region --service_name=$UiService --app_name=CareConnectApp --with_ui .\myAgent | Out-Host
& $gcloud run services update $UiService --project=$ProjectId --region=$Region --update-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest --update-env-vars "GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$mcpUrl" | Out-Host
Pop-Location

Push-Location (Join-Path $scriptRoot 'myAgent')
& $gcloud builds submit --tag $a2aImage | Out-Host
& $gcloud run deploy $A2AService --image $a2aImage --platform managed --region $Region --allow-unauthenticated --set-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest --set-env-vars "GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$mcpUrl" | Out-Host
Pop-Location

Write-Host ''
Write-Host 'Deployment completed.' -ForegroundColor Green
Write-Host "MCP: https://$McpService-1023139347696.$Region.run.app/mcp"
Write-Host "ADK UI: https://$UiService-1023139347696.$Region.run.app"
Write-Host "A2A: https://$A2AService-1023139347696.$Region.run.app/.well-known/agent.json"
