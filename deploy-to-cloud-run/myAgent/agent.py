import os

from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.adk.tools.mcp_tool import MCPToolset, StreamableHTTPConnectionParams

load_dotenv()

MCP_FALLBACK_URL = "https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp"
MCP_SERVER_URL = os.getenv("MCP_SERVER_URL", MCP_FALLBACK_URL)

SYSTEM_INSTRUCTION = (
    "You are CareConnect AI, a helpful and concise medical assistant. "
    "Use CareConnect MCP tools when needed to analyze prescriptions, summarize reports, check medicine cautions, and prepare reminders. "
    "Do not provide definitive diagnoses. Encourage clinician confirmation for any treatment decision."
)

root_agent = LlmAgent(
    model="gemini-2.5-flash",
    name="careconnect_agent",
    description="A CareConnect medical support agent using MCP tools.",
    instruction=SYSTEM_INSTRUCTION,
    tools=[
        MCPToolset(
            connection_params=StreamableHTTPConnectionParams(
                url=MCP_SERVER_URL
            )
        )
    ],
)
