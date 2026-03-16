import asyncio
import os
import re
from typing import List

from fastmcp import FastMCP


mcp = FastMCP("CareConnect MCP Server")


def _extract_medicine_candidates(text: str) -> List[str]:
    pattern = re.compile(r"\b([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\s+(?:\d+(?:mg|ml|mcg))\b")
    matches = [match.group(1).strip() for match in pattern.finditer(text)]
    seen = []
    for item in matches:
        if item not in seen:
            seen.append(item)
    return seen


@mcp.tool()
def analyze_prescription(prescription_text: str) -> dict:
    """Extract medicine-like entries and practical follow-up questions from prescription text."""
    meds = _extract_medicine_candidates(prescription_text)
    questions = [
        "What is the dose and frequency for each medicine?",
        "How many days should the patient continue each medicine?",
        "Should any medicine be taken before or after food?",
        "Are there any medicines from previous prescriptions that should be stopped?",
    ]
    return {
        "medicines_detected": meds,
        "medicine_count": len(meds),
        "follow_up_questions": questions,
        "note": "This is a supportive extraction only and must be verified by a licensed clinician.",
    }


@mcp.tool()
def summarize_medical_report(report_text: str) -> dict:
    """Create a structured non-diagnostic summary from a pasted medical report."""
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


@mcp.tool()
def check_medicine_interactions(medicines_csv: str) -> dict:
    """Provide caution-focused, non-diagnostic guidance for a medicine list."""
    medicines = [item.strip() for item in medicines_csv.split(",") if item.strip()]
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


@mcp.tool()
def set_medicine_reminder(medicine_name: str, frequency: str, duration_days: int = 7) -> dict:
    """Generate a reminder summary that a frontend/app can store or schedule."""
    return {
        "medicine_name": medicine_name,
        "frequency": frequency,
        "duration_days": duration_days,
        "status": "ready_for_app_scheduling",
        "message": f"Reminder prepared for {medicine_name} with frequency '{frequency}' for {duration_days} day(s).",
    }


if __name__ == "__main__":
    asyncio.run(
        mcp.run_async(
            transport="http",
            host="0.0.0.0",
            port=os.getenv("PORT", "8080"),
        )
    )