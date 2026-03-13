# CareConnect Flow Diagrams - Complete Documentation

## Overview

CareConnect is a multi-layered application with several interconnected workflows. This document explains how each feature works from user action to data persistence.

---

## 1. User Navigation Flow

### How Users Move Through the App

```
Login/Signup Screen
       ↓
Main App (Bottom Navigation with 5 tabs)
├── 🏠 Home (Dashboard)
│   ├─ Health Summary Card
│   ├─ Quick Action Buttons
│   ├─ AI Assistant Widget
│   └─ Medicine Reminders
├── 📅 Appointments
│   ├─ Upcoming Appointments List
│   ├─ Book New Appointment
│   ├─ Live Consultation Screen
│   └─ Appointment History
├── 💊 Medicines
│   ├─ Active Medicines List
│   ├─ Add New Medicine
│   ├─ Scan Prescription
│   └─ Medicine Details
├── 💬 AI Chat (Ask AI Doctor)
│   ├─ Chat History
│   ├─ Voice Input
│   ├─ Text Input
│   └─ Follow-up Questions
└── 👤 Profile
    ├─ User Info
    ├─ Health Profile
    ├─ Settings
    └─ Emergency Contacts
```

**Key Point**: Bottom navigation is always visible. Users can switch between screens instantly without losing their current state (handled by Riverpod providers).

---

## 2. Data Flow Architecture

### Complete Data Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                    UI LAYER (Screens)                       │
│  Dashboard | Appointments | Medicines | Chat | Profile      │
└──────────────────┬──────────────────────────────────────────┘
                   │ (User interactions)
┌──────────────────▼──────────────────────────────────────────┐
│          STATE MANAGEMENT (Riverpod Providers)              │
│ userProvider | appointmentProvider | medicineProvider       │
│ chatProvider | healthDataProvider | profileProvider        │
└──────────────────┬──────────────────────────────────────────┘
                   │ (Requests data)
┌──────────────────▼──────────────────────────────────────────┐
│              SERVICES LAYER                                 │
│ API Service | Storage | AI | Video | Notification          │
└──────────────────┬──────────────────────────────────────────┘
                   │ (Calls APIs/Database)
┌──────────────────▼──────────────────────────────────────────┐
│            DATA SOURCES                                     │
│ Firebase | Database | Gemini AI | Agora | Local Cache      │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow Directions

**Upstream** (User Action → API):
1. User taps button in UI
2. Widget calls provider method
3. Provider updates local state
4. Service makes API call
5. API updates backend database

**Downstream** (API Response → UI):
1. Backend returns response
2. Service updates local cache
3. Provider notifies listeners
4. UI automatically rebuilds with new data
5. User sees updated screen

---

## 3. Live Appointment Workflow

### Real-Time Doctor-Patient Consultation

```
PATIENT SIDE                          DOCTOR SIDE
    │                                    │
    ├─ Opens app                        ├─ Opens app
    ├─ Taps "Join Call"                 ├─ Taps "Start Consultation"
    │
    └─ Requests permissions
       (Camera, Microphone)             └─ Requests permissions
       │                                   │
       ├─ Sends token request ────────────┤
       │  to backend                      │
       │                                   │
       ├─ Gets Agora token ◄─────────────┤
       │  (from Firebase)                 │
       │                                  │
       └─ Joins Agora channel ────────────┘
          (Video/Audio Stream)            │
                                          │ Joins same channel
                                          │
REAL-TIME CONVERSATION:
    │
    ├─ Patient (speaks in Hindi)
    │  "मुझे ठंड लग गया है"
    │
    ├─ Agora streams audio to Gemini Live AI
    │
    ├─ Gemini translates in real-time
    │  "I have caught a cold"
    │
    ├─ Doctor hears (in English)
    │  and responds
    │
    ├─ Gemini translates back
    │  "आपको आराम करने की जरूरत है"
    │
    └─ Patient hears (in Hindi)
       
PRESCRIPTION ISSUANCE:
    │
    ├─ Doctor types prescription in app
    │  (Paracetamol, 2x daily, 3 days)
    │
    └─ Prescription instantly appears
       on patient's screen
       
DRUG INTERACTION CHECK:
    │
    ├─ AI checks prescription against
    │  patient's current medicines
    │
    ├─ Detects: No interactions ✓
    │
    └─ Both see confirmation
       
SESSION END:
    │
    ├─ Appointment marked as "Completed"
    ├─ Call summary generated
    ├─ Prescription saved
    └─ Data synced to Firebase
```

