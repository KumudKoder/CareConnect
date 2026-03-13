# CareConnect Flutter Frontend Design Document

## 1. App Overview & User Journey

**What**: AI-powered healthcare app connecting patients with doctors in real-time with translation, prescription management, and health tracking
**Who**: Patients (varied tech comfort levels, multilingual)
**Core Differentiator**: Gemini Live AI enables real-time doctor-patient communication in any language + smart health management

---

## 2. Design System

### Color Palette
```
Primary (Trust/Health): #00897B (Teal) - main brand color
Secondary (AI/Smart): #6C5CE7 (Purple) - AI features, interactive elements
Accent (Action): #FF6B6B (Coral) - CTAs, alerts, urgent items
Success: #4CAF50 (Green) - healthy status, completed tasks
Warning: #FFC107 (Amber) - medication alerts, caution
Error: #E53935 (Red) - critical alerts
Background: #F5F7FA (Light blue-gray) - app background
Surface: #FFFFFF (White) - cards, dialogs
Text Primary: #1A1A2E (Dark blue-gray)
Text Secondary: #6C757D (Medium gray)
```

### Typography
```
Headers: Poppins Bold (27px, 20px, 16px)
Subheaders: Poppins SemiBold (14px, 12px)
Body: Outfit Regular (14px, 12px)
Captions: Outfit Regular (11px, 10px)
```

### Spacing System
```
xs: 4px
sm: 8px
md: 12px
lg: 16px
xl: 24px
xxl: 32px
```

---

## 3. Key Screens & Components

### Screen 1: Dashboard/Home Screen
**Purpose**: Quick overview of health status, upcoming appointments, and AI features

```
┌─────────────────────────────────────┐
│  CareConnect          ⚙️  🔔        │
├─────────────────────────────────────┤
│  👋 "Hello, Rajesh!"                │
│  Your health status                 │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 🩹 Health Summary              ││
│  │ BP: 120/80 ✓                   ││
│  │ Sugar: 95 mg/dl ✓              ││
│  │ Last update: Today, 8:30 AM    ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐ │
│  │  📅 Next      │  │  💊 Active   │ │
│  │  Appointment │  │  Medicines   │ │
│  │  Tomorrow,   │  │  3 medicines │ │
│  │  2:00 PM     │  │  with Dr. X  │ │
│  └──────────────┘  └──────────────┘ │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │  🤖 Ask AI Doctor              ││
│  │  "Why is my BP high?"           ││
│  │  [Voice input button] 🎤        ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  📌 Smart Reminder                  │
│  💊 Time for morning medicine       │
│  [Took it] [Skip] [Later]           │
├─────────────────────────────────────┤
│ 🏥 [Schedule Appointment] [History] │
└─────────────────────────────────────┘
```

**Key Elements**:
- Greeting with patient name
- Health status cards (vital signs)
- Quick action shortcuts
- AI voice assistant widget
- Smart medication reminders
- Easy appointment booking

---

### Screen 2: Live Appointment Screen
**Purpose**: Real-time doctor-patient consultation with AI translation

```
┌─────────────────────────────────────┐
│  🔴 LIVE with Dr. Sharma  [00:14]   │
│  Appointment  [End Call]             │
├─────────────────────────────────────┤
│                                     │
│        [Doctor Video Feed]          │
│        📹 Dr. Sharma                │
│                                     │
├─────────────────────────────────────┤
│  🎤 You (Listening...)              │
│  Status: "Connected"                │
│                                     │
│  Doctor said:                       │
│  "How are you feeling today?"       │
│                                     │
│  Gemini AI translating...           │
│  [In your language]                 │
│  आप आज कैसा महसूस कर रहे हैं?    │
├─────────────────────────────────────┤
│  [🎤 Speak] [⏸️ Mute] [📝 Notes]   │
│                                     │
│  Doctor's Recommendations:          │
│  • Take BP medicine daily           │
│  • Reduce salt intake               │
│  • Exercise 30 mins daily           │
├─────────────────────────────────────┤
│  ⚠️ Drug Alert                      │
│  "Aspirin may interact with         │
│   your current medicine"            │
│  [Discuss with doctor]              │
└─────────────────────────────────────┘
```

**Key Elements**:
- Live video with doctor
- Real-time AI translation display
- Voice/mute controls
- Live prescription/notes
- Drug interaction warnings
- Call duration
- End call option

