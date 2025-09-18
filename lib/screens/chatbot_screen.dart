import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Add a welcome message when the screen loads
    _messages.add({
      "role": "bot",
      "text":
          "🌱 Hello! I'm your Agriculture Assistant. Ask me anything about farming, crops, irrigation, pest control, or any agricultural topics!",
    });
  }

  Future<void> _sendMessage() async {
    String query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": query});
      _loading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final answer = await ApiService.askChatbot(query);
      setState(() {
        _messages.add({"role": "bot", "text": answer});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "bot",
          "text":
              "❌ Sorry, I'm having trouble connecting to the server. Here's a general tip: ${_getOfflineTip(query)}",
        });
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  // Provide offline tips based on question keywords
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
    setState(() {
      _messages.clear();
      _messages.add({
        "role": "bot",
        "text":
            "🌱 Chat cleared! How can I help you with your agricultural questions?",
      });
    });
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    bool isUser = msg["role"] == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.green[400] : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg["text"] ?? "",
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isUser ? Colors.white : Colors.black87,
            height: 1.4,
          ),
        ),
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
                    "Agri Assistant 🤖",
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
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),

          // Loading indicator
          if (_loading)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green[400]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Assistant is thinking...",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Input area
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
                          hintText: "Ask about farming, crops, irrigation...",
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green[400],
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
                      onPressed: _loading ? null : _sendMessage,
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
