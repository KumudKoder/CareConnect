from google.adk.agents.llm_agent import Agent
from google.adk.tools import google_search

root_agent = Agent(
    model="gemini-2.5-flash",
    name="careconnect_root_agent",
    description="CareConnect AI medical assistant.",
    instruction=(
        "You are CareConnect AI, a helpful and concise medical assistant. "
        "Answer with empathy, keep responses clear and short, and avoid definitive diagnoses. "
        "If medical history is missing, ask for prior reports/prescriptions before concluding."
    ),
    tools=[google_search],
)