---

### Screen 3: Prescription Scanning & Management
**Purpose**: Digitize and track medications

```
┌─────────────────────────────────────┐
│  My Medicines          [➕ Add New]  │
├─────────────────────────────────────┤
│  Active Medicines (3)               │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 💊 Aspirin                      ││
│  │ Dose: 1 tablet | Frequency: 2x  ││
│  │ Time: 8 AM, 8 PM ⏰             ││
│  │ Refill: Due in 15 days          ││
│  │                                 ││
│  │ Next dose: 8:00 PM (in 2 hrs)   ││
│  │ [✓ Took] [Skip] [Remind me]     ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 💊 Metformin                    ││
│  │ Dose: 500mg | Frequency: 1x     ││
│  │ Time: 8 AM ⏰                   ││
│  │ ⚠️ Interacts with: Aspirin      ││
│  │                                 ││
│  │ [Take note] [More info]         ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  📸 Scan Prescription                │
│  [Camera icon]                      │
│  Upload photo of prescription       │
├─────────────────────────────────────┤
│  📊 Medicine Adherence: 92%         │
│  (Took on time: 23/25 doses)        │
└─────────────────────────────────────┘
```

**Key Elements**:
- Active medicines list
- Clear dosage & timing
- Refill reminders
- Medication adherence tracking
- Drug interaction warnings
- Camera to scan prescriptions
- Consistency indicators

---

### Screen 4: Health Trends & Analytics
**Purpose**: Visualize health data over time

```
┌─────────────────────────────────────┐
│  Health Trends         [📊] [📋]    │
├─────────────────────────────────────┤
│  📈 Blood Pressure Trend            │
│     Last 30 days                    │
│                                     │
│     180 ┤                           │
│     160 ┤        ╭──╮              │
│     140 ┤   ╭─╮  │  │  ╭─╮        │
│     120 ┤  ╭─┘ ╰─╮╰──╯ ╰─╯       │
│     100 ┤ ╭┘                      │
│      80 ┤─┘                        │
│        └────────────────────────   │
│      Mar 15        Mar 30          │
│      Status: ✓ Normal              │
│      Trend: ↗️ Slightly rising     │
│      [Consult Doctor]              │
├─────────────────────────────────────┤
│  🩸 Blood Sugar Trend               │
│     Last 7 days                     │
│     Status: ✓ Controlled            │
│     Average: 110 mg/dl              │
│     [See Details]                   │
├─────────────────────────────────────┤
│  ⚖️  Weight Trend                   │
│     Last 60 days                    │
│     Current: 75 kg                  │
│     Change: -2 kg ⬇️ Good!         │
├─────────────────────────────────────┤
│  [Export Data] [Share with Doctor]  │
└─────────────────────────────────────┘
```

**Key Elements**:
- Line charts for vital trends
- Time period filters (7d, 30d, 90d)
- Status indicators (normal/warning/critical)
- Trend arrows (up/down/stable)
- Data export capability
- Doctor sharing feature
- Clear, readable visualizations

---

### Screen 5: AI Voice Assistant Chat
**Purpose**: Answer patient questions in real-time

```
┌─────────────────────────────────────┐
│  Ask AI Doctor          [⚙️]        │
│  "Your healthcare companion"        │
├─────────────────────────────────────┤
│                                     │
│  Patient: "Why is my BP high?"      │
│  📌 10:32 AM                        │
│                                     │
│  AI Doctor:                         │
│  "High BP can be caused by stress,  │
│   salt intake, or lack of exercise. │
│   You should:                       │
│   1. Reduce salt in your diet       │
│   2. Exercise 30 mins daily         │
│   3. Monitor stress levels          │
│   4. Check with your doctor if it   │
│      stays high"                    │
│  📌 10:32 AM                        │
│                                     │
│  Patient: "Should I increase...     │
│           my medicine?"             │
│  📌 10:33 AM                        │
│                                     │
│  AI Doctor:                         │
│  "Please discuss with your doctor   │
│   before changing medicine dose. I  │
│   see you have an appointment       │
│   tomorrow at 2 PM - ask them then" │
│  📌 10:33 AM    [More details]      │
│                                     │
├─────────────────────────────────────┤
│  [🎤 Tap to speak]                  │
│  Or type your question...           │
│  [                              ]   │
│                        [Send] [🎙️] │
├─────────────────────────────────────┤
│  💡 Suggested questions:            │
│  • What does my medicine do?        │
│  • Is my BP normal?                 │
│  • When should I exercise?          │
└─────────────────────────────────────┘
```

