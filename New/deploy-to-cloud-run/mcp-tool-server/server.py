import asyncio
import base64
import json
import logging
import os
import re
from pathlib import Path
from typing import List

from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / ".env")

from fastmcp import FastMCP
from google import genai

# ─────────────────────────────────────────────────────────────────────────────
# Vertex AI client — shared across all tools
# ─────────────────────────────────────────────────────────────────────────────

GOOGLE_CLOUD_PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "careconnect-492419")
GOOGLE_CLOUD_LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

genai_client = genai.Client(
    vertexai=True,
    project=GOOGLE_CLOUD_PROJECT,
    location=GOOGLE_CLOUD_LOCATION,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.info(f"Vertex AI client ready: project={GOOGLE_CLOUD_PROJECT}, location={GOOGLE_CLOUD_LOCATION}")

# FastMCP server
mcp = FastMCP("CareConnect MCP Server")


def _extract_medicine_candidates(text: str) -> List[str]:
    pattern = re.compile(
        r"\b([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\s+(?:\d+(?:mg|ml|mcg))\b"
    )
    matches = [match.group(1).strip() for match in pattern.finditer(text)]
    seen = []
    for item in matches:
        if item not in seen:
            seen.append(item)
    return seen


def _safe_json(text: str, fallback):
    try:
        cleaned = text.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("```")[1]
            if cleaned.startswith("json"):
                cleaned = cleaned[4:]
        return json.loads(cleaned.strip())
    except Exception:
        return fallback

# TOOL 1: analyze_prescription

@mcp.tool()
def analyze_prescription(prescription_text: str) -> dict:
    """
    Extract medication details from prescription text using Gemini AI.
    Returns structured list of drugs with dosage, frequency, duration and warnings.
    Falls back to regex extraction if AI is unavailable.
    """
    try:
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=(
                "Extract all medications from this prescription text. "
                "Return ONLY valid JSON, no extra text:\n"
                '{"medicines": [{"name": "", "dosage": "", "frequency": "", '
                '"duration": "", "take_with_food": "", "instructions": ""}], '
                '"follow_up_questions": [], "note": ""}\n\n'
                f"Prescription text:\n{prescription_text}"
            ),
        )
        parsed = _safe_json(result.text or "{}", {})
        if not parsed:
            raise ValueError("Empty response from Gemini")
        parsed.setdefault(
            "note",
            "This is a supportive extraction only and must be verified by a licensed clinician.",
        )
        return parsed
    except Exception as exc:
        logger.warning(f"analyze_prescription AI failed, using regex fallback: {exc}")
        meds = _extract_medicine_candidates(prescription_text)
        return {
            "medicines_detected": meds,
            "medicine_count": len(meds),
            "follow_up_questions": [
                "What is the dose and frequency for each medicine?",
                "How many days should the patient continue each medicine?",
                "Should any medicine be taken before or after food?",
                "Are there any medicines from previous prescriptions that should be stopped?",
            ],
            "note": "Fallback extraction used. Must be verified by a licensed clinician.",
        }

# TOOL 2: analyze_prescription_image

@mcp.tool()
def analyze_prescription_image(image_base64: str, mime_type: str = "image/jpeg") -> dict:
    """
    Extract medication details from a prescription IMAGE using Gemini Vision.
    Accepts a base64-encoded image of a handwritten or printed prescription.
    Returns structured list of drugs with dosage, frequency and interaction warnings.
    This is the camera-scan tool for the Flutter prescription scanner screen.
    """
    try:
        from google.genai import types as genai_types
        image_bytes = base64.b64decode(image_base64)
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                genai_types.Part(
                    inline_data=genai_types.Blob(mime_type=mime_type, data=image_bytes)
                ),
                genai_types.Part(
                    text=(
                        "Extract all medications from this prescription image. "
                        "Return ONLY valid JSON, no extra text:\n"
                        '[{"drug": "", "brand": "", "generic": "", "dosage": "", '
                        '"frequency": "", "duration": "", "instructions": "", '
                        '"interaction_warning": ""}]'
                    )
                ),
            ],
        )
        medications = _safe_json(result.text or "[]", [])
        return {
            "medications": medications,
            "count": len(medications),
            "note": "Extracted via Gemini Vision. Verify with a licensed clinician.",
        }
    except Exception as exc:
        logger.error(f"analyze_prescription_image failed: {exc}")
        return {
            "medications": [],
            "count": 0,
            "error": str(exc),
            "note": "Image analysis failed. Please try again or enter prescription text manually.",
        }