### Technical Components

- **Video/Audio**: Agora RTC Engine (real-time streaming)
- **Translation**: Gemini Live API (context-aware, streaming)
- **Prescription Storage**: Firebase + Hive
- **Drug Interaction DB**: Local database of known interactions
- **Notification**: Firebase + Local notifications

---

## 4. Medication Reminder & Adherence Workflow

### Smart Reminder System

```
MEDICINE ADDED TO PROFILE:
    │
    ├─ User adds "Aspirin 1 tablet"
    ├─ Time: 8 AM & 8 PM
    │
    └─ System schedules reminders
       in background using WorkManager

DAILY REMINDER CYCLE:
    │
    ├─ 7:55 AM: Background job wakes up
    │
    ├─ Checks scheduled reminders
    │  (finds: Aspirin 8 AM)
    │
    ├─ Gathers context from device:
    │  • Recent location changes?
    │  • Did user check in at home?
    │  • Any food logs today?
    │
    ├─ AI generates smart message:
    │  "Did you eat? Your BP medicine is due now."
    │  (Not just generic "Take medicine")
    │
    ├─ Sends notification with:
    │  ✓ Sound (customizable)
    │  ✓ Haptic feedback (vibration)
    │  ✓ Visual notification badge
    │
    └─ Notification appears on home screen
       
USER RESPONSE:
    │
    ├─ Option 1: "✓ Took It"
    │  └─ Logged immediately at that timestamp
    │     Adherence score: 23/25 = 92%
    │
    ├─ Option 2: "⏱ Remind Later"
    │  └─ Reschedules notification
    │     for +15 minutes
    │
    └─ Option 3: "✕ Skip"
       └─ Logs as skipped
          Adherence score: 22/25 = 88%

DATA LOGGING:
    │
    ├─ Time taken
    ├─ Whether on-time or late
    ├─ User response type
    ├─ Adherence score calculated
    │
    ├─ Synced to Hive (local)
    └─ Synced to Firebase (backend)

ADHERENCE ANALYTICS:
    │
    ├─ Dashboard shows: "Your adherence: 92%"
    ├─ Weekly/Monthly trends
    ├─ Doctor can see adherence history
    │
    └─ AI learns patterns
       (e.g., "User always skips evening dose")
       └─ Adjust reminder time/message
```

### Technical Stack

- **Scheduling**: Flutter WorkManager (background tasks)
- **Notifications**: flutter_local_notifications + Firebase Cloud Messaging
- **Context Data**: Device sensors + app events
- **AI Logic**: Gemini API for smart message generation
- **Storage**: Hive (local) + Firebase (cloud)

---

## 5. AI Chat (Ask AI Doctor) Workflow

### Conversational AI with Health Context

