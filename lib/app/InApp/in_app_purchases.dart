import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  bool available = false;
  List<ProductDetails> products = [];
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  /// Initialize IAP
  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) {
      debugPrint('IAP not available');
      return;
    }

    // Listen for purchase updates
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint('Purchase Stream Error: $error');
      },
    );
  }

  /// Query product from store
  Future<void> loadProducts() async {
    const ids = {'premium_file_transfer'};
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      debugPrint('Product query error: ${response.error}');
    } else if (response.productDetails.isEmpty) {
      debugPrint('No products found');
    } else {
      products = response.productDetails;
    }
  }

  /// Buy a product
  Future<void> buyProduct(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    if (product.id == 'premium_file_transfer') {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Handle purchase updates
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        debugPrint('Purchased: ${purchase.productID}');
        await _deliverProduct(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase Error: ${purchase.error}');
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Unlock feature
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    if (purchase.productID == 'premium_file_transfer') {
      // TODO: Unlock premium file transfer feature
      debugPrint('Premium File Transfer Unlocked!');
      // You can save in SharedPreferences
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
