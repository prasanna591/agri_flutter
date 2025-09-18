import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/crop_disease_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/orders_screen.dart';

void main() {
  runApp(const AgriApp());
}

class AgriApp extends StatelessWidget {
  const AgriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri Advisor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/crop-disease': (context) => const CropDiseaseScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/marketplace': (context) => const MarketplaceScreen(),
        '/orders': (context) => const OrdersScreen(),
      },
    );
  }
}