```
USER INPUT:
    │
    ├─ Option 1: Voice Input
    │  └─ User taps 🎤, speaks question
    │     "Why is my BP high?"
    │
    └─ Option 2: Text Input
       └─ User types in chat field

PROCESSING:
    │
    ├─ If voice: Convert to text
    │  using Speech-to-Text API
    │
    └─ Gather context:
       • User's medical history
       • Current medications
       • Recent vital signs
       • Previous chat history

SEND TO GEMINI:
    │
    ├─ System prompt: "You are a healthcare assistant..."
    ├─ User message: "Why is my BP high?"
    ├─ Context: 
    │  Medical history: Hypertension, Diabetes
    │  Medicines: Aspirin 1x2, Metformin 1x
    │  Recent BP: 140/90 (high)
    │
    └─ Request Gemini API

GEMINI GENERATES RESPONSE:
    │
    ├─ Analyzes using medical knowledge
    ├─ Considers user's specific health data
    ├─ Generates empathetic response:
    │  "High BP can be due to stress, salt, exercise...
    │   You should: 1) Reduce salt 2) Exercise 30 mins..."
    │
    └─ Includes safety disclaimer:
       "Ask your doctor if it stays high"

DISPLAY RESPONSE:
    │
    ├─ Response appears in chat bubble
    │  (typed animation for UX)
    │
    ├─ Suggested follow-ups:
    │  • "What foods reduce BP?"
    │  • "How much exercise should I do?"
    │  • "Should I increase medicine dose?"
    │
    └─ Actions:
       [Share with doctor] [Save] [Ask more]

SEVERITY DETECTION:
    │
    ├─ If response mentions serious condition
    │  (chest pain, stroke symptoms, etc.)
    │
    └─ Suggest: "Schedule urgent appointment
       with your doctor"
       └─ One-tap appointment booking

CONVERSATION MEMORY:
    │
    ├─ All messages stored locally
    ├─ Synced to Firebase for continuity
    │
    └─ Doctor can review patient's AI chats
       in patient detail screen
```

### Technical Stack

- **Speech-to-Text**: Google Speech Recognition API
- **AI Model**: Gemini 1.5 Flash (via google_generative_ai package)
- **Context Retrieval**: Riverpod providers (instant access)
- **Streaming**: Stream responses for real-time typing effect
- **Storage**: Hive (local) + Firebase (cloud)
- **Safety**: Custom prompts with safety guardrails

---

## 6. Prescription Scanning Workflow

### OCR to Medicine Database

```
CAPTURE PHASE:
    │
    ├─ User taps "Scan Prescription"
    ├─ Opens camera with guidance overlay
    │  ("Frame prescription in rectangle")
    │
    └─ Captures photo

OCR PROCESSING:
    │
    ├─ Image sent to Google ML Kit
    │  (google_mlkit_text_recognition)
    │
    ├─ ML Kit extracts all visible text:
    │  "Dr. Sharma prescribes:
    │   Aspirin 1 tablet twice daily for 7 days
    │   Metformin 500mg once daily
    │   Atorvastatin 10mg at night"
    │
    └─ Raw text extracted

PARSING PHASE:
    │
    ├─ AI parses extracted text
    │  using regex + NLP:
    │  
    │  1. Find medicine names
    │     ✓ Aspirin, Metformin, Atorvastatin
    │  
    │  2. Extract dose
    │     ✓ 1 tablet, 500mg, 10mg
    │  
    │  3. Get frequency
    │     ✓ 2x daily, 1x daily, at night
    │  
    │  4. Duration
    │     ✓ 7 days
    │
    └─ Validate against medicine database
       (Check: Is "Aspirin" a real medicine?)

DRUG INTERACTION CHECK:
    │
    ├─ Get user's current medicines:
    │  • Already takes: Aspirin, Atorvastatin
    │  • New prescription: Aspirin, Metformin, Atorvastatin
    │
    ├─ Check interaction database:
    │  Aspirin + Atorvastatin = OK ✓
    │  Metformin + Aspirin = CAUTION ⚠️
    │  Metformin + Atorvastatin = OK ✓
    │
    └─ Flag warnings:
       "⚠️ Aspirin may interact with your
        blood thinner. Discuss with doctor."

DISPLAY RESULTS:
    │
    ├─ Show parsed medicines:
    │  ☑ Aspirin 1 tablet 2x daily (7 days)
    │  ☑ Metformin 500mg 1x daily
    │  ☑ Atorvastatin 10mg at night
    │
    ├─ Show any warnings:
    │  ⚠️ 1 interaction detected
    │
    └─ Actions:
       [✓ Add to Medicines] [Edit] [Discard]

SAVE TO PROFILE:
    │
    ├─ User confirms → medicines saved
    ├─ Stored in Hive locally
    ├─ Synced to Firebase
    │
    └─ Reminders scheduled automatically
       for new medicines
```

### Technical Stack

