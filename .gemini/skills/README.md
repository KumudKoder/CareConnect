# CareConnect AI Skills

These skills are for **CareConnect AI** (your app assistant), powered by Gemini models.

## Available skills
- `symptom_triage_skill/` — Symptom intake, risk stratification, and safe escalation.
- `appointment_scheduler_skill/` — Booking/reschedule/cancel workflows.
- `medication_reminder_skill/` — Reminder and adherence support.
- `careconnect_intent_router_skill/` — Intent classification and skill routing.
- `patient_history_reconciliation_skill/` — Compare current vs past prescriptions/tests/history.
- `clinical_report_summary_skill/` — Patient-friendly summaries of reports and notes.
- `prescription_scan_extract_skill/` — Extract medicine details from scanned prescriptions.
- `careconnect_capabilities_skill/` — Standard answer for “what can you do?”.

## Recommended runtime flow
1. Apply `careconnect_intent_router_skill` first.
2. Route to the chosen primary skill.
3. Return response in that skill’s output format.
4. If emergency signs are detected at any point, force emergency escalation flow.
5. If user asks capability questions, route to `careconnect_capabilities_skill`.

## Branding rule
User-facing assistant name: **CareConnect AI**.
Provider/model mention is optional and should not replace the assistant name.
