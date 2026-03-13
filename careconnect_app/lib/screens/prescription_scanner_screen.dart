import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  final String dosage;
  final String frequency;
  final String duration;
  bool isSelected;
  String? interactionWarning;

  ScannedMedicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    this.duration = '',
    this.isSelected = true,
    this.interactionWarning,
  });
}

class PrescriptionScannerScreen extends StatefulWidget {
  const PrescriptionScannerScreen({super.key});

  @override
  State<PrescriptionScannerScreen> createState() => _PrescriptionScannerScreenState();
}

class _PrescriptionScannerScreenState extends State<PrescriptionScannerScreen> {
  File? _capturedImage;
  bool _isProcessing = false;
  bool _hasResults = false;
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
        });
        await _processImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _processImage() async {
    // Simulate AI processing delay
    await Future.delayed(const Duration(seconds: 2));

    // In production, you'd send _capturedImage to Gemini with visionPrompt:
    // final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    // final imageBytes = await _capturedImage!.readAsBytes();
    // final content = Content.multi([
    //   TextPart(visionPrompt),
    //   DataPart('image/jpeg', imageBytes),
    // ]);
    // final response = await model.generateContent([content]);

    // Mock results for demonstration
    setState(() {
      _scannedMedicines.clear();
      _scannedMedicines.addAll([
        ScannedMedicine(
          name: 'Paracetamol',
          dosage: '500mg tablet',
          frequency: 'Three times daily (after meals)',
          duration: '5 days',
        ),
        ScannedMedicine(
          name: 'Amoxicillin',
          dosage: '250mg capsule',
          frequency: 'Twice daily (morning & night)',
          duration: '7 days',
          interactionWarning: 'May reduce effectiveness of oral contraceptives',
        ),
        ScannedMedicine(
          name: 'Cetirizine',
          dosage: '10mg tablet',
          frequency: 'Once daily (at bedtime)',
          duration: '10 days',
        ),
      ]);
      _isProcessing = false;
      _hasResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.document_scanner, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Scan Your Prescription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Take a clear photo of your prescription.\nOur AI will extract medicine details automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
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
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📸 Tips for best results:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('• Place prescription on a flat surface', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('• Ensure good lighting', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('• Capture the full prescription', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('• Keep the camera steady', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
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
          const Text('🤖 AI is analyzing your prescription...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Extracting medicine names, dosages & frequencies', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
        image: _capturedImage != null
            ? DecorationImage(image: FileImage(_capturedImage!), fit: BoxFit.cover)
            : null,
      ),
      child: _capturedImage == null
          ? const Center(child: Icon(Icons.image, size: 48, color: AppColors.textSecondary))
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
              Text('Gemini Vision Prompt Used', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary)),
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
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    int interactions = _scannedMedicines.where((m) => m.interactionWarning != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Found ${_scannedMedicines.length} medicines', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (interactions > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('⚠️ $interactions warning${interactions > 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 12),
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
        border: med.interactionWarning != null ? Border.all(color: AppColors.warning.withValues(alpha: 0.5)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
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
                child: Text('💊 ${med.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Dosage', med.dosage),
                _buildDetailRow('Frequency', med.frequency),
                if (med.duration.isNotEmpty) _buildDetailRow('Duration', med.duration),
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
                        const Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(med.interactionWarning!, style: const TextStyle(fontSize: 11, color: AppColors.warning))),
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
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ $selected medicine(s) added to your profile!'), backgroundColor: AppColors.success),
              );
              Future.delayed(const Duration(seconds: 1), () { if (mounted) Navigator.pop(context); });
            },
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: Text('Add $selected Medicine(s) to Profile', style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() { _hasResults = false; _capturedImage = null; }),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Scan Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Discard'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
