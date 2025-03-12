// lib/src/services/subscription_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

class SubscriptionService {
  // Singleton pattern for easy access.
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> availableProducts = [];

  /// Initialize the in-app purchase connection and query product details.
  Future<void> init() async {
    // Check if IAP is available on the device.
    final bool available = await _iap.isAvailable();
    if (!available) {
      // Handle the unavailability (e.g., show an error message)
      return;
    }

    // Define the product identifiers that you have set up in App Store Connect / Play Console.
    const Set<String> _kProductIds = {'your_subscription_product_id'};

    // Query the products.
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kProductIds);
    if (response.error != null) {
      // Handle any error during product query.
      return;
    }
    availableProducts = response.productDetails;

    // Listen to the purchase updates.
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onError: (error) {
        // Handle error during purchase updates.
      },
    );
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Optionally show a UI indicator that the purchase is pending.
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Verify the purchase if needed and then deliver the subscription.
        _deliverProduct(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error (e.g., show an error message to the user).
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

void _deliverProduct(PurchaseDetails purchaseDetails) async {
    // Get the current user.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update Firebase user document to mark subscription as active.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'subscribed': true});
      // Optionally: call a method or notify your UserDataProvider to update its state.
    }
    // You might also show a success message, etc.
    print('Subscription activated successfully!');
  }

  /// Initiate a purchase for a given product.
  Future<void> purchaseProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Dispose the purchase subscription when no longer needed.
  void dispose() {
    _subscription?.cancel();
  }
}
