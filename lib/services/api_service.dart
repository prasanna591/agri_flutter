import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your backend IP/host
  static const String baseUrl = "http://10.0.2.2:8000"; // For Android Emulator
  // If using real device on same WiFi: "http://<your-pc-ip>:8000"

  /// GET request
  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed GET: ${response.body}");
      }
    } catch (e) {
      print("GET Error: $e");
      return null;
    }
  }

  /// POST request with JSON body
  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse("$baseUrl$endpoint");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed POST: ${response.body}");
      }
    } catch (e) {
      print("POST Error: $e");
      return null;
    }
  }

  /// Upload Image (for disease detection)
  static Future<dynamic> uploadImage(String endpoint, File imageFile) async {
    final url = Uri.parse("$baseUrl$endpoint");
    try {
      var request = http.MultipartRequest("POST", url);
      request.files.add(
        await http.MultipartFile.fromPath("file", imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed Image Upload: ${response.body}");
      }
    } catch (e) {
      print("Image Upload Error: $e");
      return null;
    }
  }
}
