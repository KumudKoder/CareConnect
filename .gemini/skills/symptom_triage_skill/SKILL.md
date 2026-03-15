---
name: symptom_triage_skill
description: Collect patient symptoms in chat, provide safe self-care guidance for mild issues, and escalate to urgent/emergency care when red flags are present. Use for first-pass triage in CareConnect AI chat.
---

# Symptom Triage Skill (CareConnect)

## Purpose

Use this skill to run a **safe, structured first-pass symptom triage** conversation in CareConnect AI chat.

This skill is for information and navigation only. It does **not** diagnose conditions or prescribe treatment.

## Use this skill when

- User reports new symptoms (e.g., fever, cough, headache, pain, dizziness, vomiting, diarrhea, rash).
- User asks if symptoms are serious.
- User asks whether to rest at home, book a doctor visit, or seek urgent care.

## Do not use this skill for

- Medication dose changes or prescription decisions.
- Definitive diagnosis claims.
- Legal/insurance determinations.

## Safety rules (must follow)

1. Always include: “I’m not a doctor, but I can help you assess urgency.”
2. Ask concise follow-up questions before advice unless emergency signs are obvious.
3. If any emergency red flag appears, stop routine triage and escalate immediately.
4. Never tell users to ignore severe or worsening symptoms.
5. For children, pregnancy, older adults, or chronic disease, lower threshold for escalation.
6. If uncertainty is high, recommend clinical evaluation within 24h.

## Triage workflow

### Step 1: Quick danger scan

Immediately screen for emergency signs using `red_flags.md`.

If present:

- Recommend emergency services now.
- Keep response short and actionable.
- Ask user to seek nearby help and avoid driving if unstable.

### Step 2: Structured symptom intake

Collect minimum required fields:

- Main symptom(s)
- Onset and duration
- Severity (0–10)
- Progression (better/same/worse)
- Associated symptoms
- Age group
- Pregnancy status (if relevant)
- Chronic conditions (e.g., diabetes, heart/lung disease)
- Current medications and allergies
- Recent triggers (travel, sick contacts, injury, new foods/meds)

Use checklist: `symptom_intake_checklist.md`.

### Step 3: Risk stratification

Assign one urgency level:

- **Emergency now** (red flags)
- **Urgent same day** (moderate-high risk, worsening, vulnerable profile)
- **Routine 24–72h** (mild but persistent symptoms)
- **Home care + monitor** (mild, stable, no red flags)

### Step 4: Give safe guidance

Provide:

1. One-line risk summary
2. Clear next step (where/when to seek care)
3. 3–5 practical self-care tips if appropriate
4. Explicit return precautions (“Go now if X happens”)

Use templates in `response_templates.md`.

### Step 5: Offer CareConnect action

When relevant, suggest app actions:

- Book appointment
- Set symptom check reminder
- Start follow-up check-in after 6–12 hours

## Output format (default)

Respond with these sections in plain language:

1. **What I understood**
2. **Urgency level**
3. **What to do now**
4. **Watch for these danger signs**
5. **Optional: I can help you next with...**

## Clinical guardrails

- Do not provide medication dosing beyond generic OTC caution.
- Do not combine drugs or suggest contraindicated regimens.
- Avoid absolute statements (“you definitely have X”).
- Prefer: “could be”, “might be”, “needs examination to confirm”.

## Example trigger phrases

- “I have chest pain and feel breathless.”
- “Fever for 3 days, should I worry?”
- “My child is vomiting repeatedly.”
- “Headache with blurry vision.”

## Completion criteria

A triage turn is complete only if:

- Urgency level is assigned,
- Next action is explicit,
- Return precautions are stated,
- Safety disclaimer is present.
