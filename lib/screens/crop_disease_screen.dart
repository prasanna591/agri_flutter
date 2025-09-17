import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CropDiseaseScreen extends StatefulWidget {
  const CropDiseaseScreen({super.key});

  @override
  State<CropDiseaseScreen> createState() => _CropDiseaseScreenState();
}

class _CropDiseaseScreenState extends State<CropDiseaseScreen> {
  File? _image;
  String _result = "";
  List<Map<String, dynamic>> _recommendedProducts = [];

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) return;
    final response = await ApiService.uploadImage("/disease/predict", _image!);

    setState(() {
      _result =
          "Prediction: ${response['prediction']}\n"
          "Suggestion: ${response['suggestion']}";
      _recommendedProducts = List<Map<String, dynamic>>.from(
        response['recommended_products'] ?? [],
      );
    });
  }

  Future<void> _placeOrder(int productId) async {
    final response = await ApiService.post("/orders/create", {
      "product_id": productId,
      "quantity": 1,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? "Order failed")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🌱 Crop Disease Detection")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null) Image.file(_image!, height: 150),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("📸 Pick Image"),
            ),
            ElevatedButton(
              onPressed: _uploadImage,
              child: const Text("🔍 Detect Disease"),
            ),
            const SizedBox(height: 20),
            Text(_result, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _recommendedProducts.length,
                itemBuilder: (context, index) {
                  final product = _recommendedProducts[index];
                  return Card(
                    child: ListTile(
                      title: Text(product['name']),
                      subtitle: Text(product['description']),
                      trailing: Column(
                        children: [
                          Text("₹${product['price']}"),
                          ElevatedButton(
                            onPressed: () =>
                                _placeOrder(product['id'] ?? (index + 1)),
                            child: const Text("Buy Now"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