# ─────────────────────────────────────────────────────────────────────────────
# TOOL 3: summarize_medical_report
# ─────────────────────────────────────────────────────────────────────────────


@mcp.tool()
def summarize_medical_report(report_text: str) -> dict:
    """
    Create a plain-language summary of a medical report using Gemini AI.
    Explains lab values, findings, and recommended actions in simple terms.
    Falls back to keyword scan if AI is unavailable.
    """
    try:
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=(
                "Summarize this medical report in plain language for a patient. "
                "Return ONLY valid JSON, no extra text:\n"
                '{"summary": "", "key_findings": [], '
                '"values_outside_normal": [], "recommended_actions": [], '
                '"clinician_follow_up": ""}\n\n'
                f"Medical report:\n{report_text}"
            ),
        )
        parsed = _safe_json(result.text or "{}", {})
        if not parsed:
            raise ValueError("Empty response")
        return parsed
    except Exception as exc:
        logger.warning(f"summarize_medical_report AI failed, using keyword fallback: {exc}")
        normalized = " ".join(report_text.split())
        findings = []
        for keyword in ["hemoglobin", "glucose", "creatinine", "platelet", "cholesterol", "blood pressure"]:
            if keyword.lower() in normalized.lower():
                findings.append(keyword)
        return {
            "report_topics_detected": findings,
            "plain_language_summary": "The report has been captured for review. Highlighted topics were identified from the text for easier discussion with a doctor.",
            "clinician_follow_up": "Please confirm whether any value is outside the normal range and whether treatment changes are needed.",
        }


# ─────────────────────────────────────────────────────────────────────────────
# TOOL 4: check_medicine_interactions
# ─────────────────────────────────────────────────────────────────────────────

@mcp.tool()
def check_medicine_interactions(medicines_csv: str, allergies_csv: str = "") -> dict:
    """
    Check for drug-drug interactions and allergy conflicts using Gemini AI.
    Pass medicines as a comma-separated string e.g. 'Metformin, Lisinopril, Aspirin'.
    Optionally pass known allergies as comma-separated e.g. 'penicillin, sulfa'.
    Falls back to hardcoded rule pairs if AI is unavailable.
    """
    medicines = [item.strip() for item in medicines_csv.split(",") if item.strip()]
    allergies = [a.strip() for a in allergies_csv.split(",") if a.strip()]
    try:
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=(
                f"Check these medications for drug interactions: {medicines}\n"
                f"Patient known allergies: {allergies}\n"
                "Return ONLY valid JSON, no extra text:\n"
                '{"interactions": [], "allergy_conflicts": [], '
                '"cautions": [], "safe": true, "disclaimer": ""}'
            ),
        )
        parsed = _safe_json(result.text or "{}", {})
        if not parsed:
            raise ValueError("Empty response")
        parsed.setdefault(
            "disclaimer",
            "This is informational support, not a diagnosis or prescription change recommendation.",
        )
        return parsed
    except Exception as exc:
        logger.warning(f"check_medicine_interactions AI failed, using rule fallback: {exc}")
        cautions = []
        lowered = {item.lower() for item in medicines}
        if {"warfarin", "aspirin"}.issubset(lowered):
            cautions.append("Warfarin and aspirin together may increase bleeding risk and require clinician review.")
        if {"metformin", "insulin"}.issubset(lowered):
            cautions.append("Metformin and insulin are commonly used together, but glucose monitoring is important.")
        if not cautions:
            cautions.append("No specific rule-based caution was detected from the provided list, but a pharmacist or doctor should still confirm safety.")
        return {
            "medicines": medicines,
            "cautions": cautions,
            "disclaimer": "This is informational support, not a diagnosis or prescription change recommendation.",
        }


