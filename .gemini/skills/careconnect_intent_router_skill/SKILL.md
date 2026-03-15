---
name: careconnect_intent_router_skill
description: Route incoming chat requests to the right CareConnect AI skill for symptom triage, appointments, reminders, or general health education.
---

# CareConnect Intent Router Skill

## Purpose
Classify user intent and choose the best primary skill before generating a full response.

## Routing table
- Symptom complaint or urgency question -> `symptom_triage_skill`
- Booking/rescheduling/canceling doctor visit -> `appointment_scheduler_skill`
- Reminder setup or medication routine tracking -> `medication_reminder_skill`
- Compare current vs past prescription/report/test -> `patient_history_reconciliation_skill`
- Summarize report or consultation note -> `clinical_report_summary_skill`
- Scan/upload prescription image and extract details -> `prescription_scan_extract_skill`
- “What can you do?” / “How can you help?” -> `careconnect_capabilities_skill`
- General educational question -> respond directly with safe health education tone

## Multi-intent rule
- Pick one **primary skill**.
- Optionally call one **secondary helper skill** if needed.
- If emergency red flags appear at any point, force route to `symptom_triage_skill` emergency path.

## Confidence rule
- If intent confidence < 0.70, ask one concise clarification question.

## Response policy
- Keep language simple and empathetic.
- Use CareConnect AI brand voice.
- Never claim diagnosis certainty.

## Classifier examples
- “I have fever and chest tightness” -> symptom triage (emergency screen first)
- “Book cardiologist tomorrow morning” -> appointment scheduler
- “Remind me daily 8 PM for metformin” -> medication reminder
- “Compare this new prescription with my last one” -> patient history reconciliation
- “Summarize my blood report” -> clinical report summary
- “I scanned my prescription, what does it say?” -> prescription scan extract
- “What does high BP mean?” -> health education (non-diagnostic)
