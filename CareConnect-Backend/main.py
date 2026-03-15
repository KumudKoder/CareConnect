import os
import asyncio
import json
import base64
import logging
import warnings
from pathlib import Path

# Load .env FIRST so GOOGLE_API_KEY is available before any google.adk import
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / ".env")

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from google.adk.agents import Agent
from google.adk.agents.live_request_queue import LiveRequestQueue
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.adk.agents.run_config import RunConfig, StreamingMode
from google.genai import types
from google.adk.tools import google_search

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Suppress pydantic serialization warnings
warnings.filterwarnings("ignore", category=UserWarning, module="pydantic")

# ─────────────────────────────────────────────────────────────────────────────
# 1. APPLICATION & AGENT INITIALIZATION
# ─────────────────────────────────────────────────────────────────────────────

app = FastAPI()
APP_NAME = "careconnect"
WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
SKILLS_ROOT = WORKSPACE_ROOT / ".gemini" / "skills"


def _build_skill_prompt_bundle(skills_root: Path) -> str:
    """Load all skill SKILL.md files into one prompt bundle for runtime guidance."""
    if not skills_root.exists():
        logger.warning(f"Skills folder not found: {skills_root}")
        return ""

    skill_parts = []
    for skill_md in sorted(skills_root.glob("*/SKILL.md")):
        try:
            content = skill_md.read_text(encoding="utf-8").strip()
            if content:
                skill_parts.append(
                    f"\n\n### Skill Source: {skill_md.parent.name}/SKILL.md\n{content}"
                )
        except Exception as exc:
            logger.warning(f"Could not read skill file {skill_md}: {exc}")

    if not skill_parts:
        logger.warning("No SKILL.md files were loaded from skills directory")
        return ""

    logger.info(f"Loaded {len(skill_parts)} skill definitions from {skills_root}")
    return "\n".join(skill_parts)


BASE_AGENT_INSTRUCTION = (
    "You are CareConnect AI, a helpful and concise AI medical assistant powered by Gemini. "
    "Talk directly to the user. Keep your answers brief, simple, empathetic, and easy to read. "
    "Do NOT output internal thoughts like 'Acknowledge and Await' or repeat yourself. "
    "Avoid complex formatting unless necessary. "
    "Always consider the user's prior history context when available (past medicines, prescriptions, tests, allergies, and chronic conditions). "
    "If past data is missing, explicitly ask the user to share previous prescriptions/reports or scan them before concluding. "
    "When comparing current vs past records, explicitly list matches, possible mismatches, and missing information. "
    "Never claim definitive diagnosis or accuse clinicians of error; instead flag possible issues that need clinician confirmation."
)

CAPABILITIES_RESPONSE_POLICY = (
    "If user asks 'what can you do' or 'how can you help me', respond that you can: "
    "(1) analyze past and current prescriptions/reports together, "
    "(2) flag possible medicine mismatches/interactions to discuss with doctor, "
    "(3) summarize reports in simple language, "
    "(4) set medicine reminders and follow-up check-ins, "
    "(5) use camera-scanned prescriptions to extract and record key details for better guidance over time."
)

SKILL_BUNDLE_PROMPT = _build_skill_prompt_bundle(SKILLS_ROOT)

# CareConnect Agent — the AI "brain"
agent = Agent(
    name="careconnect_agent",
    # Use a bidi-compatible model
    model="gemini-2.5-flash-native-audio-preview-12-2025",
    instruction=(
        BASE_AGENT_INSTRUCTION
        + "\n\n"
        + CAPABILITIES_RESPONSE_POLICY
        + ("\n\n# Skill Instructions\n" + SKILL_BUNDLE_PROMPT if SKILL_BUNDLE_PROMPT else "")
    ),
    tools=[google_search],
)

# Session service (in-memory for dev; swap for VertexAiSessionService in prod)
session_service = InMemorySessionService()

# Runner wires the agent + session together
runner = Runner(app_name=APP_NAME, agent=agent, session_service=session_service)

# ─────────────────────────────────────────────────────────────────────────────
# 2. WEBSOCKET ENDPOINT  (pattern from google/adk-samples bidi-demo)
# ─────────────────────────────────────────────────────────────────────────────

