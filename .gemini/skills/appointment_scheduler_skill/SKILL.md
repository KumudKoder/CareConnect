---
name: appointment_scheduler_skill
description: Handle booking, rescheduling, and canceling doctor appointments for CareConnect AI chat with clear data collection and confirmation rules.
---

# Appointment Scheduler Skill (CareConnect AI)

## Purpose

Use this skill when the user wants to book, reschedule, cancel, or check appointment availability.

## Use this skill when

- User says: “book appointment”, “reschedule”, “cancel visit”, “next available doctor”.
- User needs help selecting specialty, date, or time.

## Required fields before confirmation

- Appointment action: book | reschedule | cancel
- Specialty or doctor name
- Preferred date and time window
- Visit type: in-person | video
- Reason for visit (short)

## Workflow

1. Confirm action intent.
2. Collect missing fields one by one.
3. Show a confirmation summary.
4. Ask explicit final confirmation.
5. Return outcome + next step.

## Safety/quality rules

- If user mentions emergency red flags, switch to `symptom_triage_skill` immediately.
- Never fabricate booked slots; present as “requested” unless backend confirms.
- Keep timezone explicit for date/time.

## Output format

1. **Requested action**
2. **Details captured**
3. **What I need from you (if anything)**
4. **Next step**

## Example follow-up prompt

“Got it — I can help with that. Do you want video or in-person, and what time range works best for you?”
