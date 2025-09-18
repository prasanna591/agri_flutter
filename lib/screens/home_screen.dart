import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_FeatureCard> features = [
      _FeatureCard(
        title: "Crop Disease",
        subtitle: "Detect crop health issues 🌱",
        icon: Icons.agriculture,
        color: Colors.green,
        route: "/crop-disease",
      ),
      _FeatureCard(
        title: "AI Chatbot",
        subtitle: "Ask anything, anytime 🤖",
        icon: Icons.chat_bubble,
        color: Colors.blue,
        route: "/chatbot",
      ),
      _FeatureCard(
        title: "Marketplace",
        subtitle: "Buy & sell farm products 🛒",
        icon: Icons.storefront,
        color: Colors.orange,
        route: "/marketplace",
      ),
      _FeatureCard(
        title: "Orders",
        subtitle: "Track your purchases 📦",
        icon: Icons.receipt_long,
        color: Colors.purple,
        route: "/orders",
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green[100],
              child: const Icon(Icons.person, color: Colors.green),
            ),
            const SizedBox(width: 8),
            Text(
              "Hi, Farmer 👋",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔎 Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: "Search crops, tools, tips...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              /// 🖼️ Dummy Banner
              SizedBox(
                height: 140,
                child: PageView(
                  children: [
                    _bannerCard("Get crop tips", Colors.green[200]!),
                    _bannerCard("Buy seeds easily", Colors.orange[200]!),
                    _bannerCard("AI Farming tools", Colors.blue[200]!),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              /// Features section
              Text(
                "Features",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: features.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, feature.route),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: feature.color.withOpacity(0.1),
                              radius: 30,
                              child: Icon(
                                feature.icon,
                                size: 32,
                                color: feature.color,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              feature.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              feature.subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              /// Recommended Section
              Text(
                "Recommended for You",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _recommendedCard("Fertilizer tips", "Boost your yield 🌾"),
              _recommendedCard("Irrigation guide", "Save water 💧"),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 Dummy Banner Widget
  static Widget _bannerCard(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color,
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  /// 🔹 Recommended Card
  static Widget _recommendedCard(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
