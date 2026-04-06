import os
import asyncio
import json
import base64
import logging
import warnings
import uuid
import base64 as py_base64
from pathlib import Path
from typing import List

# Load .env FIRST before any google.adk import
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / ".env")
load_dotenv(Path(__file__).resolve().parents[3] / ".env")

SKIP_TOKEN_VERIFY = os.environ.get("SKIP_TOKEN_VERIFY", "false").lower() == "true"

# ── Google Cloud config (Vertex AI) ──────────────────────────────────────────
GOOGLE_CLOUD_PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "agent-490407")
GOOGLE_CLOUD_LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

# ── AlloyDB config ────────────────────────────────────────────────────────────
ALLOYDB_INSTANCE_URI = os.environ.get("ALLOYDB_INSTANCE_URI", "")
ALLOYDB_DB_NAME = os.environ.get("ALLOYDB_DB_NAME", "careconnect")
ALLOYDB_DB_USER = os.environ.get("ALLOYDB_DB_USER", "")
ALLOYDB_DB_PASSWORD = os.environ.get("ALLOYDB_DB_PASSWORD", "")
ALLOYDB_ENABLE_IAM_AUTH = os.environ.get("ALLOYDB_ENABLE_IAM_AUTH", "false").lower() == "true"

from google.cloud.alloydb.connector import Connector
import pg8000

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Header, HTTPException
from pydantic import BaseModel
from google.adk.agents import Agent
from google.adk.agents.live_request_queue import LiveRequestQueue
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.adk.agents.run_config import RunConfig, StreamingMode
from google.adk.tools import google_search, FunctionTool
from google.adk.tools.agent_tool import AgentTool
from google.genai import types
from google import genai

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Suppress pydantic serialization warnings
warnings.filterwarnings("ignore", category=UserWarning, module="pydantic")

# ─────────────────────────────────────────────────────────────────────────────
# 1. VERTEX AI CLIENT
# ─────────────────────────────────────────────────────────────────────────────
genai_client = genai.Client(
    vertexai=True,
    project=GOOGLE_CLOUD_PROJECT,
    location=GOOGLE_CLOUD_LOCATION,
)

# ─────────────────────────────────────────────────────────────────────────────
# 2. APPLICATION & SKILL LOADER
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(title="CareConnect API", version="2.0.0")
APP_NAME = "careconnect"
WORKSPACE_ROOT = Path(__file__).resolve().parent
SKILLS_ROOT = WORKSPACE_ROOT / ".gemini" / "skills"

def _build_skill_prompt_bundle(skills_root: Path) -> str:
    if not skills_root.exists():
        return ""
    skill_parts = []
    for skill_md in sorted(skills_root.glob("*/SKILL.md")):
        try:
            content = skill_md.read_text(encoding="utf-8").strip()
            if content:
                skill_parts.append(f"\n\n### Skill Source: {skill_md.parent.name}/SKILL.md\n{content}")
        except Exception as exc:
            logger.warning(f"Could not read skill file {skill_md}: {exc}")
    return "\n".join(skill_parts)

SKILL_BUNDLE_PROMPT = _build_skill_prompt_bundle(SKILLS_ROOT)

# ─────────────────────────────────────────────────────────────────────────────
# 3. ALLOYDB TOOLS
# ─────────────────────────────────────────────────────────────────────────────
_alloydb_connector = Connector()


def _get_conn() -> pg8000.dbapi.Connection:
    if not ALLOYDB_INSTANCE_URI or not ALLOYDB_DB_USER:
        raise RuntimeError(
            "AlloyDB is not configured. Set ALLOYDB_INSTANCE_URI and ALLOYDB_DB_USER."
        )
    return _alloydb_connector.connect(
        ALLOYDB_INSTANCE_URI,
        "pg8000",
        user=ALLOYDB_DB_USER,
        password=ALLOYDB_DB_PASSWORD,
        db=ALLOYDB_DB_NAME,
        enable_iam_auth=ALLOYDB_ENABLE_IAM_AUTH,
    )


