# CareConnect Flutter - Developer Quick Start Guide

## Project Setup

### 1. Create Flutter Project
```bash
flutter create careconnect
cd careconnect
```

### 2. Update pubspec.yaml
```yaml
name: careconnect
description: AI-powered healthcare companion app

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.0.0
  riverpod_annotation: ^2.0.0

  # Navigation
  go_router: ^10.0.0

  # UI Components
  flutter_staggered_grid_view: ^0.7.0
  shimmer: ^3.0.0
  google_fonts: ^5.0.0

  # Video & Real-time
  agora_rtc_engine: ^6.0.0
  agora_token_builder: ^1.1.0
  permission_handler: ^11.4.0

  # Camera & Scanning
  camera: ^0.10.5
  google_mlkit_text_recognition: ^0.11.0

  # Charts & Data Visualization
  fl_chart: ^0.64.0
  syncfusion_flutter_charts: ^23.0.0

  # API & HTTP
  dio: ^5.1.1
  retrofit: ^4.0.0

  # Database & Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.1.1

  # Notifications
  firebase_core: ^24.0.0
  firebase_messaging: ^14.0.0
  flutter_local_notifications: ^17.1.1

  # AI Integration
  google_generative_ai: ^0.3.0

  # Utilities
  intl: ^0.19.0
  intl_phone_number_input: ^0.7.0
  get_it: ^7.5.0
  logger: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  hive_generator: ^2.0.0
  riverpod_generator: ^2.0.0
  retrofit_generator: ^8.0.0
```

### 3. Install Dependencies
```bash
flutter pub get
flutter pub run build_runner build
```

---

## Project Structure Best Practices

```
lib/
├── main.dart                          # App entry point
│
├── config/
│   ├── theme/
│   │   ├── app_theme.dart            # Theme configuration
│   │   ├── app_colors.dart           # Color constants
│   │   ├── app_spacing.dart          # Spacing system
│   │   └── app_typography.dart       # Text styles
│   ├── constants/
│   │   ├── app_constants.dart        # App-wide constants
│   │   └── api_endpoints.dart        # API URLs
│   └── routes/
│       └── app_router.dart           # Go Router configuration
│
├── core/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── appointment_model.dart
│   │   ├── medicine_model.dart
│   │   ├── vital_sign_model.dart
│   │   └── chat_message_model.dart
│   ├── services/
│   │   ├── api_service.dart          # HTTP client (Dio)
│   │   ├── firebase_service.dart
│   │   ├── local_storage_service.dart # Hive
│   │   ├── notification_service.dart
│   │   ├── ai_service.dart           # Gemini integration
│   │   └── video_call_service.dart   # Agora
│   └── exceptions/
│       └── app_exceptions.dart
│
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── widgets/
│   │
│   ├── home/
│   │   ├── screens/
│   │   │   └── dashboard_screen.dart
│   │   ├── providers/
│   │   │   └── dashboard_provider.dart
│   │   └── widgets/
│   │       ├── health_summary_card.dart
│   │       ├── appointment_widget.dart
│   │       ├── reminder_widget.dart
│   │       └── ai_assistant_widget.dart
│   │
│   ├── appointments/
│   │   ├── screens/
│   │   │   ├── appointments_screen.dart
│   │   │   ├── booking_screen.dart
│   │   │   └── live_appointment_screen.dart
│   │   ├── providers/
│   │   │   └── appointment_provider.dart
│   │   └── widgets/
│   │
│   ├── medicines/
│   │   ├── screens/
│   │   │   ├── medicines_screen.dart
│   │   │   ├── medicine_detail_screen.dart
│   │   │   └── scan_prescription_screen.dart
│   │   ├── providers/
│   │   │   └── medicine_provider.dart
│   │   └── widgets/
│   │
│   ├── health_trends/
│   │   ├── screens/
│   │   │   └── trends_screen.dart
│   │   ├── providers/
│   │   │   └── trends_provider.dart
│   │   └── widgets/
│   │
│   ├── ai_chat/
│   │   ├── screens/
│   │   │   └── chat_screen.dart
│   │   ├── providers/
│   │   │   └── chat_provider.dart
│   │   └── widgets/
│   │       ├── chat_message_bubble.dart
│   │       └── voice_input_widget.dart
│   │
│   └── profile/
│       ├── screens/
│       │   ├── profile_screen.dart
│       │   └── settings_screen.dart
│       ├── providers/
│       │   └── profile_provider.dart
│       └── widgets/
│
├── shared/
│   ├── widgets/
│   │   ├── custom_app_bar.dart
│   │   ├── custom_bottom_nav.dart
│   │   ├── loading_skeleton.dart
│   │   ├── health_status_badge.dart
│   │   ├── custom_button.dart
│   │   └── error_widget.dart
│   └── extensions/
│       ├── string_extensions.dart
│       ├── date_time_extensions.dart
│       └── widget_extensions.dart
│
└── utils/
    ├── formatters.dart               # Date, number formatting
    ├── validators.dart               # Form validation
    ├── logger.dart                   # Logging utility
    └── device_utils.dart             # Device info helpers
```

