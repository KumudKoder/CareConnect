#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-agent-490407}"
REGION="${REGION:-us-central1}"
RUNTIME_SA="${RUNTIME_SA:-1023139347696-compute@developer.gserviceaccount.com}"
MCP_SERVICE="${MCP_SERVICE:-careconnect-mcp-server}"
UI_SERVICE="${UI_SERVICE:-careconnect-adk-ui}"
A2A_SERVICE="${A2A_SERVICE:-careconnect-a2a}"
GOOGLE_API_KEY_VALUE="${GOOGLE_API_KEY_VALUE:-}"
SKIP_SECRET_UPDATE="${SKIP_SECRET_UPDATE:-false}"
SKIP_API_ENABLE="${SKIP_API_ENABLE:-false}"

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_ROOT/.." && pwd)"
MCP_IMAGE="gcr.io/$PROJECT_ID/$MCP_SERVICE"
A2A_IMAGE="gcr.io/$PROJECT_ID/$A2A_SERVICE"
MCP_URL="https://$MCP_SERVICE-1023139347696.$REGION.run.app/mcp"
ADK_BIN="$REPO_ROOT/.venv/bin/adk"

command -v gcloud >/dev/null 2>&1 || { echo 'gcloud is required'; exit 1; }
[[ -x "$ADK_BIN" ]] || { echo "ADK CLI not found at $ADK_BIN"; exit 1; }

gcloud config set project "$PROJECT_ID"

if [[ "$SKIP_API_ENABLE" != "true" ]]; then
  gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com \
    --project="$PROJECT_ID"
fi

if [[ "$SKIP_SECRET_UPDATE" != "true" ]]; then
  [[ -n "$GOOGLE_API_KEY_VALUE" ]] || { echo 'Set GOOGLE_API_KEY_VALUE or use SKIP_SECRET_UPDATE=true'; exit 1; }

  if ! gcloud secrets describe GOOGLE_API_KEY --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud secrets create GOOGLE_API_KEY --project="$PROJECT_ID" --replication-policy=automatic
  fi

  tmpfile="$(mktemp)"
  printf '%s' "$GOOGLE_API_KEY_VALUE" > "$tmpfile"
  gcloud secrets versions add GOOGLE_API_KEY --project="$PROJECT_ID" --data-file="$tmpfile"
  rm -f "$tmpfile"

  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$RUNTIME_SA" \
    --role="roles/secretmanager.secretAccessor"
fi

pushd "$SCRIPT_ROOT/mcp-server" >/dev/null
gcloud builds submit --tag "$MCP_IMAGE"
gcloud run deploy "$MCP_SERVICE" \
  --image "$MCP_IMAGE" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated
popd >/dev/null

pushd "$SCRIPT_ROOT" >/dev/null
"$ADK_BIN" deploy cloud_run \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --service_name="$UI_SERVICE" \
  --app_name=CareConnectApp \
  --with_ui \
  ./myAgent

gcloud run services update "$UI_SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --update-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest \
  --update-env-vars "GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$MCP_URL"
popd >/dev/null

pushd "$SCRIPT_ROOT/myAgent" >/dev/null
gcloud builds submit --tag "$A2A_IMAGE"
gcloud run deploy "$A2A_SERVICE" \
  --image "$A2A_IMAGE" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-secrets GOOGLE_API_KEY=GOOGLE_API_KEY:latest \
  --set-env-vars "GOOGLE_GENAI_USE_VERTEXAI=false,MCP_SERVER_URL=$MCP_URL"
popd >/dev/null

echo "Deployment completed"
echo "MCP: https://$MCP_SERVICE-1023139347696.$REGION.run.app/mcp"
echo "ADK UI: https://$UI_SERVICE-1023139347696.$REGION.run.app"
echo "A2A: https://$A2A_SERVICE-1023139347696.$REGION.run.app/.well-known/agent.json"
