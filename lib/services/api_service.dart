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
  final String category; // Add this new field
  final String imageUrl; // Add this for images

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      description: json['description'] ?? '',
      category: json['category'] ?? 'All',
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/150',
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

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'rag_system': ragSystem,
      'knowledge_base_size': knowledgeBaseSize,
      'timestamp': timestamp,
    };
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

  /// 🤖 AI Chatbot - Compatible with ChatbotScreen (Original method preserved)
  static Future<String> askChatbot({
    required String question,
    required String sessionId,
  }) async {
    try {
      debugPrint('Sending question: $question (Session: $sessionId)');

      final response = await http
          .post(
            Uri.parse('$baseUrl/chatbot/chat'),
            headers: headers,
            body: json.encode({'message': question, 'session_id': sessionId}),
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

  /// 🤖 Enhanced AI Chatbot with Session Management
  static Future<String> askChatbotWithSession(
    String question,
    String sessionId, {
    String? context,
    String? cropType,
  }) async {
    try {
      debugPrint(
        'Sending question with session: $question (Session: $sessionId)',
      );

      Map<String, dynamic> requestBody = {
        'question': question,
        'session_id': sessionId,
      };

      // Add optional parameters if provided
      if (context != null && context.isNotEmpty) {
        requestBody['context'] = context;
      }
      if (cropType != null && cropType.isNotEmpty) {
        requestBody['crop_type'] = cropType;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/chatbot/query'),
            headers: headers,
            body: json.encode(requestBody),
          )
          .timeout(timeoutDuration);

      debugPrint('Session response status: ${response.statusCode}');
      debugPrint('Session response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['answer'] ??
            data['reply'] ??
            'Sorry, I couldn\'t process your question.';
      } else if (response.statusCode == 422) {
        return 'Please check your question and try again.';
      } else if (response.statusCode == 500) {
        return 'Server error. Please try again later.';
      } else {
        // Try to parse error details from response
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['detail'] ??
                'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        } catch (_) {
          throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Network error. Please try again.');
    } on FormatException {
      throw Exception('Invalid response format from server.');
    } catch (e) {
      debugPrint('Error in askChatbotWithSession: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get response: ${e.toString()}');
    }
  }

  /// 🔄 Clear chat session
  static Future<bool> clearChatSession(String sessionId) async {
    try {
      debugPrint('Clearing session: $sessionId');

      // Corrected in clearChatSession
      final response = await http
          .post(
            // Corrected to POST method
            Uri.parse('$baseUrl/chatbot/conversation/clear'), // Corrected path
            headers: headers,
            body: json.encode({'session_id': sessionId}), // Added correct body
          )
          .timeout(timeoutDuration);

      debugPrint('Clear session status: ${response.statusCode}');

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error clearing session: $e');
      // Don't throw error for session clearing as it's not critical
      return false;
    }
  }

  /// 📝 Get chat history for a session
  static Future<List<Map<String, dynamic>>> getChatHistory(
    String sessionId,
  ) async {
    try {
      debugPrint('Getting chat history for session: $sessionId');

      // Original in getChatHistory
      // Corrected in getChatHistory
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/chatbot/conversation/history?session_id=$sessionId',
            ), // Corrected path and added query parameter
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      } else {
        debugPrint('Failed to get chat history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  /// 🎯 Smart chatbot query with fallback chain
  static Future<String> askChatbotSmart(
    String question, {
    String? sessionId,
    String? context,
    String? cropType,
    bool useSessionIfAvailable = true,
  }) async {
    try {
      // Try session-based query first if session ID is available
      if (sessionId != null && useSessionIfAvailable) {
        return await askChatbotWithSession(
          question,
          sessionId,
          context: context,
          cropType: cropType,
        );
      }

      // Fallback to regular chatbot query
      return await askChatbot(
        question: question,
        sessionId: sessionId ?? "default-session", // or generate UUID here
      );
    } catch (e) {
      debugPrint('Smart query failed, trying simple query: $e');

      try {
        // Try simple query as fallback
        return await askChatbotSimple(question);
      } catch (e2) {
        debugPrint('All queries failed, using offline fallback: $e2');

        // Return offline fallback response
        return _getFallbackResponse(question);
      }
    }
  }

  /// Detailed chatbot query - returns structured response (Original method preserved)
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

  /// Enhanced detailed query with session support
  static Future<ChatResponse> askChatbotDetailedWithSession(
    String question,
    String sessionId, {
    String? context,
    String? cropType,
  }) async {
    try {
      debugPrint(
        'Sending detailed question with session: $question (Session: $sessionId)',
      );

      Map<String, dynamic> requestBody = {
        'question': question,
        'session_id': sessionId,
      };
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

      debugPrint('Detailed session response status: ${response.statusCode}');

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
      debugPrint('Error in askChatbotDetailedWithSession: $e');
      rethrow;
    }
  }

  /// Simple fallback query using basic keyword matching (Original method preserved)
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

  /// Check server health (Original method preserved)
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

  /// Enhanced server health check with additional info
  static Future<Map<String, dynamic>> checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Server status check error: $e');
      return {
        'status': 'offline',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get available topics from the knowledge base (Original method preserved)
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

  /// Generate a unique session ID
  static String generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random =
        (DateTime.now().microsecond * 1000 + DateTime.now().millisecond)
            .toString();
    return '${timestamp}_$random';
  }

  /// Validate session ID format
  static bool isValidSessionId(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    // Basic validation - should contain timestamp and random part
    return sessionId.contains('_') && sessionId.length > 10;
  }

  /// Enhanced offline fallback responses (Original method preserved with improvements)
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
    } else if (lowerQuestion.contains('disease') ||
        lowerQuestion.contains('fungus')) {
      return "🍄 Practice crop rotation and ensure good air circulation. Remove infected plant material promptly. Consider copper-based fungicides for organic treatment.";
    } else if (lowerQuestion.contains('seed') ||
        lowerQuestion.contains('planting')) {
      return "🌱 Choose disease-resistant varieties when possible. Plant at proper depth and spacing. Check seed germination rates before planting.";
    } else {
      return "🚜 I'm currently offline, but here's a general farming tip: Monitor crops weekly for early signs of disease or pest problems. Feel free to ask more specific questions when I'm back online!";
    }
  }

  /// Test connection to server (Original method preserved)
  static Future<bool> testConnection() async {
    try {
      await checkHealth();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enhanced connection test with detailed results
  static Future<Map<String, dynamic>> testConnectionDetailed() async {
    final startTime = DateTime.now();

    try {
      final healthStatus = await checkHealth();
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;

      return {
        'connected': true,
        'response_time_ms': responseTime,
        'server_status': healthStatus.toJson(),
        'timestamp': endTime.toIso8601String(),
      };
    } catch (e) {
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;

      return {
        'connected': false,
        'response_time_ms': responseTime,
        'error': e.toString(),
        'timestamp': endTime.toIso8601String(),
      };
    }
  }

  // 🛒 Get All Products (SIMULATED with categories for demonstration)
  static Future<List<Product>> fetchProducts() async {
    // This part is modified to simulate a backend response with categories.
    // In a real app, your FastAPI backend would provide this data.
    return Future.value([
      Product(
        id: 1,
        name: "Organic Fertilizer",
        price: 299.0,
        description: "Rich in nitrogen and potassium.",
        category: "Fertilizers",
        imageUrl:
            "https://via.placeholder.com/150/8BC34A/FFFFFF?text=Fertilizer",
      ),
      Product(
        id: 2,
        name: "Hybrid Seeds Pack",
        price: 149.0,
        description: "High-yield, drought-resistant.",
        category: "Seeds",
        imageUrl: "https://via.placeholder.com/150/4CAF50/FFFFFF?text=Seeds",
      ),
      Product(
        id: 3,
        name: "Drip Irrigation Kit",
        price: 899.0,
        description: "Water-efficient irrigation system.",
        category: "Equipment",
        imageUrl:
            "https://via.placeholder.com/150/2196F3/FFFFFF?text=Equipment",
      ),
      Product(
        id: 4,
        name: "Premium Potting Soil",
        price: 120.0,
        description: "Aerated and rich with nutrients.",
        category: "Soil Test",
        imageUrl: "https://via.placeholder.com/150/795548/FFFFFF?text=Soil",
      ),
      Product(
        id: 5,
        name: "Tomato Seeds",
        price: 85.0,
        description: "Heirloom variety, great for sauces.",
        category: "Seeds",
        imageUrl: "https://via.placeholder.com/150/E91E63/FFFFFF?text=Tomato",
      ),
      Product(
        id: 6,
        name: "Pesticide Spray",
        price: 450.0,
        description: "Organic pest control solution.",
        category:
            "Fertilizers", // Renaming from 'Pesticide' to fit a broad category
        imageUrl:
            "https://via.placeholder.com/150/FF9800/FFFFFF?text=Pesticide",
      ),
      Product(
        id: 7,
        name: "Tractor",
        price: 250000.0,
        description: "Used tractor, low hours.",
        category: "Equipment",
        imageUrl: "https://via.placeholder.com/150/607D8B/FFFFFF?text=Tractor",
      ),
      Product(
        id: 8,
        name: "Soil pH Test Kit",
        price: 550.0,
        description: "Easy to use kit for pH testing.",
        category: "Soil Test",
        imageUrl: "https://via.placeholder.com/150/4CAF50/FFFFFF?text=pH+Kit",
      ),
    ]);
    // The original code is commented out below
    // final response = await http.get(Uri.parse("$baseUrl/products/all"));
    // if (response.statusCode == 200) {
    //   List<dynamic> data = jsonDecode(response.body);
    //   return data.map((item) => Product.fromJson(item)).toList();
    // } else {
    //   throw Exception("Failed to load products");
    // }
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
