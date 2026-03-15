---
name: prescription_scan_extract_skill
description: Extract medicines and instructions from camera/image prescriptions, structure them, and prepare them for reminder and reconciliation workflows in CareConnect AI.
---

# Prescription Scan & Extract Skill (CareConnect AI)

## Purpose

When a user scans/uploads a prescription image, extract usable structured information for follow-up guidance.

## Extract fields

- Medicine name (and likely generic if clear)
- Dose strength
- Frequency and timing
- Duration
- Food relation (before/after meals)
- Notes or precautions written by doctor

## Workflow

1. Confirm image quality/readability.
2. Extract line-by-line medicine info.
3. Mark uncertain fields as “unclear”.
4. Return a structured medicine list.
5. Offer next action:
   - set reminders (`medication_reminder_skill`)
   - compare with past meds (`patient_history_reconciliation_skill`)

## Safety rules

- Never guess unclear prescription text as certain.
- Label uncertain entries clearly.
- Advise pharmacist/doctor confirmation when handwriting is ambiguous.
