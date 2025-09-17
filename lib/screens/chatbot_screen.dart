import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  String _response = "";

  Future<void> _askChatbot() async {
    if (_controller.text.isEmpty) return;

    final res = await ApiService.post("/chatbot/query", {
      "query": _controller.text,
    });
    setState(() {
      _response = res["answer"] ?? "No response";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🤖 Agri Chatbot")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Ask me about crops, fertilizers, pests...",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _askChatbot, child: const Text("Ask")),
            const SizedBox(height: 20),
            Text(_response, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
