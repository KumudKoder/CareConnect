# CareConnect

AI-powered healthcare assistant with a Flutter mobile app, real-time Gemini-backed chat backend, prescription analysis, and cloud-deployed agent services (MCP + ADK UI + A2A) on Google Cloud Run.

## Cloud deployment runbook

For full Cloud Run deployment steps (MCP + ADK UI + A2A), see:

- `deploy-to-cloud-run/README.md`

> [!IMPORTANT]
> **Security first:** this repository does **not** ship with usable private credentials.
> You must configure **your own** API keys, Firebase config, service-account credentials, and environment variables before running.
> Never commit real keys/tokens/secrets to GitHub.

> [!TIP]
> **Enable local secret scanning (recommended):** run this once in repo root:
>
> `git config core.hooksPath .githooks`
>
> This activates the included pre-commit scanner (`.githooks/secret_scan.py`) so commits with likely secrets are blocked locally.
> A GitHub Actions workflow (`.github/workflows/secret-scan.yml`) also scans pushes/PRs in CI.

---

## What this project solves in real life

Many patients leave a clinic and forget important details:

- medicine names
- dosage timing
- duration
- what changed from earlier prescriptions

CareConnect helps by turning these into actionable, persistent records and an always-available assistant.

---

## Core app features (current)

### Mobile app (`careconnect_app`)

- Firebase auth (account-based experience)
- Dashboard, appointments, medicines, AI chat, profile
- **Prescription scanner** with AI extraction from image:
  - medicine name
  - brand ↔ generic mapping
  - dosage, frequency, duration
  - confidence score
  - interaction warning (if detected)
- **My Medicines** linked to logged-in user in Firestore (`users/{uid}/medicines`)
- Remove medicine with one tap (cross button)
- **AI chat** supports:
  - text
  - camera image
  - gallery image
  - voice input
- **Chat sessions**:
  - persistent local history (available even when logged out on same device)
  - temporary chat mode (not saved)
  - drawer with previous sessions

### Backend (`CareConnect-Backend`)

- FastAPI + WebSocket endpoint: `/ws/{user_id}/{session_id}`
- Gemini ADK live runner for streaming responses
- Firebase token verification (optional bypass in local dev)
- Health endpoint: `/health`

### Cloud agent stack (`deploy-to-cloud-run`)

- MCP server (tool layer)
- ADK Web UI service (chat interface)
- A2A service (machine-to-machine agent access)

---

## Agent capabilities

The CareConnect agent is designed to be a practical healthcare assistant (not a replacement for doctors):

1. Summarizes and explains prescriptions/reports in simple language
2. Highlights possible medicine mismatch or interaction risks for doctor confirmation
3. Uses scanned prescription content for better continuity over time
4. Helps with follow-up reminders and health context conversation
5. Supports multimodal interaction (text + voice + image)

### Current MCP tools exposed

- `analyze_prescription`
- `summarize_medical_report`
- `check_medicine_interactions`
- `set_medicine_reminder`

### Capability snapshot (practical)

- **Strong at**
  - converting prescription/report data into understandable summaries
  - extracting medicine details from images and structuring them
  - maintaining continuity (history + account-linked medicines + local chat sessions)
  - conversational help through text, voice, and images
- **Not intended for**
  - definitive diagnosis
  - emergency triage replacement
  - replacing clinician judgment

---

## Architecture at a glance

- **Flutter app** → Firebase Auth/Firestore + WebSocket backend
- **Backend** → ADK + Gemini live model
- **Cloud deployment**:
  - MCP server on Cloud Run
  - ADK UI on Cloud Run
  - A2A service on Cloud Run

---

## Step-by-step: run on your Android phone (Redmi)

This is the fastest local flow used in this repo.

### 1) Prerequisites

- Flutter SDK installed and in PATH
- Android SDK + ADB
- USB debugging enabled on phone
- Firebase files already configured in app (present in this repo)

Before first run, configure your Firebase project:

- Generate `firebase_options.dart` using FlutterFire CLI **or** fill the placeholders in `careconnect_app/lib/firebase_options.dart`
- Add your own `google-services.json` to `careconnect_app/android/app/`
- (If using iOS) add your own `GoogleService-Info.plist`

### 2) Start backend locally

From project root:

```powershell
Set-Location "<path-to-repo>\CareConnect-Backend"
if (-not (Test-Path ".\venv\Scripts\python.exe")) { python -m venv venv }
.\venv\Scripts\python.exe -m pip install --upgrade pip
.\venv\Scripts\python.exe -m pip install -r requirements.txt
.\venv\Scripts\python.exe main.py
```

Backend will run on `http://127.0.0.1:8081` by default.

### 3) Check phone connection

```powershell
adb start-server
adb devices -l
```

You should see your device id (example: `<android-device-id>`).

### 4) Run Flutter app on phone

Use your backend WS base URL when launching:

```powershell
Set-Location "<path-to-repo>\careconnect_app"
flutter pub get
flutter run -d <android-device-id> --dart-define=CARECONNECT_WS_BASE=ws://<your-local-ip>:8081
```

> Replace device id if different.

### 5) Verify app behavior

- Login works
- AI chat opens and sends text
- Camera/gallery image goes to AI chat
- Prescription scan extracts medicines
- “My Medicines” shows Firestore-linked records and delete works

