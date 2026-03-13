import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/prescription_scanner_screen.dart';
import 'screens/health_trends_screen.dart';

// ============================================================================
// THEME & COLORS
// ============================================================================

class AppColors {
  static const Color primary = Color(0xFF00897B);
  static const Color secondary = Color(0xFF6C5CE7);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );
}

// ============================================================================
// APP ENTRY POINT
// ============================================================================

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareConnect',
      theme: buildAppTheme(),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================================
// MAIN SCREEN WITH BOTTOM NAVIGATION
// ============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AppointmentsScreen(),
    const MedicinesScreen(),
    const AIChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Appts'),
          BottomNavigationBarItem(icon: Icon(Icons.medication_outlined), activeIcon: Icon(Icons.medication), label: 'Meds'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), activeIcon: Icon(Icons.chat), label: 'AI Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// DASHBOARD SCREEN
// ============================================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 18 ? 'Good Afternoon' : 'Good Evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CareConnect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        backgroundColor: Colors.white, elevation: 1,
        actions: [
          Stack(children: [
            const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.notifications_outlined, color: AppColors.textPrimary)),
            Positioned(right: 10, top: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle))),
          ]),
          const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.settings_outlined, color: AppColors.textPrimary)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('$greeting, Rajesh! 👋', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 16),
            _buildHealthSummary(),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 16),
            _buildAIWidget(context),
            const SizedBox(height: 16),
            _buildMedicationReminder(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummary() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.85), AppColors.primary]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Health Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric('Blood Pressure', '120/80', 'mmHg', Icons.favorite, 'Normal'),
              Container(width: 1, height: 60, color: Colors.white.withValues(alpha: 0.3)),
              _metric('Blood Sugar', '95', 'mg/dl', Icons.water_drop, 'Good'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Last update: ${DateFormat('hh:mm a').format(DateTime.now())}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit, IconData icon, String status) {
    return Column(children: [
      Icon(icon, color: Colors.white, size: 24),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(unit, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
        child: Text('✓ $status', style: const TextStyle(fontSize: 10, color: Colors.white)),
      ),
    ]);
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.2,
      children: [
        _actionCard(Icons.calendar_today, 'Next Appointment', 'Tomorrow, 2:00 PM', null, () {}),
        _actionCard(Icons.medication, 'Active Medicines', '3 medicines', null, () {}),
        _actionCard(Icons.trending_up, 'Health Trends', 'View analytics', null, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthTrendsScreen()));
        }),
        _actionCard(Icons.document_scanner, 'Scan Prescription', 'Camera OCR', AppColors.secondary.withValues(alpha: 0.05), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrescriptionScannerScreen()));
        }),
      ],
    );
  }

  Widget _actionCard(IconData icon, String title, String subtitle, Color? bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg ?? Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildAIWidget(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to AI Chat tab
        final mainState = context.findAncestorStateOfType<_MainScreenState>();
        mainState?.setState(() => mainState._selectedIndex = 3);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.secondary),
            ),
            const SizedBox(width: 12),
            const Text('Ask AI Doctor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('● Online', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.mic_none, color: AppColors.secondary, size: 20),
              SizedBox(width: 12),
              Text('Ask your health question...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildMedicationReminder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.85), AppColors.accent]),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.medication, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Text('Time for your medicine', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
        const SizedBox(height: 10),
        Text('Aspirin • 1 tablet', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
        Text('Due at 8:00 PM', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _reminderBtn('Took it', true, context),
          _reminderBtn('Skip', false, context),
          _reminderBtn('Later', false, context),
        ]),
      ]),
    );
  }

  Widget _reminderBtn(String label, bool primary, BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(primary ? '✓ Marked as taken' : '$label selected'), duration: const Duration(seconds: 1)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary ? AppColors.accent : Colors.white)),
      ),
    );
  }
}

// ============================================================================
// APPOINTMENTS SCREEN (Placeholder)
// ============================================================================

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Appointments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), backgroundColor: Colors.white, elevation: 1),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('UPCOMING', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _appointmentCard('Dr. Sharma', 'Cardiologist', 'Tomorrow, 2:00 PM', true, context),
        const SizedBox(height: 20),
        const Text('COMPLETED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _appointmentCard('Dr. Sharma', 'Cardiologist', 'March 13, 15 mins', false, context),
        _appointmentCard('Dr. Priya', 'General Physician', 'March 10, 20 mins', false, context),
      ]),
    );
  }

  Widget _appointmentCard(String doctor, String specialty, String time, bool upcoming, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: upcoming ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (upcoming) Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: const Text('🔴 UPCOMING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
        ),
        Text('👨‍⚕️ $doctor', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(specialty, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (upcoming) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📞 Joining call...'))); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('📞 Join Call', style: TextStyle(color: Colors.white, fontSize: 13)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Reschedule', style: TextStyle(fontSize: 13)),
            )),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 16),
            const SizedBox(width: 6),
            const Text('Completed', style: TextStyle(fontSize: 12, color: AppColors.success)),
          ]),
        ],
      ]),
    );
  }
}

// ============================================================================
// MEDICINES SCREEN
// ============================================================================

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Medicines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        backgroundColor: Colors.white, elevation: 1,
        actions: [IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: () {})],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Active Medicines (3)', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _medCard('Aspirin', '1 tablet', '2x daily', '8 AM, 8 PM', 'In 15 days', null),
        _medCard('Metformin', '500mg', '1x daily', '8 AM', 'In 20 days', 'May interact with Aspirin'),
        _medCard('Atorvastatin', '10mg', '1x daily', '10 PM', 'In 25 days', null),
        const SizedBox(height: 20),
        // Scan button
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrescriptionScannerScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Scan Prescription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.trending_up, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Text('Medicine Adherence: 92%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
            Spacer(),
            Text('23/25 doses', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  Widget _medCard(String name, String dose, String freq, String time, String refill, String? warning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('💊 $name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (warning != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: const Text('⚠️ Alert', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('$dose • $freq', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text('Time: $time ⏰', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text('Refill: $refill', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        if (warning != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('⚠️ $warning', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
          ),
        ],
      ]),
    );
  }
}

// ============================================================================
// PROFILE SCREEN
// ============================================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), backgroundColor: Colors.white, elevation: 1),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Profile header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Row(children: [
            CircleAvatar(radius: 30, backgroundColor: AppColors.primary, child: Text('RK', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rajesh Kumar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('rajesh@email.com', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text('Age: 45 | Blood Type: O+', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _section('HEALTH PROFILE', [
          _tile(Icons.medical_information, 'Conditions', 'Hypertension, Diabetes Type 2'),
          _tile(Icons.warning_amber, 'Allergies', 'Penicillin'),
          _tile(Icons.local_hospital, 'Surgeries', 'None'),
        ]),
        const SizedBox(height: 16),
        _section('PREFERENCES', [
          _tile(Icons.language, 'Language', 'हिंदी (Hindi)'),
          _tile(Icons.notifications, 'Notifications', 'ON'),
          _tile(Icons.dark_mode, 'Dark Mode', 'OFF'),
        ]),
        const SizedBox(height: 16),
        _section('EMERGENCY CONTACTS', [
          _tile(Icons.person, 'Priya Kumar', 'Spouse'),
          _tile(Icons.person, 'Arun Kumar', 'Son'),
        ]),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(children: children),
      ),
    ]);
  }

  static Widget _tile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
    );
  }
}