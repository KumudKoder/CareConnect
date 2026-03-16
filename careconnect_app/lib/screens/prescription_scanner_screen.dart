import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AppColors {
  static const Color primary = Color(0xFF00897B);
  static const Color secondary = Color(0xFF6C5CE7);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
}

class ScannedMedicine {
  final String name;
  final String genericName;
  final String brandName;
  final String dosage;
  final String frequency;
  final String duration;
  final double confidence;
  bool isSelected;
  String? interactionWarning;

  ScannedMedicine({
    required this.name,
    this.genericName = '',
    this.brandName = '',
    required this.dosage,
    required this.frequency,
    this.duration = '',
    this.confidence = 0,
    this.isSelected = true,
    this.interactionWarning,
  });
}

class PrescriptionScannerScreen extends StatefulWidget {
  const PrescriptionScannerScreen({super.key});

  @override
  State<PrescriptionScannerScreen> createState() =>
      _PrescriptionScannerScreenState();
}

class _PrescriptionScannerScreenState extends State<PrescriptionScannerScreen> {
  static const String _backendBase = String.fromEnvironment(
    'CARECONNECT_WS_BASE',
    defaultValue: 'ws://192.168.29.62:8081',
  );

  File? _capturedImage;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _hasResults = false;
  String _aiRawResponse = '';
  final ImagePicker _picker = ImagePicker();

  // Simulated scanned medicines
  final List<ScannedMedicine> _scannedMedicines = [];

