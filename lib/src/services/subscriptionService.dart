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
    print("Initializing in-app purchases...");
    // Check if IAP is available on the device.
    final bool available = await _iap.isAvailable();
    if (!available) {
      print('IAP is not available on this device.');
      return;
    }
    print("IAP is available.");

    // Define the product identifiers that you have set up in App Store Connect / Play Console.
    const Set<String> _kProductIds = {'premsub'};
    print("Querying products for IDs: $_kProductIds");

    // Query the products.
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kProductIds);
    if (response.error != null) {
      print("Error querying products: ${response.error}");
      return;
    }
    availableProducts = response.productDetails;
    print("Available products: ${availableProducts.map((p) => p.id).toList()}");

    // Listen to the purchase updates.
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onError: (error) {
        print("Error in purchase stream: $error");
      },
    );
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    print("Purchase update received: ${purchaseDetailsList.length} item(s)");
    for (var purchaseDetails in purchaseDetailsList) {
      print(
          "Purchase status: ${purchaseDetails.status} for product ${purchaseDetails.productID}");
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print("Purchase is pending...");
        // Optionally show a UI indicator that the purchase is pending.
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        print("Purchase completed or restored. Delivering product...");
        _deliverProduct(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print("Purchase error: ${purchaseDetails.error}");
        // Handle error (e.g., show an error message to the user).
      }

      if (purchaseDetails.pendingCompletePurchase) {
        print("Completing pending purchase...");
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  void _deliverProduct(PurchaseDetails purchaseDetails) async {
    print("Delivering product for purchase: ${purchaseDetails.productID}");
    // Get the current user.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print("User found: ${user.uid}, updating Firestore...");
      // Update Firebase user document to mark subscription as active.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'subscribed': true});
      // Optionally: call a method or notify your UserDataProvider to update its state.
    } else {
      print("No user is signed in.");
    }
    print('Subscription activated successfully!');
  }

  /// Initiate a purchase for a given product.
  Future<void> purchaseProduct(ProductDetails productDetails) async {
    print("Initiating purchase for product: ${productDetails.id}");
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Dispose the purchase subscription when no longer needed.
  void dispose() {
    _subscription?.cancel();
  }
}