@app.websocket("/ws/{user_id}/{session_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    user_id: str,
    session_id: str,
) -> None:
    """Bidirectional streaming WebSocket between Flutter app and Gemini."""

    await websocket.accept()
    logger.debug(f"WS accepted: user={user_id} session={session_id}")

    # ── Detect model type and set response modality ───────────────────────────
    model_name: str = agent.model
    is_native_audio = "native-audio" in model_name.lower()

    if is_native_audio:
        # Native audio models: AUDIO response + transcription
        run_config = RunConfig(
            streaming_mode=StreamingMode.BIDI,
            response_modalities=["AUDIO"],
            input_audio_transcription=types.AudioTranscriptionConfig(),
            output_audio_transcription=types.AudioTranscriptionConfig(),
        )
    else:
        # Half-cascade models (flash-exp, etc.): TEXT is faster & more reliable
        run_config = RunConfig(
            streaming_mode=StreamingMode.BIDI,
            response_modalities=["TEXT"],
        )

    logger.debug(f"RunConfig: modalities={'AUDIO' if is_native_audio else 'TEXT'}")

    # ── Session: get existing or create new ───────────────────────────────────
    session = await session_service.get_session(
        app_name=APP_NAME, user_id=user_id, session_id=session_id
    )
    if not session:
        await session_service.create_session(
            app_name=APP_NAME, user_id=user_id, session_id=session_id
        )
        logger.debug("Created new session")
    else:
        logger.debug("Resumed existing session")

    # ── Live request queue (message bus between upstream and Gemini) ──────────
    live_request_queue = LiveRequestQueue()

    # ── PHASE 3: Concurrent bidirectional tasks ───────────────────────────────

    async def upstream_task() -> None:
        """Flutter → Backend → Gemini"""
        logger.debug("upstream_task started")
        while True:
            message = await websocket.receive()

            # Binary frames = raw PCM audio
            if "bytes" in message:
                audio_data = message["bytes"]
                audio_blob = types.Blob(mime_type="audio/pcm;rate=16000", data=audio_data)
                live_request_queue.send_realtime(audio_blob)
                logger.debug(f"Audio chunk sent: {len(audio_data)} bytes")

            # Text frames = JSON (type: text | image)
            elif "text" in message:
                json_msg = json.loads(message["text"])
                msg_type = json_msg.get("type")

                if msg_type == "text":
                    content = types.Content(
                        role="user",
                        parts=[types.Part(text=json_msg["text"])],
                    )
                    live_request_queue.send_content(content)
                    logger.debug(f"Text sent: {json_msg['text'][:80]}")

                elif msg_type == "image":
                    image_bytes = base64.b64decode(json_msg["data"])
                    mime = json_msg.get("mimeType", "image/jpeg")
                    image_blob = types.Blob(mime_type=mime, data=image_bytes)
                    live_request_queue.send_realtime(image_blob)
                    logger.debug(f"Image sent: {len(image_bytes)} bytes ({mime})")

    async def downstream_task() -> None:
        """Gemini → Backend → Flutter"""
        logger.debug("downstream_task started")
        async for event in runner.run_live(
            user_id=user_id,
            session_id=session_id,
            live_request_queue=live_request_queue,
            run_config=run_config,
        ):
            event_json = event.model_dump_json(exclude_none=True, by_alias=True)
            logger.debug(f"[EVENT] {event_json[:200]}")
            await websocket.send_text(event_json)

    # ── Run both tasks concurrently ───────────────────────────────────────────
    try:
        await asyncio.gather(upstream_task(), downstream_task())
    except WebSocketDisconnect:
        logger.debug("Client disconnected")
    except Exception as e:
        logger.error(f"Streaming error: {e}", exc_info=True)
    finally:
        live_request_queue.close()
        logger.debug("Queue closed, session ended")


# ─────────────────────────────────────────────────────────────────────────────
# 4. HEALTH CHECK (for Cloud Run or any container)
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "agent": agent.name}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8081))
    uvicorn.run(app, host="0.0.0.0", port=port)