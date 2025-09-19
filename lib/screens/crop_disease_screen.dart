import 'dart:typed_data'; // for web image bytes
import 'dart:io' show File;
import 'dart:convert'; // for json.decode
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

// Model classes to match React structure
class Medicine {
  final String name;
  final String? mixingRatio;

  Medicine({required this.name, this.mixingRatio});

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] ?? '',
      mixingRatio: json['mixing_ratio'],
    );
  }
}

class DiseaseResult {
  final String diseaseName;
  final List<String> precautions;
  final List<String> remedies;
  final List<Medicine> medicines;

  DiseaseResult({
    required this.diseaseName,
    required this.precautions,
    required this.remedies,
    required this.medicines,
  });

  factory DiseaseResult.fromJson(Map<String, dynamic> json) {
    return DiseaseResult(
      diseaseName: json['disease_name'] ?? '',
      precautions: List<String>.from(json['precautions'] ?? []),
      remedies: List<String>.from(json['remedies'] ?? []),
      medicines:
          (json['medicines'] as List<dynamic>?)
              ?.map((m) => Medicine.fromJson(m))
              .toList() ??
          [],
    );
  }

  bool get isHealthy => diseaseName.toLowerCase() == 'healthy';
}

class CropDiseaseScreen extends StatefulWidget {
  const CropDiseaseScreen({super.key});

  @override
  State<CropDiseaseScreen> createState() => _CropDiseaseScreenState();
}

class _CropDiseaseScreenState extends State<CropDiseaseScreen> {
  File? _imageFile; // for mobile
  Uint8List? _imageBytes; // for web
  DiseaseResult? _result;
  String? _error;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFile = null;
          _result = null;
          _error = null;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageBytes = null;
          _result = null;
          _error = null;
        });
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null && _imageBytes == null) {
      setState(() => _error = "Please select an image file first.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // Call backend API
      final response = kIsWeb
          ? await ApiService.detectDiseaseWeb(_imageBytes!)
          : await ApiService.detectDisease(_imageFile!);

      // Debug print to check what backend returns
      debugPrint("API Response: $response");
      debugPrint("Response type: ${response.runtimeType}");

      // Try to work with whatever we get
      dynamic data = response;

      // If response has a 'prediction' key, use that
      if (response != null &&
          response is Map &&
          (response as Map).containsKey('prediction')) {
        data = (response as Map)['prediction'];
      }

      final result = DiseaseResult.fromJson(Map<String, dynamic>.from(data));

      setState(() => _result = result);
    } catch (e, stack) {
      debugPrint("Error in analyzeImage: $e\n$stack");
      setState(() => _error = "Analysis failed: ${e.toString()}");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _clearAll() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          "🌿 AI Plant Disease Detector",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.green[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro text
            Text(
              "Upload an image of a plant leaf to get an instant diagnosis, along with precautions and remedies.",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Main content grid
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 768) {
                  // Wide screen layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUploaderColumn()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildResultsColumn()),
                    ],
                  );
                } else {
                  // Mobile layout
                  return Column(
                    children: [
                      _buildUploaderColumn(),
                      const SizedBox(height: 24),
                      _buildResultsColumn(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploaderColumn() {
    return Column(
      children: [
        // Image Preview Container
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                : _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Click or drag image here",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Supports JPG, PNG formats",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Button Group
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                onPressed:
                    (_loading || (_imageFile == null && _imageBytes == null))
                    ? null
                    : _analyzeImage,
                child: _loading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Analyzing...",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "Predict Disease",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed:
                    (_imageFile == null &&
                        _imageBytes == null &&
                        _result == null)
                    ? null
                    : _clearAll,
                child: Text(
                  "Clear",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsColumn() {
    if (_loading) {
      return _buildLoadingSpinner();
    }

    if (_error != null) {
      return _buildErrorMessage(_error!);
    }

    if (_result != null) {
      return _buildResultCard(_result!);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingSpinner() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 3, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            "Analyzing your plant image...",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Error",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: GoogleFonts.poppins(color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(DiseaseResult result) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: result.isHealthy
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isHealthy ? "Plant is Healthy" : "Disease Detected",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: result.isHealthy
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.diseaseName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: result.isHealthy
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (result.precautions.isNotEmpty)
                  _buildInfoSection(
                    result.isHealthy ? "General Care Tips" : "Precautions",
                    "🛡️",
                    result.precautions,
                  ),
                if (result.remedies.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildInfoSection("Remedies", "🌿", result.remedies),
                ],
                if (result.medicines.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildMedicineSection(result.medicines),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String icon, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineSection(List<Medicine> medicines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("💊", style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              "Recommended Medicines",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...medicines.map(
          (medicine) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                if (medicine.mixingRatio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Mixing Ratio: ${medicine.mixingRatio}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