**Key Elements**:
- Chat-style conversation
- Voice input button
- Text input option
- Timestamp for messages
- Contextual suggestions
- Links to appointments
- Settings icon for preferences
- Clear distinction between user/AI

---

### Screen 6: Appointments & Doctor List
**Purpose**: Schedule and manage consultations

```
┌─────────────────────────────────────┐
│  Appointments          [📅] [➕]    │
├─────────────────────────────────────┤
│  UPCOMING (1)                       │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 🔴 LIVE CONSULTATION             ││
│  │ Dr. Sharma (Cardiologist)       ││
│  │ Tomorrow, March 20 at 2:00 PM   ││
│  │                                 ││
│  │ [📞 Join Call] [📝 Reschedule]  ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  COMPLETED (5)                      │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ ✓ March 13 - Dr. Sharma         ││
│  │ Duration: 15 mins               ││
│  │ Status: Prescription issued      ││
│  │ [View Notes] [View Prescription] ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  DOCTORS (2 Favorites)              │
├─────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐ │
│  │ 👨‍⚕️ Dr. Sharma │  │ 👩‍⚕️ Dr. Priya  │ │
│  │ Cardiologist │  │ GP            │ │
│  │ ⭐ 4.8/5     │  │ ⭐ 4.9/5      │ │
│  │ [Book]       │  │ [Book]        │ │
│  └──────────────┘  └──────────────┘ │
├─────────────────────────────────────┤
│  📅 QUICK BOOK                      │
│  [Today] [Tomorrow] [This Week]     │
│  Time: [Select time]                │
│  [Book Appointment]                 │
└─────────────────────────────────────┘
```

**Key Elements**:
- Upcoming appointments with countdown
- Quick action buttons
- Completed appointment history
- Favorite doctor list with ratings
- Quick booking interface
- Doctor specialization info
- Rescheduling option

---

### Screen 7: Settings & Profile
**Purpose**: Personalization and account management

```
┌─────────────────────────────────────┐
│  Settings              [👤]         │
├─────────────────────────────────────┤
│  PROFILE                            │
├─────────────────────────────────────┤
│  👤 Rajesh Kumar                    │
│  📧 rajesh@email.com                │
│  📱 +91-XXXXXXXXXX                  │
│  🎂 Age: 45 | Blood Type: O+        │
│  [Edit Profile]                     │
├─────────────────────────────────────┤
│  PREFERENCES                        │
├─────────────────────────────────────┤
│  🌐 Language: हिंदी (Hindi) ↓       │
│  🔔 Notifications: ON               │
│  📍 Location: Grant yourself privacy │
│  🌙 Dark Mode: OFF                  │
│  ♿ Accessibility: Large text: ON    │
├─────────────────────────────────────┤
│  HEALTH PROFILE                     │
├─────────────────────────────────────┤
│  Chronic Conditions:                │
│  • Hypertension                     │
│  • Diabetes Type 2                  │
│  Allergies: Penicillin              │
│  Previous Surgeries: None           │
│  [Edit Medical History]             │
├─────────────────────────────────────┤
│  EMERGENCY CONTACT                  │
├─────────────────────────────────────┤
│  👨‍👩‍👧 Family Members                   │
│  • Priya Kumar (Spouse)             │
│  • Arun Kumar (Son)                 │
│  [Add/Edit]                         │
├─────────────────────────────────────┤
│  ACCOUNT                            │
├─────────────────────────────────────┤
│  [Privacy Policy] [Terms of Service]│
│  [Data Export] [Delete Account]     │
│  [Logout]                           │
└─────────────────────────────────────┘
```

**Key Elements**:
- User profile summary
- Language selection
- Accessibility settings
- Dark/light mode toggle
- Medical history management
- Emergency contacts
- Privacy & data controls
- Account management

---

## 4. Navigation Structure

### Bottom Navigation (Always Visible)
```
┌─────────────────────────────────────┐
│ 🏠   📅   💊   💬   👤             │
│ Home Appt Meds Chat Profile         │
└─────────────────────────────────────┘
```

- **Home**: Dashboard + Quick actions
- **Appointments**: Schedule & history
- **Medicines**: Track & manage medications
- **Chat**: AI Assistant + Messages
- **Profile**: Settings & personal info