---

## Key Implementation Patterns

### 1. State Management with Riverpod

```dart
// Define providers
final userProvider = FutureProvider.autoDispose<User>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getUser();
});

final medicinesProvider = StateNotifierProvider.autoDispose<
    MedicineNotifier,
    AsyncValue<List<Medicine>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MedicineNotifier(apiService);
});

// Use in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider);

    return medicines.when(
      data: (data) => ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) => Text(data[index].name),
      ),
      loading: () => LoadingSkeleton(),
      error: (err, stack) => ErrorWidget(error: err),
    );
  }
}
```

### 2. Navigation with Go Router

```dart
// config/routes/app_router.dart
final goRouterProvider = Provider((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      if (!authState.isAuthenticated) return '/login';
      if (state.location == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => DashboardScreen(),
        routes: [
          GoRoute(
            path: 'appointments',
            builder: (context, state) => AppointmentsScreen(),
            routes: [
              GoRoute(
                path: 'live/:appointmentId',
                builder: (context, state) {
                  final id = state.pathParameters['appointmentId']!;
                  return LiveAppointmentScreen(appointmentId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'medicines',
            builder: (context, state) => MedicinesScreen(),
          ),
        ],
      ),
    ],
  );
});

// Usage
context.go('/appointments');
context.goNamed('live', pathParameters: {'appointmentId': '123'});
```

### 3. API Service with Dio & Retrofit

```dart
// core/services/api_service.dart
import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';

part 'api_service.g.dart';

@RestApi(baseUrl: "https://api.careconnect.com/v1")
abstract class ApiService {
  factory ApiService(Dio dio) = _ApiService;

  @GET('/user/profile')
  Future<User> getUser();

  @GET('/medicines')
  Future<List<Medicine>> getMedicines();

  @POST('/appointments')
  Future<Appointment> bookAppointment(@Body() Appointment appointment);

  @GET('/appointments/{id}/token')
  Future<String> getVideoCallToken(@Path() String id);

  @POST('/chat/ask')
  Future<ChatResponse> askAI(@Body() ChatMessage message);
}

// Setup in service provider
final apiServiceProvider = Provider((ref) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = ref.watch(authTokenProvider);
        options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          ref.read(authProvider.notifier).logout();
        }
        return handler.next(error);
      },
    ),
  );
  return ApiService(dio);
});
```

### 4. Real-time Video Consultation with Agora

