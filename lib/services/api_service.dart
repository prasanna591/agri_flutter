import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart';

/// Base URL of your FastAPI backend
const String baseUrl = kIsWeb
    ? "http://127.0.0.1:8000"
    : "http://10.0.2.2:8000";

/// --------------------
/// MODELS
/// --------------------

class Product {
  final int id;
  final String name;
  final double price;
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class Order {
  final int id;
  final List<int> productIds;
  final double totalPrice;

  Order({required this.id, required this.productIds, required this.totalPrice});

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      productIds: List<int>.from(json['product_ids']),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }
}

/// Additional models for detailed chatbot responses (from Document 1)
class ChatResponse {
  final String answer;
  final double confidenceScore;
  final List<String> sources;
  final List<String> relatedTopics;
  final String responseType;

  ChatResponse({
    required this.answer,
    required this.confidenceScore,
    required this.sources,
    required this.relatedTopics,
    required this.responseType,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] ?? '',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      sources: List<String>.from(json['sources'] ?? []),
      relatedTopics: List<String>.from(json['related_topics'] ?? []),
      responseType: json['response_type'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'confidence_score': confidenceScore,
      'sources': sources,
      'related_topics': relatedTopics,
      'response_type': responseType,
    };
  }
}

class HealthStatus {
  final String status;
  final String ragSystem;
  final int knowledgeBaseSize;
  final String timestamp;

  HealthStatus({
    required this.status,
    required this.ragSystem,
    required this.knowledgeBaseSize,
    required this.timestamp,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] ?? 'unknown',
      ragSystem: json['rag_system'] ?? 'unknown',
      knowledgeBaseSize: json['knowledge_base_size'] ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }

  bool get isHealthy => status == 'healthy';
  bool get isRagEnabled => ragSystem == 'initialized';
}

