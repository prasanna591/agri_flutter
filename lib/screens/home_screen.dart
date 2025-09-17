import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🌾 Agri Advisor"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/disease'),
              child: const Text("🌱 Crop Disease Detection"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/chatbot'),
              child: const Text("🤖 Agri Chatbot"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/marketplace'),
              child: const Text("🛒 Marketplace"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/orders'),
              child: const Text("📦 My Orders"),
            ),
          ],
        ),
      ),
    );
  }
}