```dart
// core/services/video_call_service.dart
class VideoCallService {
  late RtcEngine _engine;

  Future<void> initializeAndJoinChannel({
    required String appId,
    required String token,
    required String channelName,
  }) async {
    _engine = createAgoraRtcEngine();
    
    await _engine.initialize(RtcEngineContext(appId: appId));
    await _engine.enableVideo();
    
    // Set up event callbacks
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Joined channel: ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('User joined: $remoteUid');
        },
      ),
    );

    // Join channel
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const RtcChannelMediaOptions(),
    );
  }

  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void enableMicrophone(bool enable) {
    _engine.enableAudio();
  }
}
```

### 5. AI Chat Integration with Gemini

```dart
// core/services/ai_service.dart
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  late final GenerativeModel _model;

  AIService({required String apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.text(
        '''You are a helpful healthcare assistant named CareConnect. 
        You provide health information and reminders based on user's medical history.
        IMPORTANT: Always remind users to consult their doctor for serious concerns.
        Be empathetic and clear in your responses.'''
      ),
    );
  }

  Future<String> chat(String userMessage, {List<String>? context}) async {
    final messages = [
      if (context != null)
        for (final msg in context)
          Content.text(msg),
      Content.text(userMessage),
    ];

    try {
      final response = await _model.generateContent(messages);
      return response.text ?? 'Unable to respond';
    } catch (e) {
      return 'Error: Please try again';
    }
  }

  // Stream responses for real-time typing effect
  Stream<String> chatStream(String userMessage) {
    return _model
        .generateContentStream([Content.text(userMessage)])
        .asyncMap((event) => event.text ?? '');
  }
}
```

### 6. Local Storage with Hive

```dart
// core/services/local_storage_service.dart
@HiveType(typeId: 0)
class MedicineLocalModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String dose;

  // ... other fields
}

class LocalStorageService {
  static const medicinesBoxKey = 'medicines';
  
  Future<void> saveMedicines(List<MedicineLocalModel> medicines) async {
    final box = await Hive.openBox<MedicineLocalModel>(medicinesBoxKey);
    await box.clear();
    await box.addAll(medicines);
  }

  Future<List<MedicineLocalModel>> getMedicines() async {
    final box = await Hive.openBox<MedicineLocalModel>(medicinesBoxKey);
    return box.values.toList();
  }
}
```

### 7. Prescription Scanning with ML Kit

```dart
// features/medicines/screens/scan_prescription_screen.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanPrescriptionScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ScanPrescriptionScreen> createState() =>
      _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState
    extends ConsumerState<ScanPrescriptionScreen> {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> _scanImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract medicine information from text
      final medicines = _parseMedicineInfo(recognizedText.text);

      // Save to provider
      ref.read(medicineProvider.notifier).addFromScan(medicines);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Prescription scanned successfully')),
      );

      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan: $e')),
      );
    }
  }

  List<Medicine> _parseMedicineInfo(String text) {
    // Use regex or AI to extract medicine details
    // This is a simplified example
    final medicines = <Medicine>[];
    final lines = text.split('\n');

    for (final line in lines) {
      if (line.contains('mg') || line.contains('tablet')) {
        // Extract medicine info
      }
    }

    return medicines;
  }
}
```

### 8. Push Notifications Setup

```dart
// core/services/notification_service.dart
class NotificationService {
  static final _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Firebase messaging
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static Future<void> showMedicationReminder({
    required String medicineName,
    required String dosage,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'Medication Reminders',
      channelDescription: 'Reminders for medications',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      '💊 Time for your medicine',
      '$medicineName - $dosage',
      notificationDetails,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    // Handle notification received while app is in foreground
  }
}
```

---

## UI Best Practices for CareConnect

### 1. Loading States
```dart
// Use skeleton screens instead of spinners
medicine.when(
  data: (medicine) => MedicineCard(medicine: medicine),
  loading: () => SkeletonMedicineCard(),  // Not CircularProgressIndicator
  error: (err, _) => ErrorPlaceholder(error: err),
);
```

