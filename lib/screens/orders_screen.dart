import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];

  Future<void> _fetchOrders() async {
    final response = await ApiService.get("/orders/all");
    setState(() {
      _orders = List<Map<String, dynamic>>.from(response ?? []);
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📦 My Orders")),
      body: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Card(
            child: ListTile(
              title: Text("Order #${order['id']}"),
              subtitle: Text("Product ID: ${order['product_id']}"),
              trailing: Text("Status: ${order['status']}"),
            ),
          );
        },
      ),
    );
  }
}
