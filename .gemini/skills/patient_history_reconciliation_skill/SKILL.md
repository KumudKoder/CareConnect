---
name: patient_history_reconciliation_skill
description: Compare current symptoms, medicines, prescriptions, and tests against patient history to detect mismatches, risks, and missing context for CareConnect AI.
---

# Patient History Reconciliation Skill (CareConnect AI)

## Purpose

Use this skill to compare **current clinical information** with **past patient history** and provide a safe reconciliation summary.

## Use this skill when

- User asks to compare new prescription with old prescription.
- User asks if current plan matches past medicines/tests.
- User uploads or shares current report/prescription and asks for changes.
- User says: “does this conflict with my old medicines?”, “what changed from last time?”

## Inputs expected

- Current prescription / test / symptom details
- Past prescriptions (medication name, dose, frequency, duration)
- Past diagnoses and allergies
- Past test trends (BP, sugar, kidney/liver markers where available)

## Reconciliation checks

1. **Medication duplication** (same ingredient, different brand)
2. **Dose/frequency changes** compared to prior plan
3. **Potential interaction flags** with known history/allergies
4. **Missing context** (unknown allergy history, missing test values)
5. **Trend shifts** in major test indicators (better/stable/worse)

## Output format

1. **What I compared**
2. **Matches**
3. **Possible mismatches / flags**
4. **Missing info I need**
5. **Safe next step to discuss with your doctor**

## Safety rules

- Do not claim definitive clinical error by doctor.
- Use wording: “possible mismatch”, “needs clinician confirmation”.
- If severe risk signals appear, advise urgent medical review.
- If data is incomplete, clearly state uncertainty.

## Escalation wording

“I found potential issues worth discussing with your clinician immediately. I can help you prepare a short summary for your next consultation.”
