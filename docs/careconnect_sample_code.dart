// ============================================================================
// CARECONNECT - FLUTTER SAMPLE IMPLEMENTATION
// Key Screens & Reusable Widgets
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ============================================================================
// 1. THEME & COLOR CONFIGURATION
// ============================================================================

class AppColors {
  static const Color primary = Color(0xFF00897B);      // Teal
  static const Color secondary = Color(0xFF6C5CE7);    // Purple
  static const Color accent = Color(0xFFFF6B6B);       // Coral
  static const Color success = Color(0xFF4CAF50);      // Green
  static const Color warning = Color(0xFFFFC107);      // Amber
  static const Color error = Color(0xFFE53935);        // Red
  static const Color background = Color(0xFFF5F7FA);   // Light blue-gray
  static const Color surface = Color(0xFFFFFFFF);      // White
  static const Color textPrimary = Color(0xFF1A1A2E);  // Dark blue-gray
  static const Color textSecondary = Color(0xFF6C757D);// Gray
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
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Outfit',
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Poppins',
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

// ============================================================================
// 2. REUSABLE WIDGETS
// ============================================================================

/// Custom App Bar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showNotification;
  final VoidCallback? onNotificationTap;

  const CustomAppBar({
    required this.title,
    this.showNotification = true,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      actions: [
        if (showNotification)
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: GestureDetector(
              onTap: onNotificationTap,
              child: Stack(
                children: [
                  Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Icon(Icons.settings_outlined, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

/// Health Summary Card
class HealthSummaryCard extends StatelessWidget {
  final String bloodPressure;
  final String bloodSugar;
  final DateTime lastUpdate;

  const HealthSummaryCard({
    this.bloodPressure = "120/80",
    this.bloodSugar = "95",
    required this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Health Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HealthMetric(
                label: 'Blood Pressure',
                value: bloodPressure,
                unit: 'mmHg',
                icon: Icons.favorite,
                status: 'Normal',
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withOpacity(0.3),
              ),
              _HealthMetric(
                label: 'Blood Sugar',
                value: bloodSugar,
                unit: 'mg/dl',
                icon: Icons.drop_circle,
                status: 'Good',
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Last update: ${DateFormat('hh:mm a').format(lastUpdate)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final String status;

  const _HealthMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '✓ $status',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Quick Action Card
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? backgroundColor;

  const QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.secondary, size: 20),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medication Reminder Widget
class MedicationReminderWidget extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String time;
  final VoidCallback onTook;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  const MedicationReminderWidget({
    this.medicineName = 'Aspirin',
    this.dosage = '1 tablet',
    this.time = '8:00 PM',
    required this.onTook,
    required this.onSkip,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withOpacity(0.8), AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medication, color: Colors.white, size: 20),
              SizedBox(width: AppSpacing.md),
              Text(
                'Time for your medicine',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '$medicineName • $dosage',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          Text(
            'Due at $time',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ReminderButton(
                label: 'Took it',
                onTap: onTook,
                isPrimary: true,
              ),
              _ReminderButton(
                label: 'Skip',
                onTap: onSkip,
              ),
              _ReminderButton(
                label: 'Later',
                onTap: onLater,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ReminderButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPrimary ? AppColors.accent : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Custom Bottom Navigation
class CustomBottomNav extends StatefulWidget {
  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Appointments',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medication_outlined),
          activeIcon: Icon(Icons.medication),
          label: 'Medicines',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'AI Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

// ============================================================================
// 3. MAIN DASHBOARD SCREEN
// ============================================================================

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'CareConnect'),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(Duration(seconds: 1));
        },
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.lg),
          children: [
            // Greeting
            Text(
              'Good Evening, Rajesh! 👋',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            SizedBox(height: AppSpacing.lg),

            // Health Summary Card
            HealthSummaryCard(
              lastUpdate: DateTime.now(),
            ),
            SizedBox(height: AppSpacing.lg),

            // Quick Actions Grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
                QuickActionCard(
                  icon: Icons.calendar_today,
                  title: 'Next Appointment',
                  subtitle: 'Tomorrow, 2:00 PM',
                  onTap: () {},
                ),
                QuickActionCard(
                  icon: Icons.medication,
                  title: 'Active Medicines',
                  subtitle: '3 medicines',
                  onTap: () {},
                ),
                QuickActionCard(
                  icon: Icons.trending_up,
                  title: 'Health Trends',
                  subtitle: 'View analytics',
                  onTap: () {},
                ),
                QuickActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ask AI Doctor',
                  subtitle: 'Get answers now',
                  backgroundColor: AppColors.secondary.withOpacity(0.05),
                  onTap: () {},
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),

            // AI Assistant Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.smart_toy_outlined,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        'Ask AI Doctor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mic_none,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Text(
                          'Ask your health question...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // Smart Reminder
            MedicationReminderWidget(
              onTook: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✓ Marked as taken')),
                );
              },
              onSkip: () {},
              onLater: () {},
            ),
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(),
    );
  }
}

// ============================================================================
// 4. MEDICINES MANAGEMENT SCREEN
// ============================================================================

class MedicineModel {
  final String name;
  final String dose;
  final String frequency;
  final String time;
  final String refillDate;
  final bool hasInteraction;
  final String? interactionWarning;

  MedicineModel({
    required this.name,
    required this.dose,
    required this.frequency,
    required this.time,
    required this.refillDate,
    this.hasInteraction = false,
    this.interactionWarning,
  });
}

class MedicinesScreen extends StatelessWidget {
  final List<MedicineModel> medicines = [
    MedicineModel(
      name: 'Aspirin',
      dose: '1 tablet',
      frequency: '2x daily',
      time: '8 AM, 8 PM',
      refillDate: 'In 15 days',
      hasInteraction: false,
    ),
    MedicineModel(
      name: 'Metformin',
      dose: '500mg',
      frequency: '1x daily',
      time: '8 AM',
      refillDate: 'In 20 days',
      hasInteraction: true,
      interactionWarning: 'May interact with Aspirin',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'My Medicines'),
      body: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.lg),
        itemCount: medicines.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Medicines (${medicines.length})',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Icon(Icons.add_circle, color: AppColors.primary, size: 24),
                ],
              ),
            );
          }

          if (index == medicines.length + 1) {
            return Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  color: Colors.white, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                'Scan Prescription',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          final medicine = medicines[index - 1];
          return _MedicineCard(medicine: medicine);
        },
      ),
      bottomNavigationBar: CustomBottomNav(),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final MedicineModel medicine;

  const _MedicineCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💊 ${medicine.name}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (medicine.hasInteraction)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '⚠️ Alert',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${medicine.dose} • ${medicine.frequency}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Time: ${medicine.time} ⏰',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Refill: ${medicine.refillDate}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (medicine.hasInteraction) ...[
            SizedBox(height: AppSpacing.md),
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠️ ${medicine.interactionWarning}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 5. APP ENTRY POINT
// ============================================================================

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareConnect',
      theme: buildAppTheme(),
      home: DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
