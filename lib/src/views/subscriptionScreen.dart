import 'package:flutter/material.dart';
import 'package:food_fellas/src/services/subscriptionService.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();
    final product = subscriptionService.availableProducts.isNotEmpty
        ? subscriptionService.availableProducts.first
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text("Upgrade to Premium 🌟"),
        actions: [
          IconButton(
            icon: Icon(Icons.restore),
            tooltip: "Restore Purchases",
            onPressed: () async {
              // Call restore purchases
              await InAppPurchase.instance.restorePurchases();
              // Optionally, you can show a confirmation snack bar.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Restore purchases initiated")),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Text(
                  "✨ Unlock Premium Features ✨",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),

                // Mock-up Phone Image
                Center(
                  child: Image.asset(
                    "lib/assets/images/mockup_phone.png",
                    width: MediaQuery.of(context).size.width * 0.6,
                  ),
                ),
                SizedBox(height: 20),

                // Subscription Description
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "🚀 Upgrade to premium and unlock exclusive features:",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 15),

                // Feature List in Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFeatureTile(
                          "💬",
                          "Unlimited AI Chatting",
                          "Chat with AI anytime for cooking inspiration & meal ideas.",
                        ),
                        Divider(),
                        _buildFeatureTile(
                          "📸",
                          "Image-to-Recipe",
                          "Snap a dish, and AI generates a recipe for you.",
                        ),
                        Divider(),
                        _buildFeatureTile(
                          "📂",
                          "Unlimited Collections",
                          "Save & manage an unlimited number of recipes.",
                        ),
                        Divider(),
                        _buildFeatureTile(
                          "🤝",
                          "Collaborative Cooking",
                          "Share and edit collections with friends & family.",
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Promise more features and encourage subscription
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "🎁 And many more features coming soon!",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Subscribe now and enjoy the complete FoodFellas experience!",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 100), // Space for scrolling
              ],
            ),
          ),

          // Fixed Subscribe Button at the Bottom
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: _buildSubscribeButton(context, product, subscriptionService),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String emoji, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(emoji, style: TextStyle(fontSize: 30)),
        ), // Centered Icon
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildSubscribeButton(BuildContext context, dynamic product,
      SubscriptionService subscriptionService) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () async {
          if (product != null) {
            await subscriptionService.purchaseProduct(product);
          }
        },
        child: Center(
          child: Text(
            product != null
                ? "Subscribe Now for only ${product.price}"
                : "Subscribe Now for only \€2.99",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