/// --------------------
/// API SERVICE CLASS
/// --------------------

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Headers for all requests
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// 🌱 Crop Disease Detection (Image Upload for Web)
  static Future<String> detectDiseaseWeb(Uint8List imageBytes) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/disease/predict"),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        imageBytes,
        filename: "upload.png", // required for web uploads
      ),
    );

    var response = await request.send();
    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      var data = jsonDecode(respStr);
      return data['prediction'] ?? "No result";
    } else {
      throw Exception(
        "Failed to detect disease (Web). Status: ${response.statusCode}",
      );
    }
  }

  /// 🌱 Crop Disease Detection (Image Upload) - MOBILE
  static Future<String> detectDisease(File imageFile) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/disease/predict"),
    );
    request.files.add(
      await http.MultipartFile.fromPath("file", imageFile.path),
    );

    var response = await request.send();
    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      var data = jsonDecode(respStr);
      return data['prediction'] ?? "No result";
    } else {
      throw Exception(
        "Failed to detect disease. Status: ${response.statusCode}",
      );
    }
  }

  /// 🤖 AI Chatbot - Compatible with ChatbotScreen
  static Future<String> askChatbot(String question) async {
    try {
      debugPrint('Sending question: $question');

      final response = await http
          .post(
            Uri.parse('$baseUrl/chatbot/query'),
            headers: headers,
            body: json.encode({'question': question}),
          )
          .timeout(timeoutDuration);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['answer'] ?? 'Sorry, I couldn\'t process your question.';
      } else if (response.statusCode == 422) {
        return 'Please check your question and try again.';
      } else if (response.statusCode == 500) {
        return 'Server error. Please try again later.';
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server.');
    } catch (e) {
      debugPrint('Error in askChatbot: $e');
      throw Exception('Failed to get response: ${e.toString()}');
    }
  }

  /// Detailed chatbot query - returns structured response
  static Future<ChatResponse> askChatbotDetailed(
    String question, {
    String? context,
    String? cropType,
  }) async {
    try {
      debugPrint('Sending detailed question: $question');

      Map<String, dynamic> requestBody = {'question': question};
      if (context != null && context.isNotEmpty) {
        requestBody['context'] = context;
      }
      if (cropType != null && cropType.isNotEmpty) {
        requestBody['crop_type'] = cropType;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/detailed_query'),
            headers: headers,
            body: json.encode(requestBody),
          )
          .timeout(timeoutDuration);

      debugPrint('Detailed response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatResponse.fromJson(data);
      } else if (response.statusCode == 422) {
        throw Exception('Invalid request format. Please check your input.');
      } else if (response.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server.');
    } catch (e) {
      debugPrint('Error in askChatbotDetailed: $e');
      rethrow;
    }
  }

  /// Simple fallback query using basic keyword matching
  static Future<String> askChatbotSimple(String question) async {
    try {
      debugPrint('Sending simple question: $question');

      final response = await http
          .post(
            Uri.parse('$baseUrl/simple_query'),
            headers: headers,
            body: json.encode({'question': question}),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['answer'] ?? 'Sorry, I couldn\'t process your question.';
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('Error in askChatbotSimple: $e');
      // Return a fallback response if all else fails
      return _getFallbackResponse(question);
    }
  }

  /// Check server health
  static Future<HealthStatus> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HealthStatus.fromJson(data);
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Health check error: $e');
      throw Exception('Unable to connect to server: ${e.toString()}');
    }
  }

  /// Get available topics from the knowledge base
  static Future<List<String>> getAvailableTopics() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/topics'), headers: headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['available_topics'] ?? []);
      } else {
        throw Exception('Failed to fetch topics: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching topics: $e');
      return [
        'irrigation',
        'pest_control',
        'soil_management',
        'nutrition',
        'climate',
      ];
    }
  }

  /// Offline fallback responses
  static String _getFallbackResponse(String question) {
    final lowerQuestion = question.toLowerCase();

    if (lowerQuestion.contains('water') ||
        lowerQuestion.contains('irrigation')) {
      return "🌱 Most crops need 1-1.5 inches of water per week. Water deeply but less frequently to encourage root growth. Check soil moisture before watering.";
    } else if (lowerQuestion.contains('pest') ||
        lowerQuestion.contains('insect')) {
      return "🐛 Try Integrated Pest Management (IPM) first. Use neem oil for soft-bodied insects. Encourage beneficial insects like ladybugs.";
    } else if (lowerQuestion.contains('soil') ||
        lowerQuestion.contains('fertilizer')) {
      return "🌾 Ensure soil pH is between 6.0-7.5 for most crops. Add organic matter regularly. Test soil every 2-3 years.";
    } else if (lowerQuestion.contains('weather') ||
        lowerQuestion.contains('climate')) {
      return "🌤️ Check local forecasts and avoid irrigation before rains. Use row covers for frost protection.";
    } else {
      return "🚜 I'm currently offline, but here's a general farming tip: Monitor crops weekly for early signs of disease or pest problems. Feel free to ask more specific questions when I'm back online!";
    }
  }

  /// Test connection to server
  static Future<bool> testConnection() async {
    try {
      await checkHealth();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🛒 Get All Products
  static Future<List<Product>> fetchProducts() async {
    final response = await http.get(Uri.parse("$baseUrl/products/all"));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load products");
    }
  }

  /// ➕ Add New Product
  static Future<Product> addProduct(Product product) async {
    final response = await http.post(
      Uri.parse("$baseUrl/products/add"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": product.id,
        "name": product.name,
        "price": product.price,
        "description": product.description,
      }),
    );

    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to add product");
    }
  }

  /// 📦 Create New Order
  static Future<Order> createOrder(List<int> productIds) async {
    final response = await http.post(
      Uri.parse("$baseUrl/orders/create"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(productIds),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to create order");
    }
  }

  /// 📜 Get All Orders
  static Future<List<Order>> fetchOrders() async {
    final response = await http.get(Uri.parse("$baseUrl/orders/all"));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Order.fromJson(item)).toList();
    } else {
      throw Exception("Failed to fetch orders");
    }
  }
}

/// Exception classes for better error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
