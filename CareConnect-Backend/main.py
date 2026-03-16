import os
import asyncio
import json
import base64
import logging
import warnings
from pathlib import Path
from typing import List

# Load .env FIRST so GOOGLE_API_KEY is available before any google.adk import
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / ".env")

from firebase_admin import auth, initialize_app, get_app

FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "careconnect-3484b")
SKIP_TOKEN_VERIFY = os.environ.get("SKIP_TOKEN_VERIFY", "false").lower() == "true"

# Initialize Firebase Admin (ADC on Cloud Run service account or local GOOGLE_APPLICATION_CREDENTIALS)
try:
    get_app()
except Exception as _init_err:
    try:
        initialize_app(options={"projectId": FIREBASE_PROJECT_ID})
        logging.getLogger(__name__).info(
            f"Firebase Admin initialized with projectId={FIREBASE_PROJECT_ID}"
        )
    except Exception as _init_err_2:
        logging.getLogger(__name__).warning(
            f'Firebase Admin init issue: {_init_err}; fallback failed: {_init_err_2}'
        )
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Header, HTTPException
from pydantic import BaseModel
from google.adk.agents import Agent
from google.adk.agents.live_request_queue import LiveRequestQueue
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.adk.agents.run_config import RunConfig, StreamingMode
from google.genai import types
from google import genai
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
    "When user asks what happened in a doctor meeting, help summarize clearly from provided notes/transcript and call out medicine-allergy risks explicitly."
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


class NoteSummaryRequest(BaseModel):
    transcript: str
    allergies: List[str] = []


class NoteSummaryResponse(BaseModel):
    summary: str
    red_flags: List[str]


def _verify_bearer_token(authorization_header: str | None) -> str:
    """Returns UID if verified or raises HTTPException."""
    if SKIP_TOKEN_VERIFY:
        return "guest"

    if not authorization_header:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    token = authorization_header.strip()
    if token.lower().startswith("bearer "):
        token = token[7:].strip()

    if not token:
        raise HTTPException(status_code=401, detail="Missing bearer token")

    try:
        decoded = auth.verify_id_token(token)
        uid = decoded.get("uid")
        if not uid:
            raise HTTPException(status_code=401, detail="Invalid token")
        return uid
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning(f"Token verification failed: {exc}")
        raise HTTPException(status_code=401, detail="Token verification failed")


def _extract_allergy_flags(transcript: str, allergies: List[str]) -> List[str]:
    flags: List[str] = []
    text = (transcript or "").lower()
    keywords = ("prescribe", "prescribed", "medicine", "tablet", "capsule", "dose", "take")
    has_med_context = any(k in text for k in keywords)

    for raw in allergies:
        allergy = (raw or "").strip()
        if not allergy:
            continue
        if allergy.lower() in text and has_med_context:
            flags.append(
                f"Possible allergy conflict detected: '{allergy}' appears in meeting conversation with medication context."
            )

    # Deduplicate while preserving order
    deduped: List[str] = []
    for f in flags:
        if f not in deduped:
            deduped.append(f)
    return deduped


def _fallback_summary(transcript: str) -> str:
    lines = [ln.strip() for ln in (transcript or "").splitlines() if ln.strip()]
    if not lines:
        return "No transcript available to summarize."

    preview = lines[:8]
    return (
        "Summary (fallback):\n"
        + "\n".join(f"- {ln[:220]}" for ln in preview)
        + ("\n- ..." if len(lines) > len(preview) else "")
    )


@app.post("/notes/summarize", response_model=NoteSummaryResponse)
async def summarize_note(
    payload: NoteSummaryRequest,
    authorization: str | None = Header(default=None),
):
    """Summarize a doctor-patient meeting transcript and flag allergy risks."""
    _uid = _verify_bearer_token(authorization)

    transcript = (payload.transcript or "").strip()
    if not transcript:
        raise HTTPException(status_code=400, detail="Transcript is empty")

    red_flags = _extract_allergy_flags(transcript, payload.allergies)

    summary = ""
    api_key = os.environ.get("GOOGLE_API_KEY", "").strip()
    if api_key:
        try:
            client = genai.Client(api_key=api_key)
            prompt = (
                "You are a clinical note assistant. Summarize this doctor-patient conversation in plain language. "
                "Return: (1) key complaints, (2) doctor advice, (3) medicines and dosage/frequency/duration if present, "
                "(4) follow-up actions, (5) warning signs to monitor. Keep concise but complete.\n\n"
                f"Transcript:\n{transcript}"
            )
            result = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=prompt,
            )
            summary = (getattr(result, "text", None) or "").strip()
        except Exception as exc:
            logger.warning(f"AI summarization failed, using fallback summary: {exc}")

    if not summary:
        summary = _fallback_summary(transcript)

    return NoteSummaryResponse(summary=summary, red_flags=red_flags)

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

    # Auth: Verify Firebase ID token
    if SKIP_TOKEN_VERIFY:
        await websocket.accept()
        logger.warning("SKIP_TOKEN_VERIFY=true, bypassing Firebase token verification")
    
    token = websocket.query_params.get("token") if hasattr(websocket, "query_params") else None
    if not SKIP_TOKEN_VERIFY:
        try:
            decoded = auth.verify_id_token(token) if token else None
            uid = decoded.get("uid") if decoded else None
            if not uid:
                await websocket.close(code=4401)
                return
            user_id = uid
        except Exception as e:
            logger.warning(f"Auth failed (project={FIREBASE_PROJECT_ID}): {e}")
            await websocket.close(code=4401)
            return
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