---

## Troubleshooting (phone run)

- `Could not connect to Kotlin compile daemon` may appear in logs; if Gradle continues and APK installs, run is still okay.
- If app installs then `Lost connection to device`, app can still be running on device. Re-run `flutter run` to reattach.
- If backend auth fails in local testing, verify Firebase project and token flow.
- If AI chat says not connected, verify backend is running and `CARECONNECT_WS_BASE` is reachable from the device/network.

---

## Reproducible testing

Use the steps below when you want another developer, reviewer, or judge to reproduce the current behavior consistently.

### Test environment assumptions

- Windows machine with Flutter, Android SDK, ADB, and Python installed
- Android phone connected by USB with debugging enabled
- Backend dependencies installed from `CareConnect-Backend/requirements.txt`
- Firebase configured with your own project values
- Phone and laptop on the same network if the app must reach the local backend over Wi‑Fi

### 1) Start from a clean state

From repo root:

```powershell
Set-Location "<path-to-repo>\careconnect_app"
flutter clean
flutter pub get
```

From the backend folder:

```powershell
Set-Location "<path-to-repo>\CareConnect-Backend"
if (-not (Test-Path ".\venv\Scripts\python.exe")) { python -m venv venv }
.\venv\Scripts\python.exe -m pip install --upgrade pip
.\venv\Scripts\python.exe -m pip install -r requirements.txt
```

### 2) Run static verification

Flutter checks:

```powershell
Set-Location "<path-to-repo>\careconnect_app"
flutter analyze
flutter test
```

Backend smoke import / startup check:

```powershell
Set-Location "<path-to-repo>\CareConnect-Backend"
.\venv\Scripts\python.exe main.py
```

Expected result:

- Flutter analyzer completes without relevant errors
- Flutter tests pass
- Backend starts and exposes `http://127.0.0.1:8081/health`

### 3) Verify backend health endpoint

In a new terminal:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:8081/health" -UseBasicParsing
```

Expected result: HTTP 200 with a healthy status payload.

### 4) Run on a physical Android phone

Get your local IP address and device id, then launch:

```powershell
Set-Location "<path-to-repo>\careconnect_app"
adb devices -l
flutter run -d <android-device-id> --dart-define=CARECONNECT_WS_BASE=ws://<your-local-ip>:8081
```

Expected result:

- app installs on the phone
- login screen/dashboard opens
- AI chat opens without crashing
- app can reach the backend if the phone can access `<your-local-ip>:8081`

### 5) Functional regression checklist

Use this exact checklist for consistent manual validation:

1. Sign in with a test account.
2. Open **AI Chat** and send a text prompt.
3. Use the **camera** in chat and verify no crash occurs.
4. Use the **gallery** in chat and verify image upload works.
5. Start a **Meeting Note**, exchange a few messages, and stop the note.
6. Open the chat drawer and confirm the meeting note appears under cloud notes.
7. Open that note and run **Summarize**.
8. Ask: `What doctor told in my last meeting?`
9. Open **Prescription Scanner**, scan a prescription image, and confirm extracted medicines appear.
10. Open **My Medicines**, confirm records are linked to the signed-in account, then remove one medicine.

### 6) Artifact locations for verification

After a successful debug build, the APK should be present at one of these paths:

- `careconnect_app/build/app/outputs/flutter-apk/app-debug.apk`
- `careconnect_app/build/app/outputs/apk/debug/app-debug.apk`

### Notes for reviewers

- If the backend is not publicly deployed, local AI chat features depend on the laptop-hosted backend being reachable from the phone.
- If real Firebase credentials are not configured, authentication-dependent flows will not be reproducible.
- For broader sharing, prefer a release build and a cloud-hosted backend over a debug APK and local IP.

---

## Google Cloud deployment status and public access

Current live services are deployed on Google Cloud Run.

> [!NOTE]
> For security and portability, concrete project identifiers are intentionally replaced with placeholders below.
> Use this pattern for Cloud Run services:
> `https://<service>-<project-number>.<region>.run.app`

### Live endpoints

- MCP endpoint:  
  `https://<mcp-service>-<project-number>.<region>.run.app/mcp`
- ADK Web UI:  
  `https://<adk-ui-service>-<project-number>.<region>.run.app`
- A2A service:  
  `https://<a2a-service>-<project-number>.<region>.run.app`
- A2A agent card:  
  `https://<a2a-service>-<project-number>.<region>.run.app/.well-known/agent.json`

### How anyone can access and use the agent

1. **Human UI usage**: open ADK UI URL in browser and chat with the CareConnect agent.
2. **MCP client usage**: configure an MCP-compatible client to use the MCP endpoint.
3. **A2A integration**: read the agent card JSON and connect from an A2A-compatible consumer.

For full deploy/redeploy commands, see:  
`deploy-to-cloud-run/README.md`

---

## Repository structure

- `careconnect_app/` → Flutter mobile app
- `CareConnect-Backend/` → FastAPI + WebSocket + ADK runtime backend
- `deploy-to-cloud-run/` → Cloud Run deployment assets for MCP/UI/A2A
- `docs/` → architecture, strategy, and reference documentation

---

## Important disclaimer

CareConnect provides informational assistance and workflow support. It is not a substitute for licensed medical diagnosis or emergency care.
