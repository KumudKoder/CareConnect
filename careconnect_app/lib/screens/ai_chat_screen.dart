import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final String? imagePath; // for camera images

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isTyping = false,
    this.imagePath,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isAITyping = false;
  int? _activeAiMessageIndex;
  String _aiTranscriptSoFar = '';

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  // WebSocket
  WebSocketChannel? _channel;
  final String _userId = "user_123"; // TODO: Get from auth
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  final List<String> _suggestedQuestions = [
    'Why is my BP high?',
    'What does my medicine do?',
    'Is my blood sugar normal?',
    'When should I exercise?',
    'What foods reduce BP?',
    'Can I skip my evening dose?',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _connectWebSocket();
    _messages.add(
      ChatMessage(
        text: '''Hello Rajesh! 👋 I'm your AI health assistant.

I can help you with:
• Understanding your health data
• Medicine information & interactions
• Exercise and diet recommendations
• Scheduling appointments

How can I help you today?''',
        isUser: false,
      ),
    );
  }

  void _connectWebSocket() {
    // Replace with your actual backend IP if running on device/emulator
    // 192.168.29.62 is the host PC IP for physical device testing
    final wsUrl = Uri.parse('ws://192.168.29.62:8081/ws/$_userId/$_sessionId');
    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _channel?.stream.listen(
        (data) {
          _handleBackendMessage(data);
        },
        onError: (error) {
          print('WebSocket Error: $error');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Connection error: $error')));
          }
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );
    } catch (e) {
      print('Could not connect: $e');
    }
  }

  void _handleBackendMessage(dynamic data) {
    if (!mounted) return;

    try {
      final Map<String, dynamic> message = jsonDecode(data as String);
      String newText = "";

      // We ONLY listen to outputTranscription to avoid duplication from the final content block
      if (message.containsKey('outputTranscription') &&
          message['outputTranscription'] != null) {
        final transcription = message['outputTranscription'];
        if (transcription.containsKey('text') &&
            transcription['text'] != null) {
          newText = transcription['text'];
        }
      }

      if (newText.isNotEmpty) {
        setState(() {
          _isAITyping = false;

          // Create a fresh AI bubble for this turn if needed.
          if (_activeAiMessageIndex == null ||
              _activeAiMessageIndex! < 0 ||
              _activeAiMessageIndex! >= _messages.length ||
              _messages[_activeAiMessageIndex!].isUser) {
            _messages.add(ChatMessage(text: '', isUser: false));
            _activeAiMessageIndex = _messages.length - 1;
            _aiTranscriptSoFar = '';
          }

          // Native-audio transcription can be cumulative, so avoid double-append.
          if (newText == _aiTranscriptSoFar) {
            // Duplicate event; ignore.
            return;
          }

          if (newText.startsWith(_aiTranscriptSoFar)) {
            // Full transcript-so-far update: replace current message with latest.
            _aiTranscriptSoFar = newText;
          } else if (_aiTranscriptSoFar.startsWith(newText)) {
            // Older/out-of-order partial update; ignore.
            return;
          } else {
            // Delta chunk update: append.
            _aiTranscriptSoFar += newText;
          }

          final idx = _activeAiMessageIndex!;
          final currentMsg = _messages[idx];
          _messages[idx] = ChatMessage(
            text: _aiTranscriptSoFar,
            isUser: false,
            timestamp: currentMsg.timestamp,
          );
        });
        _scrollToBottom();
      }
      // Handle the legacy simple format if we ever use it
      else if (message['type'] == 'text' && message.containsKey('text')) {
        setState(() {
          _isAITyping = false;
          _messages.add(ChatMessage(text: message['text'], isUser: false));
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error parsing backend message: $e');
    }
  }

  // Removed _getAIResponse dummy logic

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isAITyping = true;
      _activeAiMessageIndex = null;
      _aiTranscriptSoFar = '';
    });

    // Send to backend via WebSocket
    if (_channel != null) {
      final payload = jsonEncode({"type": "text", "text": text.trim()});
      _channel!.sink.add(payload);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not connected to server')));
      setState(() => _isAITyping = false);
    }

    _controller.clear();
    _scrollToBottom();
  }

  // ── VOICE INPUT ──────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎤 Mic error: ${error.errorMsg}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          }
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _sendMessage(result.recognizedWords);
            // Alternatively, buffer PCM audio directly:
            // if (_channel != null) {
            //   _channel!.sink.add(jsonEncode({
            //     "type": "audio",
            //     "data": base64Encode(pcmAudioBytes),
            //   }));
            // }
            _speech.stop();
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎤 Microphone permission denied. Please allow mic access in Settings.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── CAMERA INPUT ─────────────────────────────────────────────────
  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo == null || !mounted) return;

      // Add the image as a user message
      setState(() {
        _messages.add(
          ChatMessage(
            text: '📷 Scanned image',
            isUser: true,
            imagePath: photo.path,
          ),
        );
        _isAITyping = true;
      });
      _scrollToBottom();

      // Read file and send base64 over WebSocket
      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      if (_channel != null) {
        final payload = jsonEncode({
          "type": "image",
          "data": base64Image,
          "mimeType": "image/jpeg",
        });
        _channel!.sink.add(payload);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to server')),
        );
        setState(() => _isAITyping = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Camera error: Check permissions or space.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    _speech.stop();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Doctor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Online • Ready to help',
              style: TextStyle(fontSize: 11, color: Colors.green),
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
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  _messages.length +
                  (_isAITyping ? 1 : 0) +
                  (_messages.length <= 1 ? 1 : 0),
              itemBuilder: (context, index) {
                if (_messages.length <= 1 && index == _messages.length) {
                  return _buildSuggestions();
                }
                if (_isAITyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                if (index >= _messages.length) return const SizedBox();
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    // AI Message Style (Gemini-like clean look)
    if (!isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Blue Gemini Sparkle
            Container(
              margin: const EdgeInsets.only(right: 12, top: 4),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF1A73E8),
                size: 22,
              ),
            ),
            Expanded(
              child: MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1F1F1F),
                    height: 1.5,
                  ),
                  h1: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F1F),
                  ),
                  h2: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F1F),
                  ),
                  h3: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F1F),
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 15,
                  ),
                  strong: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // User Message Style (Light grey rounded bubble on the right)
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding:
                  message.imagePath != null
                      ? const EdgeInsets.all(6)
                      : const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(message.imagePath!),
                        width: 220,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (message.imagePath == null || message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1F1F1F),
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF1A73E8),
              size: 22,
            ),
          ),
          const Text(
            "Thinking...",
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Color(0xFF5F6368),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) => _TypingDot(index: index);

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '💡 Suggested questions:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children:
                  _suggestedQuestions
                      .map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _sendMessage(q),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                q,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Mic button — toggles listening
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _isListening
                          ? AppColors.accent
                          : AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.white : AppColors.secondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Camera button
            GestureDetector(
              onTap: _openCamera,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text input
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText:
                      _isListening
                          ? '🎤 Listening...'
                          : 'Ask your health question...',
                  hintStyle: TextStyle(
                    color:
                        _isListening
                            ? AppColors.accent
                            : AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send button
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: Container(
                width: 44,
                height: 44,
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

class _TypingDot extends StatefulWidget {
  final int index;
  const _TypingDot({required this.index});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.secondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