- **Camera**: flutter camera plugin
- **OCR**: Google ML Kit Text Recognition
- **Parsing**: Regex + custom NLP (medicine database lookup)
- **Interaction DB**: Local SQLite or Hive with known interactions
- **Storage**: Hive + Firebase

---

## 7. State Management with Riverpod

### How State Flows Through Providers

```
SCENARIO: User takes medicine (marks adherence)

1. USER ACTION:
   └─ Taps "✓ Took It" button
      └─ Widget calls: ref.read(medicineProvider.notifier)
         .markAsTaken(medicineId)

2. PROVIDER METHOD:
   └─ MedicineNotifier.markAsTaken():
      ├─ Update local state (in-memory)
      │  state = state.copyWith(
      │    medicines: [...],
      │    adherenceScore: 92%
      │  )
      │
      ├─ Call API Service
      │  await apiService.recordAdherence(medicineId)
      │
      └─ Wait for response
         ├─ Success: state fully synced
         └─ Error: Revert local change, show error

3. SERVICE LAYER (API Call):
   └─ POST /medicines/{id}/adherence
      ├─ Body: { timestamp: now, action: "took" }
      └─ Returns: { medicine: ..., adherence: 92% }

4. DATA SOURCE (Backend):
   └─ Firebase stores adherence log
      └─ Calculates new adherence score

5. RESPONSE HANDLING:
   └─ Provider receives updated data
      └─ Notifies all listeners

6. UI REBUILD (Automatic):
   └─ MedicinesScreen watches medicineProvider
      └─ Rebuilds when state changes
         └─ Shows: "✓ Aspirin (taken at 8:02 AM)"
            
   └─ DashboardScreen watches adherenceProvider
      └─ Rebuilds when state changes
         └─ Shows: "Adherence: 92% (Excellent!)"
         
   └─ Any other screen watching medicineProvider
      └─ Also automatically updates
      
7. LOCAL CACHE:
   └─ StorageService caches data
      ├─ Hive database (for medicines, appointments)
      └─ SharedPreferences (for auth tokens, settings)
      
      → Enables offline access
      → Syncs when connection restored
```

### Provider Hierarchy

```
rootProvider
├── authProvider (user authentication state)
├── userProvider (current user data)
├── appointmentProvider (upcoming appointments)
├── medicineProvider (user's medicines)
├── healthDataProvider (vitals, BP, sugar)
├── chatProvider (AI chat history)
├── adherenceProvider (derived from medicineProvider)
│   └─ Calculates adherence percentage
├── notificationProvider (pending notifications)
└── settingsProvider (user preferences)

Each provider:
• Has local state (what's in memory)
• Can fetch from API (apiServiceProvider)
• Can read from cache (storageServiceProvider)
• Can depend on other providers
• Notifies listeners when state changes
```

---

## 8. Real-Time Features

### Notifications & Alerts

```
APPOINTMENT REMINDER:
Time: 2 hours before appointment
    │
    ├─ Local notification scheduled at install
    ├─ Firebase Cloud Messaging (FCM) as backup
    │
    └─ Notification shown:
       "Your appointment with Dr. Sharma
        in 2 hours at 2:00 PM"
       [Open] [Reschedule]

MEDICATION REMINDER:
Time: Scheduled daily (8 AM, 8 PM, etc.)
    │
    ├─ Background job (WorkManager)
    ├─ Gathers context (did user eat, etc.)
    │
    └─ Smart notification shown:
       "Did you eat? Your BP medicine is due now."
       [Took it] [Remind Later] [Skip]

URGENT ALERTS:
When AI detects critical issue
    │
    ├─ High-priority notification
    ├─ Sound + haptic feedback
    │
    └─ "⚠️ Your BP is critically high (180/120)
        Call doctor immediately"
        [Call Doctor] [OK]
```

---

## 9. Offline Support

### How App Works Without Internet

