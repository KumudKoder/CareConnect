import os

from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.adk.tools.mcp_tool import MCPToolset, StreamableHTTPConnectionParams

load_dotenv()

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
                url=os.getenv("MCP_SERVER_URL", "http://localhost:8080/mcp")
            )
        )
    ],
)
