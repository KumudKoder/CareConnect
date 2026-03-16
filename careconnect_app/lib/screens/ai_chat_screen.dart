import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
  final String? imagePath;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.imagePath,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
  };

  static ChatMessage fromJson(Map<String, dynamic> j) => ChatMessage(
    text: j['text'] as String? ?? '',
    isUser: j['isUser'] as bool? ?? false,
    timestamp:
        j['timestamp'] != null
            ? DateTime.tryParse(j['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
    imagePath: j['imagePath'] as String?,
  );
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  static ChatSession fromJson(Map<String, dynamic> j) => ChatSession(
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Chat',
    createdAt:
        j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
    messages:
        (j['messages'] as List<dynamic>?)
            ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class MeetingNote {
  final String id;
  final String title;
  final String rawTranscript;
  final String summary;
  final List<String> redFlags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;

  MeetingNote({
    required this.id,
    required this.title,
    required this.rawTranscript,
    required this.summary,
    required this.redFlags,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  static MeetingNote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MeetingNote(
      id: doc.id,
      title: (d['title'] ?? 'Meeting Note').toString(),
      rawTranscript: (d['rawTranscript'] ?? '').toString(),
      summary: (d['summary'] ?? '').toString(),
      redFlags:
          (d['redFlags'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      status: (d['status'] ?? 'active').toString(),
    );
  }
}

class ChatStorage {
  static const String _sessionsKey = 'cc_chat_sessions_v1';

  static Future<List<ChatSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final sessions =
          list
              .map(
                (e) => ChatSession.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList();
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final limited = sessions.length > 30 ? sessions.sublist(0, 30) : sessions;
    await prefs.setString(
      _sessionsKey,
      jsonEncode(limited.map((s) => s.toJson()).toList()),
    );
  }

  static Future<void> deleteSession(String sessionId) async {
    final sessions = await load();
    sessions.removeWhere((s) => s.id == sessionId);
    await save(sessions);
  }
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  static const String _backendBase = String.fromEnvironment(
    'CARECONNECT_WS_BASE',
    defaultValue: '',
  );

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<ChatMessage> _messages = [];
  bool _isAITyping = false;
  int? _activeAiMessageIndex;
  String _aiTranscriptSoFar = '';

  List<ChatSession> _sessions = [];
  late String _currentSessionId;
  bool _isTemporary = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final ImagePicker _imagePicker = ImagePicker();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  bool _disposed = false;
  String _userId = 'guest';
  Timer? _responseTimeoutTimer;

  // Meeting notes / allergy safety
  bool _isMeetingActive = false;
  String? _activeMeetingNoteId;
  String _meetingTranscriptBuffer = '';
  Timer? _aiNotePersistDebounce;
  String _lastPersistedAiLine = '';
  bool _isSummarizingNote = false;

  List<String> _allergies = [];
  Set<String> _knownMedicineTerms = {};

  final List<String> _suggestedQuestions = [
    'Why is my BP high?',
    'What does my medicine do?',
    'Is my blood sugar normal?',
    'When should I exercise?',
    'What foods reduce BP?',
    'Can I skip my evening dose?',
    'What doctor told in my last meeting?',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) _userId = u.uid;
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    _loadSessions().then((_) => _startNewSession());
    _loadPatientContext();
  }

  Future<void> _loadSessions() async {
    final loaded = await ChatStorage.load();
    if (mounted) setState(() => _sessions = loaded);
  }

  Future<void> _loadPatientContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = userDoc.data() ?? {};

      final parsedAllergies = <String>[];
      final allergiesRaw = data['allergies'];
      if (allergiesRaw is String) {
        parsedAllergies.addAll(
          allergiesRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      } else if (allergiesRaw is List) {
        parsedAllergies.addAll(
          allergiesRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty),
        );
      }

      final medsSnap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('medicines')
              .get();

      final terms = <String>{};
      for (final doc in medsSnap.docs) {
        final m = doc.data();
        for (final key in ['name', 'genericName', 'brandName']) {
          final val = (m[key] ?? '').toString().trim().toLowerCase();
          if (val.isNotEmpty) terms.add(val);
        }
      }

      if (mounted) {
        setState(() {
          _allergies = parsedAllergies;
          _knownMedicineTerms = terms;
        });
      }
    } catch (_) {
      // non-fatal
    }
  }

  void _startNewSession({bool temporary = false}) {
    _saveCurrentSession();

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final u = FirebaseAuth.instance.currentUser;
    final userName = u?.displayName ?? u?.email?.split('@').first ?? 'there';

    setState(() {
      _currentSessionId = newId;
      _isTemporary = temporary;
      _messages.clear();
      _isAITyping = false;
      _activeAiMessageIndex = null;
      _aiTranscriptSoFar = '';
      _messages.add(
        ChatMessage(
          text:
              temporary
                  ? '⚡ Temporary chat — this conversation will be cleared when you close it.\n\nHello $userName! How can I help you today?'
                  : 'Hello $userName! 👋 I\'m your AI health assistant.\n\nI can help you with:\n• Understanding your health data\n• Medicine information & interactions\n• Exercise and diet recommendations\n• Doctor meeting notes & summaries\n\nHow can I help you today?',
          isUser: false,
        ),
      );
    });

    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connectWebSocket();
  }

  void _loadSession(ChatSession session) {
    _saveCurrentSession();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;

    setState(() {
      _currentSessionId = session.id;
      _isTemporary = false;
      _messages
        ..clear()
        ..addAll(session.messages);
      _isAITyping = false;
      _activeAiMessageIndex = null;
      _aiTranscriptSoFar = '';
    });

    _connectWebSocket();
    _scrollToBottom();
  }

  void _saveCurrentSession() {
    if (_isTemporary) return;
    if (_messages.isEmpty) return;
    final hasUserMessage = _messages.any((m) => m.isUser);
    if (!hasUserMessage) return;

    final firstUserMsg = _messages.firstWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(text: 'Chat', isUser: true),
    );
    final title =
        firstUserMsg.text.length > 40
            ? '${firstUserMsg.text.substring(0, 40)}…'
            : firstUserMsg.text;

    final updated = ChatSession(
      id: _currentSessionId,
      title: title,
      createdAt: _messages.first.timestamp,
      messages: List.from(_messages),
    );

    final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (idx >= 0) {
      _sessions[idx] = updated;
    } else {
      _sessions.insert(0, updated);
    }

    ChatStorage.save(_sessions);
  }

  Future<void> _deleteSession(String sessionId) async {
    await ChatStorage.deleteSession(sessionId);
    final sessions = await ChatStorage.load();
    if (mounted) setState(() => _sessions = sessions);
  }

  Future<void> _connectWebSocket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_backendBase.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI backend is not configured in this build. Rebuild with CARECONNECT_WS_BASE pointing to a reachable backend.',
            ),
          ),
        );
      }
      return;
    }

    _userId = user.uid;
    final token = await user.getIdToken(true);

    final baseUri = Uri.parse(_backendBase);
    final wsScheme =
        baseUri.scheme == 'https'
            ? 'wss'
            : (baseUri.scheme == 'http' ? 'ws' : baseUri.scheme);

    final wsUrl = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/$_userId/$_currentSessionId',
      queryParameters: {'token': token},
    );

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _channelSubscription = _channel?.stream.listen(
        _handleBackendMessage,
        onError: (error) {
          _cancelResponseTimeout();
          if (!_disposed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Connection error: $error. If this APK was shared, it may still be pointing to a local laptop backend.',
                ),
              ),
            );
          }
        },
        onDone: () {
          _cancelResponseTimeout();
          _channel = null;
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not connect to backend: $e. Shared APKs need a public backend, not a private 192.168.x.x address.',
            ),
          ),
        );
      }
    }
  }

  void _handleBackendMessage(dynamic data) {
    if (!mounted) return;

    _cancelResponseTimeout();

    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      String newText = '';

      if (message.containsKey('outputTranscription') &&
          message['outputTranscription'] != null) {
        final t = message['outputTranscription'];
        if (t is Map && t['text'] is String) newText = t['text'] as String;
      } else if (message['type'] == 'text' && message['text'] is String) {
        newText = message['text'] as String;
      }

      if (newText.isNotEmpty) {
        setState(() {
          _isAITyping = false;

          if (_activeAiMessageIndex == null ||
              _activeAiMessageIndex! >= _messages.length ||
              _messages[_activeAiMessageIndex!].isUser) {
            _messages.add(ChatMessage(text: '', isUser: false));
            _activeAiMessageIndex = _messages.length - 1;
            _aiTranscriptSoFar = '';
          }

          if (newText == _aiTranscriptSoFar) return;

          if (newText.startsWith(_aiTranscriptSoFar)) {
            _aiTranscriptSoFar = newText;
          } else if (!_aiTranscriptSoFar.startsWith(newText)) {
            _aiTranscriptSoFar += newText;
          } else {
            return;
          }

          final idx = _activeAiMessageIndex!;
          final cur = _messages[idx];
          _messages[idx] = ChatMessage(
            text: _aiTranscriptSoFar,
            isUser: false,
            timestamp: cur.timestamp,
          );
        });

        _scheduleAIMeetingPersist();
        _scrollToBottom();
        if (!_isTemporary) _saveCurrentSession();
      }
    } catch (_) {}
  }

  void _scheduleAIMeetingPersist() {
    _aiNotePersistDebounce?.cancel();
    _aiNotePersistDebounce = Timer(const Duration(milliseconds: 1200), () {
      final text = _aiTranscriptSoFar.trim();
      if (text.isEmpty || text == _lastPersistedAiLine) return;
      _lastPersistedAiLine = text;
      _appendMeetingLine('Doctor/AI', text);
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final trimmed = text.trim();

    // Smart local retrieval from latest cloud notes.
    final lower = trimmed.toLowerCase();
    final asksMeetingRecall =
        lower.contains('what doctor told') ||
        lower.contains('doctor said') ||
        lower.contains('last meeting') ||
        lower.contains('meeting notes');

    setState(() {
      _messages.add(ChatMessage(text: trimmed, isUser: true));
    });
    _appendMeetingLine('Patient', trimmed);

    if (asksMeetingRecall) {
      final recall = await _answerFromLatestMeetingNote();
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: recall, isUser: false));
      });
      _scrollToBottom();
      _controller.clear();
      if (!_isTemporary) _saveCurrentSession();
      _appendMeetingLine('Doctor/AI', recall);
      return;
    }

    setState(() {
      _isAITyping = true;
      _activeAiMessageIndex = null;
      _aiTranscriptSoFar = '';
    });

    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'text', 'text': trimmed}));
      _startResponseTimeout(
        'The AI backend did not answer in time. Check that the backend is running and reachable from this phone.',
      );
    } else {
      final isSignedIn = FirebaseAuth.instance.currentUser != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSignedIn
                ? 'Not connected to server'
                : 'Sign in to chat with the AI backend.',
          ),
        ),
      );
      setState(() => _isAITyping = false);
    }

    _controller.clear();
    _scrollToBottom();
    if (!_isTemporary) _saveCurrentSession();
  }

  Future<String> _answerFromLatestMeetingNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'Please sign in to access cloud meeting notes.';
    }

    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meeting_notes')
            .orderBy('updatedAt', descending: true)
            .limit(1)
            .get();

    if (snap.docs.isEmpty) {
      return 'I could not find any saved meeting notes yet. Start a meeting note from the drawer first.';
    }

    final note = MeetingNote.fromDoc(snap.docs.first);
    if (note.summary.trim().isNotEmpty) {
      return 'From your latest meeting notes:\n\n${note.summary}';
    }

    final text = note.rawTranscript.trim();
    if (text.isEmpty) {
      return 'Your latest meeting note exists but has no transcript yet.';
    }

    final clipped =
        text.length > 1200 ? '${text.substring(0, 1200)}\n\n...' : text;
    return 'From your latest meeting transcript:\n\n$clipped';
  }

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
            content: Text('🎤 Microphone permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCamera() => _pickAndSendImage(ImageSource.camera);
  Future<void> _openGallery() => _pickAndSendImage(ImageSource.gallery);

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (photo == null || !mounted || _disposed) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                source == ImageSource.camera
                    ? '📷 Captured image'
                    : '🖼️ Selected image',
            isUser: true,
            imagePath: photo.path,
          ),
        );
        _isAITyping = true;
        _activeAiMessageIndex = null;
        _aiTranscriptSoFar = '';
      });
      _appendMeetingLine(
        'Patient',
        source == ImageSource.camera
            ? '[Shared a camera image]'
            : '[Shared a gallery image]',
      );

      _scrollToBottom();

      if (_channel == null) {
        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not connected to server')),
          );
          setState(() => _isAITyping = false);
        }
        return;
      }

      final bytes = await photo.readAsBytes();
      final mimeType =
          photo.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';

      _channel!.sink.add(
        jsonEncode({
          'type': 'text',
          'text':
              'Please analyze this uploaded image. If it is a prescription, medical report, medicine box, or test result, explain what you can see in simple language and highlight any important medical details.',
        }),
      );

      _channel!.sink.add(
        jsonEncode({
          'type': 'image',
          'data': base64Encode(bytes),
          'mimeType': mimeType,
        }),
      );

      _startResponseTimeout(
        'The uploaded image was sent, but the AI did not respond. This usually means the backend is unreachable or the build points to the wrong server.',
      );
    } catch (_) {
      if (mounted && !_disposed) {
        setState(() => _isAITyping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? '📷 Camera failed. Check permissions.'
                  : '🖼️ Gallery failed. Check permissions.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startMeetingNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start meeting notes.')),
      );
      return;
    }

    final notes = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meeting_notes');

    final now = DateTime.now();
    final title =
        'Meeting ${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final doc = notes.doc();

    await doc.set({
      'title': title,
      'rawTranscript': '',
      'summary': '',
      'redFlags': <String>[],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'sessionId': _currentSessionId,
    });

    if (!mounted) return;
    setState(() {
      _isMeetingActive = true;
      _activeMeetingNoteId = doc.id;
      _meetingTranscriptBuffer = '';
      _lastPersistedAiLine = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📝 Meeting note started (cloud).')),
    );
  }

  Future<void> _endMeetingNote() async {
    final user = FirebaseAuth.instance.currentUser;
    final noteId = _activeMeetingNoteId;
    if (user == null || noteId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meeting_notes')
        .doc(noteId)
        .set({
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
          'endedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      _isMeetingActive = false;
      _activeMeetingNoteId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Meeting note ended and saved to cloud.')),
    );
  }

  Future<void> _appendMeetingLine(String speaker, String text) async {
    if (!_isMeetingActive) return;
    final user = FirebaseAuth.instance.currentUser;
    final noteId = _activeMeetingNoteId;
    if (user == null || noteId == null) return;

    final line = '[${_timeOfDay(DateTime.now())}] $speaker: ${text.trim()}';
    if (line.trim().isEmpty) return;

    _meetingTranscriptBuffer =
        _meetingTranscriptBuffer.isEmpty
            ? line
            : '$_meetingTranscriptBuffer\n$line';

    final flags = _detectAllergyFlags(text);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meeting_notes')
        .doc(noteId)
        .set({
          'rawTranscript': _meetingTranscriptBuffer,
          'updatedAt': FieldValue.serverTimestamp(),
          'redFlags': FieldValue.arrayUnion(flags),
          'status': 'active',
          'sessionId': _currentSessionId,
        }, SetOptions(merge: true));
  }

  List<String> _detectAllergyFlags(String text) {
    final lower = text.toLowerCase();
    final hasMedicineContext =
        lower.contains('prescribe') ||
        lower.contains('medicine') ||
        lower.contains('tablet') ||
        lower.contains('capsule') ||
        lower.contains('dose') ||
        _knownMedicineTerms.any((m) => lower.contains(m));

    if (!hasMedicineContext) return const [];

    final flags = <String>[];
    for (final allergy in _allergies) {
      final a = allergy.toLowerCase().trim();
      if (a.isEmpty) continue;
      if (lower.contains(a)) {
        flags.add(
          'Possible allergy conflict: "$allergy" appears in medication discussion.',
        );
      }
    }
    return flags.toSet().toList();
  }

  Future<void> _summarizeMeetingNote(MeetingNote note) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to summarize notes.')),
      );
      return;
    }

    final transcript = note.rawTranscript.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This note has no transcript yet.')),
      );
      return;
    }

    setState(() => _isSummarizingNote = true);

    try {
      final token = await user.getIdToken(true);
      final uri = _summaryUri();

      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.write(
        jsonEncode({'transcript': transcript, 'allergies': _allergies}),
      );

      final resp = await req.close();
      final body = await utf8.decodeStream(resp);

      String summary = '';
      List<String> redFlags = [];

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        summary = (decoded['summary'] ?? '').toString().trim();
        redFlags =
            (decoded['red_flags'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
      } else {
        summary = _fallbackSummary(transcript);
      }

      if (summary.isEmpty) summary = _fallbackSummary(transcript);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meeting_notes')
          .doc(note.id)
          .set({
            'summary': summary,
            'redFlags': FieldValue.arrayUnion(redFlags),
            'updatedAt': FieldValue.serverTimestamp(),
            'summarizedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Meeting summary saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not summarize note right now.')),
      );
    } finally {
      if (mounted) setState(() => _isSummarizingNote = false);
    }
  }

  Uri _summaryUri() {
    final base = Uri.parse(_backendBase);
    final scheme =
        base.scheme == 'wss'
            ? 'https'
            : (base.scheme == 'ws' ? 'http' : base.scheme);
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/notes/summarize',
    );
  }

  String _fallbackSummary(String transcript) {
    final lines =
        transcript
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (lines.isEmpty) return 'No transcript available to summarize.';
    final preview = lines.take(8).map((e) => '- $e').join('\n');
    return 'Summary (fallback):\n$preview${lines.length > 8 ? '\n- ...' : ''}';
  }

  void _openMeetingNoteSheet(MeetingNote note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${note.status}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (note.redFlags.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ Red flags',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        ...note.redFlags.map(
                          (f) => Text(
                            '• $f',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (note.redFlags.isNotEmpty) const SizedBox(height: 12),
                Text(
                  note.summary.trim().isEmpty
                      ? 'No summary yet.'
                      : note.summary,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (note.rawTranscript.trim().isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        note.rawTranscript,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isSummarizingNote
                                ? null
                                : () => _summarizeMeetingNote(note),
                        icon: const Icon(Icons.summarize_outlined),
                        label: Text(
                          _isSummarizingNote ? 'Summarizing...' : 'Summarize',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendMessage('What doctor told in my last meeting?');
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Ask from note'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeOfDay(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
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

  void _startResponseTimeout(String message) {
    _responseTimeoutTimer?.cancel();
    _responseTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_isAITyping) return;
      setState(() => _isAITyping = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _cancelResponseTimeout() {
    _responseTimeoutTimer?.cancel();
    _responseTimeoutTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _saveCurrentSession();
    _aiNotePersistDebounce?.cancel();
    _cancelResponseTimeout();
    _channelSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isTemporary ? '⚡ Temporary Chat' : 'AI Doctor',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _isMeetingActive
                  ? '📝 Meeting note active (cloud)'
                  : (_isTemporary
                      ? 'Not saved • closes when you leave'
                      : 'Online • Ready to help'),
              style: TextStyle(
                fontSize: 11,
                color:
                    _isMeetingActive
                        ? AppColors.primary
                        : (_isTemporary ? AppColors.accent : Colors.green),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              _isMeetingActive
                  ? Icons.stop_circle_outlined
                  : Icons.note_add_outlined,
              color:
                  _isMeetingActive ? AppColors.accent : AppColors.textPrimary,
            ),
            tooltip:
                _isMeetingActive ? 'End meeting note' : 'Start meeting note',
            onPressed: _isMeetingActive ? _endMeetingNote : _startMeetingNote,
          ),
          IconButton(
            icon: const Icon(
              Icons.add_comment_outlined,
              color: AppColors.textPrimary,
            ),
            tooltip: 'New chat',
            onPressed: _startNewSession,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isTemporary)
            Container(
              width: double.infinity,
              color: AppColors.accent.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.flash_on, size: 14, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'Temporary mode — this chat will not be saved.',
                    style: TextStyle(fontSize: 11, color: AppColors.accent),
                  ),
                ],
              ),
            ),
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

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const Text(
                '💬 Chats & Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _drawerActionTile(
              icon: Icons.add_comment_outlined,
              label: 'New Chat',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _startNewSession();
              },
            ),
            _drawerActionTile(
              icon: Icons.flash_on_outlined,
              label: 'Temporary Chat',
              color: AppColors.accent,
              subtitle: 'Not saved when closed',
              onTap: () {
                Navigator.pop(context);
                _startNewSession(temporary: true);
              },
            ),
            _drawerActionTile(
              icon:
                  _isMeetingActive
                      ? Icons.stop_circle_outlined
                      : Icons.note_add_outlined,
              label:
                  _isMeetingActive ? 'End Meeting Note' : 'Start Meeting Note',
              color: _isMeetingActive ? AppColors.accent : AppColors.secondary,
              subtitle: 'Stores raw doctor-patient notes in cloud',
              onTap: () async {
                Navigator.pop(context);
                if (_isMeetingActive) {
                  await _endMeetingNote();
                } else {
                  await _startMeetingNote();
                }
              },
            ),
            Divider(color: Colors.grey.shade200, height: 1),
            Expanded(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'PREVIOUS CHATS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (_sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        'No previous chats yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ..._sessions.map((session) {
                      final isActive = session.id == _currentSessionId;
                      return Dismissible(
                        key: Key('chat_${session.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: AppColors.accent.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.delete_outline,
                            color: AppColors.accent,
                          ),
                        ),
                        onDismissed: (_) => _deleteSession(session.id),
                        child: ListTile(
                          selected: isActive,
                          selectedTileColor: AppColors.primary.withValues(
                            alpha: 0.07,
                          ),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                isActive
                                    ? AppColors.primary
                                    : AppColors.secondary.withValues(
                                      alpha: 0.1,
                                    ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color:
                                  isActive ? Colors.white : AppColors.secondary,
                            ),
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _formatDate(session.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadSession(session);
                          },
                        ),
                      );
                    }),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'MEETING NOTES (CLOUD)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (user == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        'Sign in to view cloud notes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('meeting_notes')
                              .orderBy('updatedAt', descending: true)
                              .limit(20)
                              .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Loading notes...',
                              style: TextStyle(fontSize: 12),
                            ),
                          );
                        }

                        final notes =
                            snap.data!.docs.map(MeetingNote.fromDoc).toList();
                        if (notes.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Text(
                              'No meeting notes yet. Start one from above.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children:
                              notes.map((n) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        (n.redFlags.isNotEmpty)
                                            ? AppColors.accent.withValues(
                                              alpha: 0.2,
                                            )
                                            : AppColors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                    child: Icon(
                                      n.redFlags.isNotEmpty
                                          ? Icons.warning_amber_outlined
                                          : Icons.note_alt_outlined,
                                      size: 16,
                                      color:
                                          n.redFlags.isNotEmpty
                                              ? AppColors.accent
                                              : AppColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    n.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_formatDate(n.updatedAt ?? n.createdAt ?? DateTime.now())}${n.redFlags.isNotEmpty ? ' • ${n.redFlags.length} red flag(s)' : ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => _openMeetingNoteSheet(n),
                                );
                              }).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerActionTile({
    required IconData icon,
    required String label,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle:
          subtitle != null
              ? Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              )
              : null,
      onTap: onTap,
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (!message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        cacheWidth: 720,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              width: 220,
                              height: 180,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text(
                                'Image unavailable',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
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
    return const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.auto_awesome, color: Color(0xFF1A73E8), size: 22),
          ),
          Text(
            'Thinking...',
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
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openGallery,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