```
USER OPENS APP:
    │
    ├─ Check internet connection
    │
    ├─ If ONLINE:
    │  ├─ Fetch fresh data from Firebase
    │  ├─ Update local cache (Hive)
    │  └─ Show current data
    │
    └─ If OFFLINE:
       ├─ Load data from local cache
       │  (medicines, appointments, history)
       │
       ├─ Show cached data:
       │  ✓ Medicines list (works!)
       │  ✓ Vital signs history (works!)
       │  ✓ Appointment info (works!)
       │  ✓ Chat history (works!)
       │
       ├─ Disabled features:
       │  ✗ Book new appointment
       │  ✗ Live video call
       │  ✗ Ask AI doctor
       │  ✗ Scan prescription
       │
       └─ Queue actions for sync:
          • Mark medicine taken → synced when online
          • Add notes → synced when online
          • Update settings → synced when online

RECONNECTION:
    │
    ├─ Detect internet restored
    ├─ Sync queued actions
    ├─ Fetch latest data
    │
    └─ All features restored
```

### Caching Strategy

```
Local Cache (Hive):
├── Medicines
│   └─ Persists across app closes
├── Appointments
│   └─ Cached for quick access
├── Vital Signs
│   └─ Recent health data
├── Chat Messages
│   └─ Chat history for offline review
└── User Profile
    └─ Basic profile info

Cache Invalidation:
├─ Manual refresh (pull-to-refresh)
├─ Time-based (cache for 1 hour)
├─ Event-based (when user adds medicine)
└─ Manual clear (in settings)
```

---

## 10. Summary: Data Journey Examples

### Example 1: User Takes Medicine

```
1. User taps "Took It" on reminder
2. medicineProvider.markAsTaken() called
3. Local state updated instantly
4. API call: POST /medicines/{id}/adherence
5. Backend records adherence log
6. Returns updated adherence score (92%)
7. Hive cache updated
8. MedicinesScreen rebuilds → shows checkmark ✓
9. DashboardScreen rebuilds → shows score 92%
10. Both users and doctors see the update
```

**Time**: ~500ms (feels instant)
**Offline**: Queued, synced when online

---

### Example 2: Live Appointment

```
1. Patient taps "Join Call"
2. Request token from Firebase
3. Token received, joins Agora channel
4. Doctor joins same channel
5. Video/audio streams established
6. Patient speaks in Hindi
7. Gemini Live translates real-time
8. Doctor hears in English
9. Doctor types prescription
10. AI checks interactions
11. Prescription appears on patient screen
12. Call ends, saved to Firebase
13. Both see: "Appointment completed ✓"
```

**Latency**: ~100-200ms (real-time)
**Bandwidth**: High (video stream)
**Offline**: Not possible (requires live connection)

---

### Example 3: Scan Prescription

```
1. User taps "Scan Prescription"
2. Opens camera, captures image
3. Image sent to ML Kit OCR
4. Text extracted: "Aspirin 1 tablet 2x daily"
5. Parsed into medicine format
6. Checked against current medicines
7. Interaction check: No interactions found ✓
8. User sees parsed result
9. Confirms → saved to Hive
10. Background sync → uploaded to Firebase
11. Reminder scheduled automatically
```

**Time**: ~2-3 seconds
**Accuracy**: ~95% (depends on image quality)
**Offline**: OCR works locally, sync queued

---

## 10. Key Takeaways

### How Everything Works Together

1. **UI → Providers → Services → APIs → Database → Cache → UI** (Reactive Loop)

2. **Each screen watches multiple providers** - when data changes, screen updates automatically

3. **Riverpod handles state** - no need for setState or complex bloc patterns

4. **Firebase + Hive** - cloud data + local cache = offline support

5. **Background jobs** - reminders work even when app is closed

6. **Real-time features** - Agora for video, Gemini for AI, FCM for notifications

7. **One source of truth** - if user data changes, ALL screens reflect it instantly

---

## Architecture Principles

✓ **Reactive**: Changes propagate automatically
✓ **Scalable**: Easy to add new features/providers
✓ **Offline-first**: Cache everything, sync when online
✓ **User-centric**: Smart AI features (context-aware reminders, translation, etc.)
✓ **Real-time**: Live video, instant notifications, streaming AI
✓ **Secure**: Auth tokens, encrypted data, secure APIs