import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  // Speech recognition
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';

  // Language selection
  String _selectedLanguage = 'en-US';
  final Map<String, String> _languages = {'en-US': 'English', 'ta-IN': 'தமிழ்'};

  // State management
  bool _loading = false;
  String? _sessionId;

  // Animations
  late AnimationController _micAnimationController;
  late Animation<double> _micPulseAnimation;
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeAnimations();
    _generateSessionId();

    // Add enhanced welcome message
    _messages.add({
      "role": "bot",
      "text":
          "Hello! I'm your agricultural assistant. How can I help you today with crop diseases or our products?",
      "timestamp": DateTime.now(),
    });
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
  }

  void _initializeAnimations() {
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _micPulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  void _generateSessionId() {
    _sessionId = ApiService.generateSessionId();
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Microphone Permission Required',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please grant microphone permission to use voice input.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('Settings', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      await _requestMicrophonePermission();
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _micAnimationController.repeat(reverse: true);

        await _speech.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
              _controller.text = _recognizedText;
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          localeId: _selectedLanguage,
        );
      }
    } else {
      setState(() => _isListening = false);
      _micAnimationController.stop();
      _micAnimationController.reset();
      await _speech.stop();
    }
  }

  Future<void> _sendMessage() async {
    String query = _controller.text.trim();
    if (query.isEmpty || _loading || _sessionId == null) return;

    setState(() {
      _messages.add({
        "role": "user",
        "text": query,
        "timestamp": DateTime.now(),
      });
      _loading = true;
      _controller.clear();
    });

    _scrollToBottom();
    _typingAnimationController.repeat();

    try {
      // Use smart query method that falls back gracefully
      final answer = await ApiService.askChatbotSmart(
        query,
        sessionId: _sessionId,
        useSessionIfAvailable: true,
      );
      setState(() {
        _messages.add({
          "role": "bot",
          "text": answer,
          "timestamp": DateTime.now(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "bot",
          "text":
              "Sorry, I'm having trouble connecting. Error: ${e.toString()}\n\nHere's a general tip: ${_getOfflineTip(query)}",
          "timestamp": DateTime.now(),
        });
      });
    } finally {
      setState(() => _loading = false);
      _typingAnimationController.stop();
      _typingAnimationController.reset();
      _scrollToBottom();
    }
  }

  String _getOfflineTip(String question) {
    final lowerQuestion = question.toLowerCase();

    if (lowerQuestion.contains('water') ||
        lowerQuestion.contains('irrigation')) {
      return "Most crops need 1-1.5 inches of water per week. Water deeply but less frequently.";
    } else if (lowerQuestion.contains('pest') ||
        lowerQuestion.contains('disease')) {
      return "Check plants regularly for early signs of problems. Use integrated pest management approaches.";
    } else if (lowerQuestion.contains('soil') ||
        lowerQuestion.contains('fertilizer')) {
      return "Maintain soil pH between 6.0-7.5 for most crops. Add organic matter regularly.";
    } else if (lowerQuestion.contains('weather') ||
        lowerQuestion.contains('climate')) {
      return "Monitor weather forecasts and protect crops from extreme conditions.";
    }
    return "Keep monitoring your crops regularly and maintain good agricultural practices.";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    // Clear session on server if possible
    if (_sessionId != null) {
      ApiService.clearChatSession(_sessionId!);
    }

    setState(() {
      _messages.clear();
      _messages.add({
        "role": "bot",
        "text":
            "Chat cleared! How can I help you with your agricultural questions?",
        "timestamp": DateTime.now(),
      });
    });
    _generateSessionId(); // Generate new session ID for fresh start
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isUser = msg["role"] == "user";
    DateTime timestamp = msg["timestamp"] ?? DateTime.now();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot avatar (left side for bot messages)
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8, top: 8),
              decoration: BoxDecoration(
                color: Colors.green[500],
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],

          // Message bubble
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[500] : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg["text"] ?? "",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isUser ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User avatar (right side for user messages)
          if (isUser) ...[
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 8, top: 8),
              decoration: BoxDecoration(
                color: Colors.blue[500],
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  'Y',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8, top: 8),
            decoration: BoxDecoration(
              color: Colors.green[500],
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => AnimatedBuilder(
                  animation: _typingAnimationController,
                  builder: (context, child) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[500]!.withOpacity(
                        (0.4 +
                                0.6 *
                                    (((_typingAnimationController.value +
                                            index * 0.3) %
                                        1.0)))
                            .clamp(0.0, 1.0),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = [
      "💧 How much water does my crop need?",
      "🐛 How to identify pest problems?",
      "🌾 Best fertilizers for vegetables",
      "🌤️ Weather protection tips",
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(left: 8, right: 4),
            child: ActionChip(
              label: Text(
                suggestions[index],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green[700],
                ),
              ),
              backgroundColor: Colors.green[50],
              onPressed: () {
                _controller.text = suggestions[index].substring(
                  2,
                ); // Remove emoji
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _micAnimationController.dispose();
    _typingAnimationController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.agriculture,
                color: Colors.green[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Agri Assistant Chatbot",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Ask me anything about farming",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.green[700]),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick suggestions (only show when no messages or just welcome message)
          if (_messages.length <= 1) _buildQuickSuggestions(),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Start a conversation!",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _loading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Enhanced input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Language selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        items: _languages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                entry.value,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLanguage = newValue!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Voice input button
                  AnimatedBuilder(
                    animation: _micPulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _isListening ? _micPulseAnimation.value : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.red[400]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: _isListening
                                ? Colors.white
                                : Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: _toggleListening,
                          tooltip: _isListening
                              ? 'Stop Recording'
                              : 'Start Recording',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text input field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? "Listening..."
                              : "Ask or type your question...",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_loading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: _loading || _controller.text.trim().isEmpty
                          ? Colors.green[200]
                          : Colors.green[400],
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _loading ? Icons.hourglass_empty : Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _loading || _controller.text.trim().isEmpty
                          ? null
                          : _sendMessage,
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
}
