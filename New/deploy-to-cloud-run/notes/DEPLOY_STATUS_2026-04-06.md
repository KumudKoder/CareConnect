# CareConnect Deployment Status (2026-04-06)

## Project

- Project ID: `agent-490407`
- Region: `us-central1`

## Deployed Cloud Run services

- `careconnect-main-backend`
  - URL: `https://careconnect-main-backend-1023139347696.us-central1.run.app`
  - Status: ✅ deployed
- `careconnect-mcp-server`
  - URL: `https://careconnect-mcp-server-1023139347696.us-central1.run.app`
  - Status: ✅ deployed
- `careconnect-adk-ui`
  - URL: `https://careconnect-adk-ui-1023139347696.us-central1.run.app/dev-ui/`
  - Status: ✅ deployed

## Runtime verification done

- `GET /health` on `careconnect-main-backend` returned:
  - `{ "status": "ok", "agent": "careconnect_orchestrator" }`
- `POST /notes/summarize` generated model response successfully.
- MCP server `/mcp` responded with HTTP `406` for invalid probe body (expected for malformed MCP request), indicating service is reachable.

## Fixes applied during deployment

- `deploy_new.ps1`
  - Added ADK CLI auto-detection when `adk` is not on PATH.
  - Added non-interactive Cloud Run auth flag pass-through for ADK deploy.
- `mcp-server/main.py`
  - Fixed startup crash caused by `Path(...).parents[3]` index error in container.
  - Updated app startup to bind to Cloud Run `PORT` environment variable.

## Pending for full AlloyDB-backed flow

- No AlloyDB cluster/instance currently exists in project (`gcloud alloydb clusters list --region us-central1` returned zero items).
- Current backend is deployed with placeholder AlloyDB values.
- To complete ADK → MCP → AlloyDB end-to-end persistence, provision AlloyDB cluster + instance and redeploy `careconnect-main-backend` with real values:
  - `ALLOYDB_INSTANCE_URI`
  - `ALLOYDB_DB_NAME`
  - `ALLOYDB_DB_USER`
  - `ALLOYDB_DB_PASSWORD` (or IAM auth)

## Local env convenience

- Root `.env` created at: `c:\Users\Kumud\Downloads\careconnect\New\.env`
- Contains placeholders for Google Cloud + AlloyDB variables.
