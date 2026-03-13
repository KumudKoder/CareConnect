# CareConnect: Frontend Architecture & Design

## 1. UI/UX Design Language (The "Architectural" Look)

To achieve a modern, minimalist, and "architectural" feel, the design focuses on clean geometry, strong typography, purposeful whitespace, and a monochromatic or muted color palette.

- **Grid Systems and Alignment:** Treat the screen like a blueprint. Use a strict 8pt grid system. Elements should align perfectly along vertical and horizontal axes.
- **Typography:** Use a structural, clean sans-serif font like **Inter**, **SF Pro**, or **Manrope**. Use stark contrasts in font weights (e.g., very thin, large headers paired with highly readable, medium-weight body text).
- **Color Palette:** Limit the palette to 2-3 colors. Use dark charcoal or stark black for text, a sheer off-white or light gray for the background, and a single muted accent color (like sage green or slate blue) for active states.
- **Cards and Containers:** Avoid heavy drop-shadows. Use subtle 1px borders (e.g., `#E0E0E0`) or entirely flat colored surfaces to separate content. Avoid overly rounded corners; use sharp edges or a very low border radius (e.g., 4px to 8px) for a structured look.
- **Mobile-First Ergonomics:** Since this is a mobile phone app (iOS/Android), ensure all interactive elements (buttons, inputs) are at least 48x48 dp for reliable touch targets. Keep primary actions (like activating the AI) reachable within the "thumb zone" at the bottom of the screen. Utilize native mobile gestures natively (swipe to go back, pull to refresh).

## 2. Key Screens & Components

### Mobile Navigation Structure

- Maintain a clean Bottom Navigation Bar for jumping between core modules: **Home (Timeline)**, **Companion (AI)**, and **History (Documents/Prescriptions)**.

### The Home/Overview Screen

- A bold, simple greeting (e.g., "Good morning, Sarah.").
- A minimalist timeline of their health journey (past visits, current medications).
- A prominent, distraction-free "Start Visit" button to activate the AI companion.

### The "Live Companion" Screen (During Appointment)

- **Gemini Live AI Integration:** Hears both the doctor and the patient, translating the medical instructions live into the patient's native language.
- Almost entirely blank to reduce cognitive load while speaking with the doctor.
- A sleek, subtle, monochromatic waveform or glowing orb in the center to indicate the AI is listening.
- A simple transcription ticker at the bottom displaying what is being recorded and translated in real-time.

### The Prescription Scanner (Camera View) & History

- A fullscreen camera view with a sharp, grid-like bounding box (think architectural viewfinder) that reads the drug name, dose, and frequency.
- **Drug Conflict Alert:** When a new prescription is scanned, a bottom sheet slides up comparing "Current Medication" vs "New Medication", immediately highlighting interactions in a colored tag (e.g., a muted yellow warning pill).
- **Health Trend Chart:** Displays historical comparisons (e.g., Blood Pressure or Sugar levels over time) pulled from past read prescriptions.

### The "Ask AI Later" Chat Screen

- **Voice Reply:** The AI answers the patient's questions ("What did the doctor say about my BP medicine?") via Voice in the patient's native language.
- Unlike traditional bubbly chat apps (like WhatsApp), format this like a clinical logbook.
- Left-aligned text for both user and AI, separated by thick horizontal lines or distinct typographic hierarchy, making it read like an organized medical dossier.

### Smart Reminders (Background/Notification Layer)

- A context-aware notification system that sends intelligent, conversational prompts (e.g., "Did you eat? Your BP medicine is due now.").
- Powered by the schedules extracted during the Live Companion session and Prescription Scanning.

## 3. Flutter Implementation & Architecture

We follow a **Feature-First (Domain-Driven)** architecture to keep the code organized and scalable. **All data will be stored in Firebase**, allowing the AI to learn from every session over time.

### Recommended Folder Structure

```text
lib/
  ├── core/                 # App-wide UI rules, colors, routing
  │   ├── theme/            # ThemeData (Colors, Typography)
  │   └── utils/
  ├── features/
  │   ├── live_companion/   # Audio recording & waveform UI
  │   ├── prescription/     # Camera scanner & comparison logic
  │   └── chat/             # Ask AI later interface
  └── main.dart
```

### Essential Flutter Packages

- **State & Backend:** `flutter_riverpod` (state), `firebase_core`, `cloud_firestore` (storing context and history).
- **AI & Translation:** `google_generative_ai` (Gemini integration), `flutter_tts` (for the AI Voice Reply feature).
- **Routing:** `go_router` (handles deep linking and seamless navigation).
- **Typography:** `google_fonts` (access to fonts like Inter or Manrope).
- **Live Audio:** `record` and `speech_to_text` (for the clinical listening mode).
- **Scanning:** `camera` and `google_mlkit_text_recognition` (for reading prescription labels).
- **Data Visualization:** `fl_chart` (to draw the health trend charts for BP/Sugar).
- **Notifications:** `flutter_local_notifications` (for the Smart Reminders).
- **Animations:** `flutter_animate` (for subtle, smooth slide-ins and fades that feel high-end).
