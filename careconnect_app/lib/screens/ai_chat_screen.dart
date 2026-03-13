import 'package:flutter/material.dart';
import 'dart:async';

class AppColors {
  static const Color primary = Color(0xFF00897B);
  static const Color secondary = Color(0xFF6C5CE7);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  bool isTyping;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isTyping = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isAITyping = false;

  final List<String> _suggestedQuestions = [
    'Why is my BP high?',
    'What does my medicine do?',
    'Is my blood sugar normal?',
    'When should I exercise?',
    'What foods reduce BP?',
    'Can I skip my evening dose?',
  ];

  // Mock AI responses based on keywords
  final Map<String, String> _aiResponses = {
    'bp': '''High blood pressure can be caused by several factors:

1. **Stress** — Try relaxation techniques like deep breathing
2. **Salt intake** — Reduce sodium in your diet to <2000mg/day
3. **Lack of exercise** — Aim for 30 minutes of walking daily
4. **Medication adherence** — Take your medicines on time

📊 Your recent BP readings show a slightly rising trend (140/90).

⚠️ If your BP stays above 140/90 for 3+ days, please consult Dr. Sharma.

_Would you like me to schedule an appointment?_''',
    'medicine': '''Here are your current medications:

💊 **Aspirin** — 1 tablet, twice daily (8 AM & 8 PM)
   → Helps prevent blood clots and reduces heart attack risk

💊 **Metformin** — 500mg, once daily (8 AM)
   → Controls blood sugar levels for Type 2 Diabetes

⚠️ **Interaction Alert**: Metformin may interact with Aspirin. Monitor for signs of low blood sugar.

✅ Your adherence score: 92% (Excellent!)

_Always consult your doctor before changing any dosage._''',
    'sugar': '''Based on your recent readings:

📊 **Average Blood Sugar**: 110 mg/dl (Last 7 days)
✅ **Status**: Well controlled

Normal ranges:
• Fasting: 70-100 mg/dl
• After meals: <140 mg/dl

Your average is slightly above fasting normal but well within the after-meal range. Keep up the good work!

💡 **Tips**:
- Avoid sugary drinks
- Eat more fiber-rich foods
- Walk for 15 mins after meals

_Your next checkup with Dr. Sharma is tomorrow at 2 PM._''',
    'exercise': '''For your health profile (Hypertension + Diabetes), here's a recommended exercise plan:

🏃 **Daily Routine**:
• Morning walk — 30 minutes (brisk)
• Light stretching — 10 minutes
• Evening walk — 15 minutes (after dinner)

⏰ **Best times**:
• Morning: 6-7 AM (before breakfast)
• Evening: 7-8 PM (1 hour after dinner)

⚠️ **Precautions**:
• Check blood sugar before exercise
• Stay hydrated
• Avoid intense workouts
• Stop if you feel dizzy

📈 Regular exercise can reduce BP by 5-8 mmHg!''',
    'food': '''Foods that help lower blood pressure:

🥬 **Leafy Greens** — Spinach, kale (rich in potassium)
🍌 **Bananas** — Natural potassium source
🫐 **Berries** — Blueberries, strawberries (antioxidants)
🐟 **Fatty Fish** — Salmon, mackerel (omega-3)
🧄 **Garlic** — Natural BP reducer
🥣 **Oatmeal** — High fiber, low sodium
🥜 **Nuts** — Almonds, walnuts (healthy fats)

🚫 **Foods to AVOID**:
• Excess salt/sodium
• Processed foods
• Red meat in large quantities
• Sugary beverages & alcohol

💡 **Tip**: The DASH diet is specifically designed for hypertension patients.''',
    'skip': '''⚠️ **Please do not skip your evening dose without consulting your doctor.**

Skipping medication can cause:
• Blood pressure spikes
• Blood sugar fluctuations
• Reduced treatment effectiveness

If you're experiencing side effects, please discuss with Dr. Sharma at your appointment tomorrow.

💡 **Tip**: Set a reminder to take your medicine. I can help you with that!

_Would you like me to set a reminder?_''',
  };

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: '''Hello Rajesh! 👋 I'm your AI health assistant.

I can help you with:
• Understanding your health data
• Medicine information & interactions
• Exercise and diet recommendations
• Scheduling appointments

How can I help you today?''',
      isUser: false,
    ));
  }

  String _getAIResponse(String query) {
    final lowerQuery = query.toLowerCase();
    for (final entry in _aiResponses.entries) {
      if (lowerQuery.contains(entry.key)) {
        return entry.value;
      }
    }
    return '''I understand your concern. Based on your health profile:

• **Conditions**: Hypertension, Type 2 Diabetes
• **Current Medicines**: Aspirin (2x daily), Metformin (1x daily)
• **Last BP**: 140/90 mmHg
• **Last Sugar**: 110 mg/dl

I'd recommend discussing "$query" with Dr. Sharma at your appointment tomorrow (2:00 PM).

_Is there anything specific about your health I can help with?_''';
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isAITyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Simulate AI typing delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final response = _getAIResponse(text);
      setState(() {
        _isAITyping = false;
        _messages.add(ChatMessage(text: response, isUser: false));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('Online • Ready to help', style: TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isAITyping ? 1 : 0) + (_messages.length <= 1 ? 1 : 0),
              itemBuilder: (context, index) {
                // Show suggestions after welcome
                if (_messages.length <= 1 && index == _messages.length) {
                  return _buildSuggestions();
                }
                // Show typing indicator
                if (_isAITyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                if (index >= _messages.length) return const SizedBox();
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, color: AppColors.secondary, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')} ${message.timestamp.hour >= 12 ? 'PM' : 'AM'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Text('R', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy, color: AppColors.secondary, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0), const SizedBox(width: 4),
                _buildDot(1), const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 Suggested questions:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _suggestedQuestions.map((q) => GestureDetector(
              onTap: () => _sendMessage(q),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Text(q, style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Voice button
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🎤 Voice input coming soon!'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic, color: AppColors.secondary, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Text input
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Ask your health question...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Send button
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