---

## 5. Key Features & Interactions

### Feature 1: Medication Reminders
```
⏰ Smart Reminder System:
- Time-based: Daily medication reminders
- Context-aware: "Did you eat? Your BP medicine is due."
- Flexible snooze: Remind in 5, 15, 30 mins
- Adherence tracking: Show consistency score
- Rich notifications: Custom sounds, vibration
```

### Feature 2: AI Voice Assistant
```
🤖 Ask AI Doctor:
- Voice input (tap and hold)
- Natural language understanding
- Health context awareness
- Multi-language responses
- Follow-up suggestions
- Doctor escalation if needed
```

### Feature 3: Prescription Scanning
```
📸 Smart Prescription Reader:
- Camera integration
- OCR for medicine name/dose
- Auto-fill medication list
- Drug interaction detection
- Refill reminders
```

### Feature 4: Health Data Visualization
```
📊 Trends & Analytics:
- Line charts for vital trends
- Time period filtering
- Status indicators (⚠️ alerts)
- Historical comparison
- Export/share with doctor
```

### Feature 5: Real-time Consultation
```
🔴 Live Appointment:
- Video + audio with doctor
- AI real-time translation
- Live prescription upload
- Drug interaction alerts
- Call recording (with consent)
- Post-appointment summary
```

---

## 6. Micro-interactions & Animations

### Loading States
```
✓ Skeleton screens instead of spinners
✓ Smooth fade-in of content
✓ Subtle pulse animation for "loading"
```

### Button Interactions
```
✓ Ripple effect on tap
✓ Scale animation on long press
✓ Color change feedback
✓ Success checkmark animation
```

### Page Transitions
```
✓ Fade transition between pages
✓ Slide-up for modals
✓ Slide-in from right for new screens
✓ Bounce effect for alerts
```

### Reminder Notifications
```
✓ Slide-down from top
✓ Auto-dismiss after 5 seconds
✓ Swipe to dismiss
✓ Sound + haptic feedback
```

---

## 7. Accessibility Considerations

### For Varied User Comfort Levels
```
✓ Large touch targets (min 48dp)
✓ Clear, simple language
✓ High contrast mode option
✓ Dark mode support
✓ Text size adjustments (110%, 125%, 150%)
✓ Voice input everywhere
✓ Screen reader support
✓ Multi-language support (built-in)
```

### Healthcare Specific
```
✓ Clear unit labels (mg/dl, mmHg)
✓ Status indicators (colors + text)
✓ Confirmation dialogs for critical actions
✓ Undo options where possible
✓ Offline viewing of critical data
```

---

## 8. Flutter Implementation Stack

### Dependencies
```yaml
# State Management
riverpod: ^2.0.0

# UI Components
flutter_staggered_grid_view: ^0.7.0
shimmer: ^3.0.0  # Loading skeletons

# Video & Voice
agora_rtc_engine: ^6.0.0  # For live consultations
permission_handler: ^11.4.0

# Charts & Data Viz
fl_chart: ^0.64.0

# Camera & Scanning
camera: ^0.10.5
ml_kit: ^0.0.0  # For OCR of prescriptions
google_mlkit_text_recognition: ^0.0.0

# HTTP & API
dio: ^5.1.1

# Database & Storage
hive: ^2.2.3
shared_preferences: ^2.1.1

# Notifications
firebase_messaging: ^14.0.0
flutter_local_notifications: ^17.1.1

# AI Integration
google_generative_ai: ^0.1.0  # Gemini API

# Internationalization
intl: ^0.19.0
get: ^4.6.0  # For language switching

# Others
intl_phone_number_input: ^0.7.0
syncfusion_flutter_charts: ^23.0.0  # Advanced charts
```

