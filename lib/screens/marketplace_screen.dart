import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<Map<String, dynamic>> _products = [];

  Future<void> _fetchProducts() async {
    final response = await ApiService.get("/products/all");
    setState(() {
      _products = List<Map<String, dynamic>>.from(response ?? []);
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
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🛒 Marketplace")),
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return Card(
            child: ListTile(
              title: Text(product['name']),
              subtitle: Text(product['description']),
              trailing: Column(
                children: [
                  Text("₹${product['price']}"),
                  ElevatedButton(
                    onPressed: () => _placeOrder(product['id'] ?? (index + 1)),
                    child: const Text("Buy"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}