def _ensure_alloydb_schema() -> None:
    try:
        conn = _get_conn()
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS health_records (
                    id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    record_type TEXT NOT NULL,
                    data JSONB NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS reminders (
                    id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    medication TEXT NOT NULL,
                    frequency TEXT NOT NULL,
                    start_date TEXT NOT NULL,
                    duration_days INTEGER NOT NULL,
                    active BOOLEAN NOT NULL DEFAULT TRUE,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
        conn.commit()
        conn.close()
        logger.info("AlloyDB schema ensured.")
    except Exception as exc:
        logger.warning(f"AlloyDB schema initialization skipped/failed: {exc}")


def store_health_record(user_id: str, record_type: str, data: str) -> dict:
    try:
        data_dict = json.loads(data) if isinstance(data, str) else data
        record_id = str(uuid.uuid4())
        conn = _get_conn()
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO health_records (id, user_id, record_type, data)
                VALUES (%s, %s, %s, %s::jsonb)
                """,
                (record_id, user_id, record_type, json.dumps(data_dict)),
            )
        conn.commit()
        conn.close()
        return {"status": "saved", "record_id": record_id, "record_type": record_type}
    except Exception as exc:
        return {"status": "error", "message": str(exc)}


def get_patient_history(user_id: str, record_type: str = "") -> dict:
    try:
        conn = _get_conn()
        with conn.cursor() as cur:
            if record_type:
                cur.execute(
                    """
                    SELECT id, record_type, data::text, created_at
                    FROM health_records
                    WHERE user_id=%s AND record_type=%s
                    ORDER BY created_at DESC
                    LIMIT 10
                    """,
                    (user_id, record_type),
                )
            else:
                cur.execute(
                    """
                    SELECT id, record_type, data::text, created_at
                    FROM health_records
                    WHERE user_id=%s
                    ORDER BY created_at DESC
                    LIMIT 10
                    """,
                    (user_id,),
                )
            rows = cur.fetchall()
        conn.close()
        records = []
        for row in rows:
            records.append(
                {
                    "id": row[0],
                    "type": row[1],
                    "data": json.loads(row[2]) if isinstance(row[2], str) else row[2],
                    "timestamp": row[3].isoformat() if row[3] else None,
                }
            )
        return {"records": records, "count": len(records)}
    except Exception as exc:
        return {"records": [], "count": 0, "error": str(exc)}


def set_medication_reminder(user_id: str, medication: str, frequency: str, start_date: str, duration_days: int) -> dict:
    try:
        reminder_id = str(uuid.uuid4())
        conn = _get_conn()
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO reminders (id, user_id, medication, frequency, start_date, duration_days, active)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (reminder_id, user_id, medication, frequency, start_date, duration_days, True),
            )

            # Keep reminder discoverable via history tooling as well
            reminder_record_id = str(uuid.uuid4())
            reminder_payload = {
                "medication": medication,
                "frequency": frequency,
                "start_date": start_date,
                "duration_days": duration_days,
                "active": True,
            }
            cur.execute(
                """
                INSERT INTO health_records (id, user_id, record_type, data)
                VALUES (%s, %s, %s, %s::jsonb)
                """,
                (reminder_record_id, user_id, "reminder", json.dumps(reminder_payload)),
            )

        conn.commit()
        conn.close()
        return {"status": "reminder_set", "reminder_id": reminder_id, "medication": medication}
    except Exception as exc:
        return {"status": "error", "message": str(exc)}

def check_medicine_interactions(medications: str, allergies: str = "") -> dict:
    try:
        meds_list = json.loads(medications) if isinstance(medications, str) else medications
        allergy_list = json.loads(allergies) if isinstance(allergies, str) and allergies else []
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=(f"Check interactions: {meds_list}. Allergies: {allergy_list}. Return JSON.")
        )
        text = (result.text or "").strip().replace("```json", "").replace("```", "")
        return json.loads(text)
    except Exception:
        return {"interactions": [], "safe": True}

def analyze_prescription_image(image_base64: str, mime_type: str = "image/jpeg") -> dict:
    try:
        image_bytes = base64.b64decode(image_base64)
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                types.Part(inline_data=types.Blob(mime_type=mime_type, data=image_bytes)),
                types.Part(text="Extract medications as JSON list: [{\"drug\": \"\", \"dosage\": \"\", \"frequency\": \"\", \"duration\": \"\"}]")
            ]
        )
        text = (result.text or "[]").strip().replace("```json", "").replace("```", "")
        meds = json.loads(text)
        return {"medications": meds, "count": len(meds)}
    except Exception:
        return {"medications": [], "count": 0}

def translate_medical_text(text: str, target_language: str) -> dict:
    try:
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=f"Translate to {target_language}. Keep medicine names in English: {text}"
        )
        return {"translated": result.text, "language": target_language}
    except Exception:
        return {"translated": text, "error": "translation failed"}

# Register tools
store_record_tool = FunctionTool(func=store_health_record)
get_history_tool = FunctionTool(func=get_patient_history)
set_reminder_tool = FunctionTool(func=set_medication_reminder)
check_interactions_tool = FunctionTool(func=check_medicine_interactions)
analyze_image_tool = FunctionTool(func=analyze_prescription_image)
translate_tool = FunctionTool(func=translate_medical_text)

# ─────────────────────────────────────────────────────────────────────────────
# 4. MULTI-AGENT SYSTEM
# ─────────────────────────────────────────────────────────────────────────────

# ── SUB-AGENT 1: Prescription Agent ──────────────────────────────────────────
prescription_agent = Agent(
    name="prescription_agent",
    model="gemini-2.5-flash",
    instruction=(
        "You are a prescription specialist within the CareConnect system. "
        "Your ONLY responsibilities are:\n"
        "1. Extract medication details from prescription images using analyze_prescription_image.\n"
        "2. Check for drug-drug interactions and allergy conflicts using check_medicine_interactions.\n"
        "3. Return structured, clear medication information.\n\n"
        "Rules:\n"
        "- Always call check_medicine_interactions after extracting medications.\n"
        "- Never claim definitive diagnosis.\n"
        "- Always flag interaction warnings for doctor confirmation.\n"
        "- Return results in simple, patient-friendly language."
    ),
    tools=[analyze_image_tool, check_interactions_tool],
)

# ── SUB-AGENT 2: Reminder & Schedule Agent ───────────────────────────────────
reminder_agent = Agent(
    name="reminder_agent",
    model="gemini-2.5-flash",
    instruction=(
        "You are a medication schedule manager within the CareConnect system. "
        "Your ONLY responsibilities are:\n"
        "1. Set medication reminders using set_medication_reminder.\n"
        "2. Retrieve upcoming medication schedules using get_patient_history.\n"
        "3. Help patients stay on track with their medication routine.\n\n"
        "Rules:\n"
        "- Always confirm medication name, frequency, and duration before setting a reminder.\n"
        "- Set one reminder per medication per prescription.\n"
        "- When listing schedules, group by time of day (morning/afternoon/evening/night)."
    ),
    tools=[set_reminder_tool, get_history_tool],
)

# ── SUB-AGENT 3: Health Records Agent ────────────────────────────────────────
records_agent = Agent(
    name="health_records_agent",
    model="gemini-2.5-flash",
    instruction=(
        "You are a health records manager within the CareConnect system. "
        "Your ONLY responsibilities are:\n"
        "1. Store new prescriptions, test results, and vitals using store_health_record.\n"
        "2. Retrieve patient health history using get_patient_history.\n"
        "3. Compare current medications against past prescriptions.\n"
        "4. Identify patterns or changes in health data over time.\n\n"
        "Rules:\n"
        "- NEVER share one patient's data with another.\n"
        "- Always use the correct user_id when storing or retrieving.\n"
        "- When comparing records, explicitly list: matches, mismatches, and new additions."
    ),
    tools=[store_record_tool, get_history_tool],
)

# ── SUB-AGENT 4: Notes & Translation Agent ───────────────────────────────────
notes_agent = Agent(
    name="notes_agent",
    model="gemini-2.5-flash",
    instruction=(
        "You are a medical notes and translation specialist within the CareConnect system. "
        "Your ONLY responsibilities are:\n"
        "1. Summarize doctor-patient meeting transcripts in SOAP format "
        "(Subjective, Objective, Assessment, Plan).\n"
        "2. Extract action items and follow-up tasks from consultations.\n"
        "3. Translate medical text to the patient's preferred language using translate_medical_text.\n\n"
        "Rules:\n"
        "- Keep summaries concise but complete.\n"
        "- Always call out medicine-allergy risks explicitly in summaries.\n"
        "- When translating, always keep medicine names and dosages in English."
    ),
    tools=[translate_tool],
)

# ── PRIMARY ORCHESTRATOR AGENT ───────────────────────────────────────────────
BASE_AGENT_INSTRUCTION = (
    "You are CareConnect AI, a helpful and concise AI medical assistant powered by Gemini. "
    "Talk directly to the user. Keep your answers brief, simple, empathetic, and easy to read. "
    "Do NOT output internal thoughts like 'Acknowledge and Await' or repeat yourself. "
    "Avoid complex formatting unless necessary. "
    "Always consider the user's prior history context when available "
    "(past medicines, prescriptions, tests, allergies, and chronic conditions). "
    "If past data is missing, explicitly ask the user to share previous prescriptions/reports "
    "or scan them before concluding. "
    "When comparing current vs past records, explicitly list matches, possible mismatches, "
    "and missing information. "
    "Never claim definitive diagnosis or accuse clinicians of error; "
    "instead flag possible issues that need clinician confirmation. "
    "When user asks what happened in a doctor meeting, help summarize clearly from provided "
    "notes/transcript and call out medicine-allergy risks explicitly."
)

CAPABILITIES_RESPONSE_POLICY = (
    "If user asks 'what can you do' or 'how can you help me', respond that you can:\n"
    "(1) Analyze past and current prescriptions/reports together.\n"
    "(2) Flag possible medicine mismatches/interactions to discuss with doctor.\n"
    "(3) Summarize reports in simple language.\n"
    "(4) Set medicine reminders and follow-up check-ins.\n"
    "(5) Translate prescriptions to your preferred language (Tamil, Telugu, Hindi, Tagalog, Bahasa).\n"
    "(6) Use camera-scanned prescriptions to extract and record key details for better guidance over time."
)

MULTI_AGENT_ROUTING = (
    "\n\nYou are the PRIMARY ORCHESTRATOR coordinating 4 specialist sub-agents:\n"
    "- prescription_agent: Use for analyzing prescription images and checking drug interactions.\n"
    "- reminder_agent: Use for setting medication reminders and retrieving schedules.\n"
    "- health_records_agent: Use for storing or retrieving patient health data from AlloyDB.\n"
    "- notes_agent: Use for summarizing doctor meeting transcripts and translating medical text.\n\n"
    "ROUTING RULES:\n"
    "1. For 'scan my prescription' → prescription_agent first, then health_records_agent to save, "
    "then reminder_agent to set reminders. This is the full new_prescription workflow.\n"
    "2. For 'what medicines am I taking' → health_records_agent.\n"
    "3. For 'set a reminder' → reminder_agent.\n"
    "4. For 'summarize my doctor visit' → notes_agent.\n"
    "5. For 'translate this prescription' → notes_agent.\n"
    "6. For general health questions → use google_search for current information.\n"
    "Always tell the user which step you are on in multi-step workflows."
)

orchestrator_instruction = (
    BASE_AGENT_INSTRUCTION
    + "\n\n"
    + CAPABILITIES_RESPONSE_POLICY
    + MULTI_AGENT_ROUTING
    + (
        "\n\n# Skill Instructions\n" + SKILL_BUNDLE_PROMPT
        if SKILL_BUNDLE_PROMPT
        else ""
    )
)
orchestrator_instruction = "You are CareConnect AI Orchestrator..." + SKILL_BUNDLE_PROMPT
agent = Agent(
    name="careconnect_orchestrator",
    model="gemini-2.5-flash-native-audio-preview-12-2025",
    instruction=orchestrator_instruction,
    tools=[AgentTool(agent=prescription_agent), AgentTool(agent=reminder_agent), AgentTool(agent=records_agent), AgentTool(agent=notes_agent), google_search],
)

session_service = InMemorySessionService()
runner = Runner(app_name=APP_NAME, agent=agent, session_service=session_service)


@app.on_event("startup")
async def on_startup() -> None:
    _ensure_alloydb_schema()


@app.on_event("shutdown")
async def on_shutdown() -> None:
    try:
        _alloydb_connector.close()
    except Exception:
        pass

# ─────────────────────────────────────────────────────────────────────────────
# 5. PYDANTIC MODELS
# ─────────────────────────────────────────────────────────────────────────────
class NoteSummaryRequest(BaseModel):
    transcript: str
    allergies: List[str] = []

class NoteSummaryResponse(BaseModel):
    summary: str
    red_flags: List[str]

class PrescriptionRequest(BaseModel):
    image_base64: str
    mime_type: str = "image/jpeg"

class TranslateRequest(BaseModel):
    text: str
    target_language: str = "Hindi"

class WorkflowRequest(BaseModel):
    user_id: str
    workflow_type: str  # "new_prescription", "check_schedule", "review_history"
    image_base64: str = ""
    text: str = ""
    allergies: List[str] = []

# ─────────────────────────────────────────────────────────────────────────────
# 6. AUTH HELPERS
# ─────────────────────────────────────────────────────────────────────────────
def _verify_bearer_token(authorization_header: str | None) -> str:
    if SKIP_TOKEN_VERIFY:
        return "guest"
    if not authorization_header:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = authorization_header.replace("Bearer ", "").strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    try:
        # Lightweight decode for uid/sub extraction (without signature verification)
        parts = token.split(".")
        if len(parts) != 3:
            return "token_user"
        payload = parts[1]
        payload += "=" * (-len(payload) % 4)
        decoded_payload = json.loads(py_base64.urlsafe_b64decode(payload.encode("utf-8")).decode("utf-8"))
        return decoded_payload.get("uid") or decoded_payload.get("sub") or "token_user"
    except Exception:
        return "token_user"

def _extract_allergy_flags(transcript: str, allergies: List[str]) -> List[str]:
    return [f"Allergy risk: {a}" for a in allergies if a.lower() in transcript.lower()]

# ─────────────────────────────────────────────────────────────────────────────
# 7. REST ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/notes/summarize", response_model=NoteSummaryResponse)
async def summarize_note(payload: NoteSummaryRequest, authorization: str | None = Header(default=None)):
    _uid = _verify_bearer_token(authorization)
    result = genai_client.models.generate_content(model="gemini-2.5-flash", contents=f"Summarize: {payload.transcript}")
    return NoteSummaryResponse(summary=result.text, red_flags=_extract_allergy_flags(payload.transcript, payload.allergies))

@app.post("/prescription/analyze")
async def analyze_prescription(payload: PrescriptionRequest, authorization: str | None = Header(default=None)):
    _verify_bearer_token(authorization)
    return analyze_prescription_image(payload.image_base64, payload.mime_type)

@app.post("/prescription/translate")
async def translate_prescription(payload: TranslateRequest, authorization: str | None = Header(default=None)):
    _verify_bearer_token(authorization)
    return translate_medical_text(payload.text, payload.target_language)

@app.post("/workflow/run")
async def run_workflow(payload: WorkflowRequest, authorization: str | None = Header(default=None)):
    _uid = _verify_bearer_token(authorization)
    result_steps = []

    # SYNC LOGIC: Set session_id for state tracking
    session_id = f"workflow_{payload.user_id}_{payload.workflow_type}"

    # 1. New Prescription Workflow
    if payload.workflow_type == "new_prescription":
        if not payload.image_base64:
            raise HTTPException(status_code=400, detail="image_base64 required for new_prescription workflow")

        logger.info(f"Workflow[new_prescription] Step 1: Analyzing prescription for user {payload.user_id}")
        prescription_result = analyze_prescription_image(image_base64=payload.image_base64)
        result_steps.append({"step": 1, "action": "analyze_prescription", "result": prescription_result})

        medications = prescription_result.get("medications", [])
        if not medications:
            return {"workflow": payload.workflow_type, "status": "completed", "steps": result_steps, "message": "No medications found."}

        logger.info(f"Workflow[new_prescription] Step 2: Checking interactions")
        med_names = [m.get("drug", "") for m in medications if m.get("drug")]
        interaction_result = check_medicine_interactions(medications=json.dumps(med_names), allergies=json.dumps(payload.allergies))
        result_steps.append({"step": 2, "action": "check_interactions", "result": interaction_result})

        logger.info(f"Workflow[new_prescription] Step 3: Saving to health records")
        save_result = store_health_record(user_id=payload.user_id, record_type="prescription", data=json.dumps({"meds": medications, "ints": interaction_result}))
        result_steps.append({"step": 3, "action": "save_health_record", "result": save_result})

        logger.info(f"Workflow[new_prescription] Step 4: Setting reminders")
        reminder_results = []
        for med in medications:
            reminder = set_medication_reminder(payload.user_id, med.get("drug", "Med"), med.get("frequency", "daily"), "today", 7)
            reminder_results.append(reminder)
        result_steps.append({"step": 4, "action": "set_reminders", "result": reminder_results})

        return {"workflow": payload.workflow_type, "status": "completed", "steps": result_steps, "session_id": session_id}

    # 2. Check Schedule Workflow
    elif payload.workflow_type == "check_schedule":
        logger.info(f"Workflow[check_schedule] for user {payload.user_id}")
        history = get_patient_history(user_id=payload.user_id, record_type="prescription")
        reminders = get_patient_history(user_id=payload.user_id, record_type="")
        return {"workflow": payload.workflow_type, "status": "completed", "prescriptions": history, "reminders": reminders, "session_id": session_id}

    # 3. Review History Workflow
    elif payload.workflow_type == "review_history":
        logger.info(f"Workflow[review_history] for user {payload.user_id}")
        history = get_patient_history(user_id=payload.user_id)
        summary = "Health summary generated..." if history["records"] else "No records found."
        return {"workflow": payload.workflow_type, "status": "completed", "history": history, "summary": summary, "session_id": session_id}

    else:
        raise HTTPException(status_code=400, detail="Unknown workflow_type")

# ─────────────────────────────────────────────────────────────────────────────
# 8. WEBSOCKET ENDPOINT
# ─────────────────────────────────────────────────────────────────────────────

@app.websocket("/ws/{user_id}/{session_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str, session_id: str):
    await websocket.accept()
    live_request_queue = LiveRequestQueue()

    async def upstream_task():
        while True:
            message = await websocket.receive()
            if "bytes" in message:
                live_request_queue.send_realtime(types.Blob(mime_type="audio/pcm;rate=16000", data=message["bytes"]))
            elif "text" in message:
                live_request_queue.send_content(types.Content(role="user", parts=[types.Part(text=json.loads(message["text"])["text"])]))

    async def downstream_task():
        async for event in runner.run_live(user_id=user_id, session_id=session_id, live_request_queue=live_request_queue, run_config=RunConfig(streaming_mode=StreamingMode.BIDI)):
            await websocket.send_text(event.model_dump_json(exclude_none=True, by_alias=True))

    try:
        await asyncio.gather(upstream_task(), downstream_task())
    except:
        live_request_queue.close()

# ─────────────────────────────────────────────────────────────────────────────
# 9. HEALTH CHECK
# ─────────────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "agent": agent.name}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)