### Folder Structure
```
lib/
├── main.dart
├── config/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_typography.dart
│   └── routes/
│       └── app_routes.dart
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── home/
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   │       ├── health_summary_card.dart
│   │       ├── appointment_widget.dart
│   │       └── reminder_widget.dart
│   ├── appointments/
│   │   ├── appointments_screen.dart
│   │   ├── booking_screen.dart
│   │   ├── live_appointment_screen.dart
│   │   └── widgets/
│   ├── medicines/
│   │   ├── medicines_screen.dart
│   │   ├── add_medicine_screen.dart
│   │   ├── scan_prescription_screen.dart
│   │   └── medicine_detail_screen.dart
│   ├── health_trends/
│   │   ├── trends_screen.dart
│   │   └── widgets/
│   │       ├── bp_trend_chart.dart
│   │       └── health_summary_chart.dart
│   ├── ai_chat/
│   │   ├── ai_chat_screen.dart
│   │   └── widgets/
│   │       ├── chat_message_bubble.dart
│   │       └── voice_input_widget.dart
│   └── profile/
│       ├── profile_screen.dart
│       └── settings_screen.dart
│
├── widgets/
│   ├── custom_app_bar.dart
│   ├── custom_bottom_nav.dart
│   ├── loading_skeleton.dart
│   ├── health_status_badge.dart
│   └── custom_button.dart
│
├── models/
│   ├── user_model.dart
│   ├── appointment_model.dart
│   ├── medicine_model.dart
│   ├── vital_sign_model.dart
│   └── chat_message_model.dart
│
├── providers/
│   ├── auth_provider.dart
│   ├── appointment_provider.dart
│   ├── medicine_provider.dart
│   ├── health_data_provider.dart
│   ├── chat_provider.dart
│   └── user_provider.dart
│
├── services/
│   ├── api_service.dart
│   ├── firebase_service.dart
│   ├── local_storage_service.dart
│   ├── notification_service.dart
│   ├── ai_service.dart  # Gemini integration
│   └── agora_service.dart  # Video call service
│
└── utils/
    ├── constants.dart
    ├── validators.dart
    ├── formatters.dart
    └── extensions.dart
```

---

## 9. Development Phases

### Phase 1: MVP (Weeks 1-4)
- ✅ Authentication (login/signup)
- ✅ Dashboard with health summary
- ✅ Appointment booking & list
- ✅ Medicine tracking with reminders
- ✅ Basic AI chat

### Phase 2: Enhanced Features (Weeks 5-8)
- ✅ Live appointment with video
- ✅ Prescription scanning with OCR
- ✅ Health trends & charts
- ✅ Drug interaction alerts
- ✅ Multi-language support

### Phase 3: Advanced Features (Weeks 9-12)
- ✅ AI voice assistant with Gemini
- ✅ Real-time translation
- ✅ Advanced analytics & reports
- ✅ Wearable device integration
- ✅ Offline mode

---

## 10. Design Tokens Quick Reference

### Elevation/Shadows
```
Low: elevation: 1.0
Medium: elevation: 4.0
High: elevation: 8.0
```

### Border Radius
```
Small: 8.0
Medium: 12.0
Large: 16.0
XLarge: 20.0
```

### Opacity
```
Subtle: 0.4
Medium: 0.6
Strong: 0.8
```

---

## 11. Key Screens Code Example

### Dashboard Widget Structure (Dart/Flutter)
```dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: CustomAppBar(title: 'CareConnect'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(healthDataProvider);
        },
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Greeting
            _buildGreeting(),
            SizedBox(height: 16),
            
            // Health Summary Card
            HealthSummaryCard(),
            SizedBox(height: 16),
            
            // Quick Actions (2-column grid)
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _QuickActionCard(
                  icon: Icons.calendar_today,
                  title: 'Next Appointment',
                  subtitle: 'Tomorrow, 2:00 PM',
                  onTap: () => GoRouter.of(context).push('/appointments'),
                ),
                _QuickActionCard(
                  icon: Icons.medication,
                  title: 'Active Medicines',
                  subtitle: '3 medicines',
                  onTap: () => GoRouter.of(context).push('/medicines'),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // AI Doctor Widget
            _AIAssistantWidget(),
            SizedBox(height: 16),
            
            // Smart Reminder
            MedicationReminderWidget(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(),
    );
  }
  
  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' :
                     hour < 18 ? 'Good Afternoon' : 'Good Evening';
    
    return Text(
      '$greeting, Rajesh! 👋',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
```

---

## Summary

**CareConnect's Frontend Philosophy:**
1. **Simple First**: Easy for any user to navigate
2. **AI-Centric**: AI features are front and center
3. **Health-Focused**: Clear health data, easy tracking
4. **Accessible**: Multi-language, multiple input methods
5. **Real-time**: Live consultation, instant reminders
6. **Trustworthy**: Clear medical information, safety warnings

Every screen should feel modern, responsive, and trustworthy—making healthcare accessible to everyone.
