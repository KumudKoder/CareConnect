# CareConnect

AI-powered healthcare assistant with a Flutter mobile app, real-time Gemini-backed chat backend, prescription analysis, and cloud-deployed agent services (MCP + ADK UI + A2A) on Google Cloud Run.

> [!IMPORTANT]
> **Security first:** this repository does **not** ship with usable private credentials.
> You must configure **your own** API keys, Firebase config, service-account credentials, and environment variables before running.
> Never commit real keys/tokens/secrets to GitHub.

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

## Google Cloud deployment status and public access

Current live services are deployed on Google Cloud Run.

### Live endpoints

- MCP endpoint:  
  `https://careconnect-mcp-server-1023139347696.us-central1.run.app/mcp`
- ADK Web UI:  
  `https://careconnect-adk-ui-1023139347696.us-central1.run.app`
- A2A service:  
  `https://careconnect-a2a-1023139347696.us-central1.run.app`
- A2A agent card:  
  `https://careconnect-a2a-1023139347696.us-central1.run.app/.well-known/agent.json`

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