  // The Gemini Vision Prompt (used when sending to Gemini API)
  // "Extract the Drug Name, Dosage, and Frequency from this prescription image."

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
          _isProcessing = true;
          _hasResults = false;
          _aiRawResponse = '';
        });
        await _processImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _processImage() async {
    final image = _capturedImage;
    if (image == null) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {
      final aiResponse = await _analyzePrescriptionWithAI(image);
      final medicines = _parseMedicinesFromResponse(aiResponse);

      if (!mounted) return;
      setState(() {
        _scannedMedicines
          ..clear()
          ..addAll(medicines);
        _aiRawResponse = aiResponse;
        _isProcessing = false;
        _hasResults = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scannedMedicines.clear();
        _aiRawResponse =
            'Sorry, I could not analyze this prescription right now. Please try again.';
        _isProcessing = false;
        _hasResults = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI scan failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String> _analyzePrescriptionWithAI(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in before scanning prescription.');
    }

    final token = await user.getIdToken(true);
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    final baseUri = Uri.parse(_backendBase);
    final wsScheme =
        baseUri.scheme == 'https'
            ? 'wss'
            : (baseUri.scheme == 'http' ? 'ws' : baseUri.scheme);
    final wsUrl = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/${user.uid}/$sessionId',
      queryParameters: {'token': token},
    );

    final bytes = await imageFile.readAsBytes();
    final ext = imageFile.path.toLowerCase();
    final mimeType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';

    final channel = WebSocketChannel.connect(wsUrl);
    final completer = Completer<String>();
    StreamSubscription? subscription;
    Timer? idleTimer;
    String transcript = '';

    void completeNow() {
      if (!completer.isCompleted) {
        completer.complete(transcript.trim());
      }
    }

    subscription = channel.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          String chunk = '';

          if (message.containsKey('outputTranscription') &&
              message['outputTranscription'] is Map<String, dynamic>) {
            final out = message['outputTranscription'] as Map<String, dynamic>;
            final text = out['text'];
            if (text is String) {
              chunk = text;
            }
          } else if (message['type'] == 'text' && message['text'] is String) {
            chunk = message['text'] as String;
          }

          if (chunk.isNotEmpty) {
            if (chunk == transcript) {
              return;
            }
            if (chunk.startsWith(transcript)) {
              transcript = chunk;
            } else if (!transcript.startsWith(chunk)) {
              transcript += chunk;
            }

            idleTimer?.cancel();
            idleTimer = Timer(const Duration(milliseconds: 1400), completeNow);
          }
        } catch (_) {
          // Ignore malformed frames and continue collecting valid output.
        }
      },
      onError: (_) => completeNow(),
      onDone: completeNow,
      cancelOnError: false,
    );

    final prompt = jsonEncode({
      'type': 'text',
      'text':
          'You are analyzing a medicine prescription image. Identify medicines and respond in valid JSON only with this shape: '
          '{"medicines":[{"name":"...","genericName":"...","brandName":"...","dosage":"...","frequency":"...","duration":"...","confidence":0.0,"interactionWarning":"optional"}],"summary":"..."}. '
          'Rules: dosage, frequency, and duration are mandatory keys for each medicine; if unknown, set value to "Unknown". '
          'confidence must be between 0 and 1. Return only JSON.',
    });

    final imagePayload = jsonEncode({
      'type': 'image',
      'data': base64Encode(bytes),
      'mimeType': mimeType,
    });

    channel.sink.add(prompt);
    channel.sink.add(imagePayload);

    Timer(const Duration(seconds: 12), completeNow);

    final result = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => transcript.trim(),
    );

    idleTimer?.cancel();
    await subscription.cancel();
    await channel.sink.close();

    if (result.isEmpty) {
      throw Exception('No response from AI backend');
    }
    return result;
  }

  List<ScannedMedicine> _parseMedicinesFromResponse(String rawText) {
    final jsonText = _extractJsonObject(rawText);
    if (jsonText == null) return [];

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return [];

      final medicines = decoded['medicines'];
      if (medicines is! List) return [];

      return medicines
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => ScannedMedicine(
              name: (m['name'] ?? 'Unknown').toString(),
              genericName: (m['genericName'] ?? m['generic'] ?? '').toString(),
              brandName: (m['brandName'] ?? m['brand'] ?? '').toString(),
              dosage: (m['dosage'] ?? 'Unknown').toString(),
              frequency: (m['frequency'] ?? 'Unknown').toString(),
              duration: (m['duration'] ?? 'Unknown').toString(),
              confidence:
                  (m['confidence'] is num)
                      ? (m['confidence'] as num).toDouble().clamp(0.0, 1.0)
                      : 0.0,
              interactionWarning: m['interactionWarning']?.toString(),
            ),
          )
          .where((m) => m.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String? _extractJsonObject(String rawText) {
    final cleaned =
        rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return null;
    }
    return cleaned.substring(start, end + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Scan Prescription',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera / Upload section
            if (!_hasResults) _buildCaptureSection(),

            // Processing indicator
            if (_isProcessing) _buildProcessingIndicator(),

            // Results
            if (_hasResults) ...[
              _buildImagePreview(),
              const SizedBox(height: 20),
              _buildVisionPromptCard(),
              const SizedBox(height: 20),
              _buildResultsSection(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureSection() {
    return Column(
      children: [
        // Instruction
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.document_scanner,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan Your Prescription',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a clear photo of your prescription.\nOur AI will extract medicine details automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Camera & Gallery buttons
        Row(
          children: [
            Expanded(
              child: _buildOptionButton(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                color: AppColors.primary,
                onTap: () => _captureImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOptionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                color: AppColors.secondary,
                onTap: () => _captureImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tips
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.2),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📸 Tips for best results:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '• Place prescription on a flat surface',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '• Ensure good lighting',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '• Capture the full prescription',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '• Keep the camera steady',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.secondary),
          const SizedBox(height: 20),
          const Text(
            '🤖 AI is analyzing your prescription...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Extracting medicine names, dosages & frequencies',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        image:
            _capturedImage != null
                ? DecorationImage(
                  image: FileImage(_capturedImage!),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child:
          _capturedImage == null
              ? const Center(
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              )
              : null,
    );
  }

  Widget _buildVisionPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.secondary, size: 18),
              SizedBox(width: 8),
              Text(
                'Gemini Vision Prompt Used',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '"Extract the Drug Name, Dosage, and Frequency from this prescription image."',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    int interactions =
        _scannedMedicines.where((m) => m.interactionWarning != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_aiRawResponse.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🤖 AI analysis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _aiRawResponse,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Found ${_scannedMedicines.length} medicines',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (interactions > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚠️ $interactions warning${interactions > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_scannedMedicines.isEmpty)
          const Text(
            'No structured medicines could be extracted. Please try a clearer image.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else
          ..._scannedMedicines.map((med) => _buildMedicineResult(med)),
      ],
    );
  }

  Widget _buildMedicineResult(ScannedMedicine med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            med.interactionWarning != null
                ? Border.all(color: AppColors.warning.withValues(alpha: 0.5))
                : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: med.isSelected,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => med.isSelected = v ?? true),
              ),
              Expanded(
                child: Text(
                  '💊 ${med.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (med.brandName.trim().isNotEmpty)
                  _buildDetailRow('Brand', med.brandName),
                if (med.genericName.trim().isNotEmpty)
                  _buildDetailRow('Generic', med.genericName),
                _buildDetailRow('Dosage', med.dosage),
                _buildDetailRow('Frequency', med.frequency),
                _buildDetailRow(
                  'Duration',
                  med.duration.isEmpty ? 'Unknown' : med.duration,
                ),
                _buildDetailRow(
                  'Confidence',
                  '${(med.confidence * 100).toStringAsFixed(0)}%',
                ),
                if (med.interactionWarning != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            med.interactionWarning!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    int selected = _scannedMedicines.where((m) => m.isSelected).length;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _addSelectedMedicinesToProfile,
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving...' : 'Add $selected Medicine(s) to Profile',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    () => setState(() {
                      _hasResults = false;
                      _capturedImage = null;
                      _scannedMedicines.clear();
                      _aiRawResponse = '';
                    }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Scan Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Discard'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addSelectedMedicinesToProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      }
      return;
    }

    final selectedMeds = _scannedMedicines.where((m) => m.isSelected).toList();
    if (selectedMeds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one medicine to add.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final medsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines');

      final batch = FirebaseFirestore.instance.batch();
      for (final med in selectedMeds) {
        final docRef = medsCollection.doc();
        batch.set(docRef, {
          'name': med.name,
          'genericName': med.genericName,
          'brandName': med.brandName,
          'dosage': med.dosage,
          'frequency': med.frequency,
          'duration': med.duration.isEmpty ? 'Unknown' : med.duration,
          'confidence': med.confidence,
          'interactionWarning': med.interactionWarning,
          'source': 'prescription_scan',
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${selectedMeds.length} medicine(s) added to your profile!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save medicines: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
