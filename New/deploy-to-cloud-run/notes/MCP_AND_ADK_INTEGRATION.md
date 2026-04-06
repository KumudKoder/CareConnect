# MCP and ADK Integration Guide

This guide explains how to connect the **MCP Tool Server** with the **ADK Web UI Agent** in CareConnect.

---

## Overview

CareConnect uses two complementary services:

1. **MCP Tool Server** (`mcp-tool-server`)
   - Exposes tools via FastMCP protocol (`/mcp` endpoint)
   - Tools: prescription analysis, medicine interaction checking, reminders, health records
   - URL: `https://<YOUR_MCP_DOMAIN>/mcp`

2. **ADK Web UI Agent** (`myAgent`)
   - Deployed via `adk deploy cloud_run --with_ui`
   - Currently uses basic tools (e.g., `google_search`)
   - Can be configured to call MCP tools

---

## Current Architecture

### Present state (standalone)

- ADK agent runs independently with built-in tool set
- MCP server runs independently with prescription/medicine tools
- **No direct connection yet**

### Target state (integrated)

- ADK agent calls MCP tools via HTTP
- User query → ADK LLM → MCP tool call → response → user

---

## How to Connect ADK to MCP

### Option A: Configure ADK agent to use MCP toolset

Update `myAgent/agent.py` to add MCP tool client:

```python
from google.adk.agents.llm_agent import Agent
from google.adk.tools import MCPToolset, StreamableHTTPConnectionParams

# MCP server endpoint
MCP_SERVER_URL = os.environ.get("MCP_SERVER_URL", "https://<YOUR_MCP_DOMAIN>/mcp")

root_agent = Agent(
    model="gemini-2.5-flash",
    name="careconnect_root_agent",
    description="CareConnect AI medical assistant.",
    instruction="...",
    tools=[
        MCPToolset(
            StreamableHTTPConnectionParams(
                url=MCP_SERVER_URL,
                timeout=30
            )
        )
    ],
)
```

Then redeploy:

```powershell
adk deploy cloud_run `
  --project=<YOUR_PROJECT_ID> `
  --region=<YOUR_REGION> `
  --service_name=careconnect-adk-ui `
  --with_ui `
  .\myAgent
```

### Option B: Call MCP from backend (current setup)

The `mcp-server/main.py` (main backend) can call tools and return results to ADK UI via WebSocket.

---

## Environment Setup

### For ADK to find MCP

Set this env var on the ADK Cloud Run service:

```powershell
gcloud run services update careconnect-adk-ui `
  --project=<YOUR_PROJECT_ID> `
  --region=<YOUR_REGION> `
  --update-env-vars "MCP_SERVER_URL=https://<YOUR_MCP_DOMAIN>/mcp"
```

Replace `<YOUR_MCP_DOMAIN>` with actual deployed MCP server domain:

- Example: `careconnect-mcp-server-1023139347696.us-central1.run.app`

---

## Testing the Integration

### 1) Verify MCP server is reachable

```powershell
$mcp_url = "https://<YOUR_MCP_DOMAIN>/mcp"
Invoke-WebRequest -Uri $mcp_url -UseBasicParsing -ErrorAction SilentlyContinue | Select-Object -ExpandProperty StatusCode
```

Expected: HTTP `406` or similar (MCP requires specific protocol handshake)

### 2) Open ADK UI and create a new chat session

- URL: `https://<YOUR_ADK_DOMAIN>/dev-ui/`
- Start a new conversation

### 3) Test MCP-backed query

Try a query like:

```
"Analyze this prescription image and check medicine interactions with my allergy: penicillin"
```

Expected:
- ADK agent → calls MCP tool → MCP analyzes prescription → response returned to user

---

## Troubleshooting

### "Tool not found" or timeout

**Check**:
- MCP server is deployed and running
- `MCP_SERVER_URL` env var is set correctly on ADK service
- Network/firewall allows ADK → MCP communication

**Fix**:

```powershell
# Verify MCP server logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=careconnect-mcp-server" `
  --project=<YOUR_PROJECT_ID> `
  --limit=20
```

### ADK doesn't recognize MCP tools

**Check**:
- `MCPToolset` is properly initialized in `agent.py`
- ADK SDK has been updated: `pip install --upgrade google-adk`

**Fix**:
- Redeploy ADK with updated code:

```powershell
adk deploy cloud_run .\myAgent --with_ui
```

### Network error between ADK and MCP

**Check**:
- Both services deployed in same region (recommended)
- Both allowing unauthenticated requests (or share auth setup)

---

## Architecture Diagram

```
User
  ↓
[ADK Web UI (careconnect-adk-ui)]
  ↓ (HTTP POST to /mcp)
[MCP Tool Server (careconnect-mcp-server)]
  ├─ analyze_prescription_image()
  ├─ check_medicine_interactions()
  ├─ set_medication_reminder()
  └─ get_patient_history()
  ↓
Vertex AI (for LLM inference)
  ↓
Response back to user
```

---

## Next Steps

1. **Update `myAgent/agent.py`** with MCPToolset config (Option A)
2. **Set `MCP_SERVER_URL`** env var on ADK Cloud Run service
3. **Redeploy ADK** with `adk deploy cloud_run`
4. **Test integration** using the verification steps above
5. **Monitor logs** in Cloud Logging for errors

For full backend integration (Option B, recommended for production):
- See `FROM_SCRATCH_SETUP.md` section 10 (workflow endpoints)
