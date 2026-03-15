import os
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from google.adk.agents import Agent
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.adk.agents.run_config import RunConfig, StreamingMode
from google.genai import types

# 1. APPLICATION INITIALIZATION (PHASE 1)
app = FastAPI()

from google.adk.tools import google_search

# Configure your CareConnect Agent (The "Brain")
agent = Agent(
    name="careconnect_agent",
    model="gemini-2.0-flash-exp",
    instruction=(
        "You are Gemini CareConnect, a medical assistant present during doctor-patient visits. "
        "Listen to the conversation. If a doctor prescribes something that conflicts with the "
        "patient's historical health data (e.g., allergies or dosage), interrupt politely to alert them. "
        "Summarize the visit at the end."
    ),
    tools=[google_search] # Optional: Add tools for medical grounding
)

# Use InMemory for hackathon dev; switch to VertexAiSessionService for production persistence
session_service = InMemorySessionService() 
runner = Runner(app_name="careconnect", agent=agent, session_service=session_service)

# 2. WEBSOCKET ENDPOINT & SESSION INITIALIZATION (PHASE 2)
@app.websocket("/ws/{user_id}/{session_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str, session_id: str):
    await websocket.accept()
    
    # Initialize session and streaming config
    session = await session_service.get_or_create_session("careconnect", user_id, session_id)
    
    # Bidi-streaming config: Capture 16kHz mono PCM audio
    run_config = RunConfig(
        streaming_mode=StreamingMode.BIDI,
        response_modalities=["AUDIO"],
        input_audio_transcription=types.AudioTranscriptionConfig(),
        output_audio_transcription=types.AudioTranscriptionConfig(),
    )
    
    # Create the LiveRequestQueue to buffer incoming 200ms audio chunks
    live_request_queue = runner.create_live_request_queue()

    # 3. BIDI-STREAMING (PHASE 3)
    async def upstream():
        """Receives multimodal data from Flutter and forwards to Gemini."""
        try:
            while True:
                message = await websocket.receive_json()
                if message["type"] == "text":
                    live_request_queue.send_content(message["text"])
                elif message["type"] == "audio":
                    # message["data"] should be base64-encoded PCM 16kHz audio
                    live_request_queue.send_realtime(message["data"], mime_type="audio/pcm")
                elif message["type"] == "image":
                    # For prescription analysis (Action 2 for Kumud)
                    live_request_queue.send_realtime(message["data"], mime_type=message["mimeType"])
        except WebSocketDisconnect:
            live_request_queue.close()

    async def downstream():
        """Receives Events from Gemini and forwards them back to Flutter."""
        async for event in runner.run_live(user_id, session_id, live_request_queue, run_config):
            # Serialize ADK event to JSON and send to client
            await websocket.send_text(event.model_dump_json())

    # Run both tasks concurrently to allow for natural interruptions
    try:
        await asyncio.gather(upstream(), downstream())
    finally:
        # 4. TERMINATE SESSION (PHASE 4)
        live_request_queue.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))