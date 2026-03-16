# CareConnect MCP-style server deployment (using your `main.py`)

This follows the same Cloud Run pattern from the course repo, but uses your existing `main.py`.

## Commands (course-style)

Build:

`gcloud builds submit --tag gcr.io/$(gcloud config get-value project)/careconnect-mcp-server`

Deploy:

`gcloud run deploy careconnect-mcp-server --image gcr.io/$(gcloud config get-value project)/careconnect-mcp-server --platform managed --allow-unauthenticated --set-env-vars GOOGLE_API_KEY=YOUR_KEY`