# ─────────────────────────────────────────────────────────────────────────────
# TOOL 5: set_medicine_reminder  (scheduling)
# ─────────────────────────────────────────────────────────────────────────────

@mcp.tool()
def set_medicine_reminder(
    medicine_name: str,
    frequency: str,
    duration_days: int = 7,
    start_date: str = "today",
    user_id: str = "",
) -> dict:
    """
    Generate a reminder schedule that the Flutter app can store or schedule.
    Returns a structured reminder ready for Firestore storage.
    Includes suggested times based on frequency.
    """
    time_map = {
        "once daily":         ["8:00 AM"],
        "twice daily":        ["8:00 AM", "8:00 PM"],
        "three times daily":  ["8:00 AM", "2:00 PM", "8:00 PM"],
        "every 8 hours":      ["6:00 AM", "2:00 PM", "10:00 PM"],
        "every 6 hours":      ["6:00 AM", "12:00 PM", "6:00 PM", "12:00 AM"],
        "at bedtime":         ["9:00 PM"],
    }
    times = time_map.get(frequency.lower(), ["8:00 AM"])
    return {
        "medicine_name": medicine_name,
        "frequency": frequency,
        "suggested_times": times,
        "duration_days": duration_days,
        "start_date": start_date,
        "user_id": user_id,
        "status": "ready_for_app_scheduling",
        "message": (
            f"Reminder prepared for {medicine_name} with frequency "
            f"'{frequency}' for {duration_days} day(s) starting {start_date}."
        ),
    }

# ─────────────────────────────────────────────────────────────────────────────
# TOOL 6: translate_medical_text  (APAC multilingual support)
# ─────────────────────────────────────────────────────────────────────────────


@mcp.tool()
def translate_medical_text(text: str, target_language: str = "Hindi") -> dict:
    """
    Translate medical prescription or report text to an APAC language using Gemini.
    Supported: Tamil, Telugu, Hindi, Kannada, Malayalam,
               Tagalog, Bahasa Indonesia, Vietnamese, Sinhala, Thai.
    Medicine names and dosages are always kept in English.
    """
    supported = [
        "Tamil", "Telugu", "Hindi", "Kannada", "Malayalam",
        "Tagalog", "Bahasa Indonesia", "Vietnamese", "Sinhala", "Thai",
    ]
    if target_language not in supported:
        return {
            "error": f"Language '{target_language}' not supported.",
            "supported_languages": supported,
        }
    try:
        result = genai_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=(
                f"Translate this medical text to {target_language}.\n"
                "IMPORTANT RULES:\n"
                "1. Keep ALL medicine names, drug names, and dosages in English.\n"
                "2. Only translate instructions, advice, and descriptive sentences.\n"
                "3. Keep all numbers as-is.\n\n"
                f"Text to translate:\n{text}"
            ),
        )
        return {
            "original": text,
            "translated": result.text,
            "target_language": target_language,
            "note": "Medicine names and dosages preserved in English.",
        }
    except Exception as exc:
        logger.error(f"translate_medical_text failed: {exc}")
        return {
            "original": text,
            "translated": text,
            "target_language": target_language,
            "error": str(exc),
        }

# ─────────────────────────────────────────────────────────────────────────────
# Run MCP server
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    logger.info(f"Starting CareConnect MCP Server on port {port}")
    asyncio.run(
        mcp.run_async(
            transport="http",
            host="0.0.0.0",
            port=str(port),
        )
    )