### 2. Health Data Visualization
```dart
// Use proper chart libraries
LineChart(
  LineChartData(
    gridData: FlGridData(show: false),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            return Text(DateFormat('MMM').format(
              DateTime.now().subtract(Duration(days: value.toInt())),
            ));
          },
        ),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: [
          FlSpot(0, 120),
          FlSpot(1, 125),
          FlSpot(2, 118),
        ],
        isCurved: true,
        color: AppColors.primary,
      ),
    ],
  ),
)
```

### 3. Custom Bottom Navigation
```dart
// Don't use default BottomNavigationBar - create custom for better control
CustomBottomNav(
  selectedIndex: _selectedIndex,
  onTap: (index) {
    context.go(_routes[index]);
    setState(() => _selectedIndex = index);
  },
  items: [
    BottomNavItem(icon: Icons.home, label: 'Home'),
    BottomNavItem(icon: Icons.calendar_today, label: 'Appointments'),
    // ... more items
  ],
)
```

---

## Performance Optimization

### 1. Use const Constructors
```dart
// Good
const SizedBox(height: 16);
const Padding(padding: EdgeInsets.all(16));

// Avoid
SizedBox(height: 16);  // Rebuilds every time parent rebuilds
```

### 2. Lazy Loading for Lists
```dart
ListView.builder(
  itemCount: medicines.length,
  itemBuilder: (context, index) => MedicineCard(medicine: medicines[index]),
)
```

### 3. Caching Images
```dart
Image.network(
  'https://...',
  cacheHeight: 300,
  cacheWidth: 300,
)
```

---

## Testing

### Unit Tests
```dart
test('formatBPReading should format correctly', () {
  expect(formatBPReading(120, 80), '120/80');
});

test('isMedicineTimeAlert should detect alerts', () {
  final now = DateTime.now();
  expect(isMedicineTimeAlert(now, now), true);
});
```

### Widget Tests
```dart
testWidgets('MedicineCard displays medicine name', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MedicineCard(
        medicine: Medicine(name: 'Aspirin', dose: '1 tablet'),
      ),
    ),
  );

  expect(find.text('💊 Aspirin'), findsOneWidget);
});
```

---

## Debugging & Logging

```dart
// Use logger instead of print
import 'package:logger/logger.dart';

final logger = Logger();

// In your code
logger.i('User logged in');
logger.w('Medicine adherence low');
logger.e('API error: $error', error: e, stackTrace: st);
```

---

## Firebase Integration Checklist

- [ ] Create Firebase project
- [ ] Add Android app to Firebase (SHA-1 fingerprint)
- [ ] Add iOS app to Firebase
- [ ] Download `google-services.json` (Android)
- [ ] Download `GoogleService-Info.plist` (iOS)
- [ ] Enable Firestore Database
- [ ] Set up Cloud Messaging
- [ ] Configure security rules

---

## Deployment Checklist

### Before Release
- [ ] Run `flutter test`
- [ ] Run `flutter analyze`
- [ ] Test on real devices (Android & iOS)
- [ ] Check app permissions
- [ ] Update version in `pubspec.yaml`
- [ ] Update privacy policy
- [ ] Add app icons & splash screens

### Android Release
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS Release
```bash
flutter build ios --release
```

---

## Troubleshooting Common Issues

### Issue: "Flutter: Permission denied"
**Solution**: Check AndroidManifest.xml and Info.plist for required permissions

### Issue: "Null safety errors"
**Solution**: Ensure all variables are properly initialized or marked as nullable

### Issue: "Widget build method called during build"
**Solution**: Use `Future.delayed` or `addPostFrameCallback` for navigation/state changes

### Issue: "Out of memory with images"
**Solution**: Use `cacheHeight` and `cacheWidth` with Image.network()

---

## Useful Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [Material Design 3](https://m3.material.io)
- [Firebase Flutter](https://firebase.flutter.dev)
- [Google Generative AI SDK](https://ai.google.dev/tutorials/flutter_quickstart)

---

**Happy Coding!** 🚀 Build a healthcare app that changes lives.
