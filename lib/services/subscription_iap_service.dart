import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/utils/user_id.dart';

Set<String> get kPremiumProductIds {
  final monthly = dotenv.env['IAP_PRODUCT_MONTHLY'];
  final yearly = dotenv.env['IAP_PRODUCT_YEARLY'];

  final ids = <String>{};
  if (monthly != null && monthly.isNotEmpty) ids.add(monthly);
  if (yearly != null && yearly.isNotEmpty) ids.add(yearly);

  if (ids.isEmpty) {
    ids.addAll({
      'com.share.transfer.file.all.data.app.premium.monthly',
      'com.share.transfer.file.all.data.app.premium.yearly',
    });
  }

  return ids;
}

class PremiumPlan {
  final String id;
  final String title;
  final String description;
  final String price;

  const PremiumPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });
}

class SubscriptionIAPService {
  SubscriptionIAPService._internal();

  static final SubscriptionIAPService _instance =
      SubscriptionIAPService._internal();

  factory SubscriptionIAPService() => _instance;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isPremium = false;

  /// Cached premium flag from remote (Firestore / SharedPreferences).
  /// This lets us respect Pro status even before a purchase event occurs
  /// in the current session.
  bool _cachedPremium = false;

  bool get isPremium => _isPremium || _cachedPremium;

  /// Called from PremiumController / startup to sync remote premium status.
  void setCachedPremium(bool value) {
    _cachedPremium = value;
  }

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  Future<void> init() async {
    debugPrint('[SubscriptionIAP] init: starting...');
    isLoading.value = true;
    final available = await _inAppPurchase.isAvailable();
    _isAvailable = available;
    debugPrint('[SubscriptionIAP] init: isAvailable=$available');
    if (!available) {
      debugPrint('[SubscriptionIAP] init: aborting (IAP not available)');
      isLoading.value = false;
      return;
    }

    _subscription ??=
        _inAppPurchase.purchaseStream.listen(_onPurchaseUpdated, onError: (e) {
      debugPrint('[SubscriptionIAP] purchaseStream error: $e');
    }, onDone: () {
      debugPrint('[SubscriptionIAP] purchaseStream done');
      _subscription?.cancel();
    });
    debugPrint('[SubscriptionIAP] init: purchase stream listener attached');

    await _loadProducts();
    debugPrint('[SubscriptionIAP] init: completed (products count: ${_products.length})');
    isLoading.value = false;
  }

  Future<void> _loadProducts() async {
    debugPrint('[SubscriptionIAP] _loadProducts: querying product IDs: $kPremiumProductIds');
    final response = await _inAppPurchase.queryProductDetails(
      kPremiumProductIds,
    );

    if (response.error != null) {
      debugPrint('[SubscriptionIAP] _loadProducts: query error: ${response.error}');
      return;
    }

    _products = response.productDetails;
    debugPrint('[SubscriptionIAP] _loadProducts: fetched ${_products.length} product(s): ${_products.map((p) => p.id).toList()}');
  }

  PremiumPlan? planForId(String id) {
    final product = _products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    if (product == null) return null;

    return PremiumPlan(
      id: product.id,
      title: product.title,
      description: product.description,
      price: product.price,
    );
  }

  Future<void> buy(String productId) async {
    debugPrint('[SubscriptionIAP] buy: productId=$productId, isAvailable=$_isAvailable');
    if (!_isAvailable) {
      debugPrint('[SubscriptionIAP] buy: aborting (IAP not available)');
      return;
    }

    final product = _products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (product == null) {
      debugPrint('[SubscriptionIAP] buy: product not found: $productId (available: ${_products.map((p) => p.id).toList()})');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    debugPrint('[SubscriptionIAP] buy: starting purchase for ${product.id}');
    isLoading.value = true;
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('[SubscriptionIAP] buy: buyNonConsumable returned (result will come via purchase stream)');
    } catch (e, st) {
      debugPrint('[SubscriptionIAP] buy: exception: $e');
      debugPrint('[SubscriptionIAP] buy: stackTrace: $st');
      isLoading.value = false;
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    debugPrint('[SubscriptionIAP] restorePurchases: starting, isAvailable=$_isAvailable');
    if (!_isAvailable) {
      debugPrint('[SubscriptionIAP] restorePurchases: aborting (IAP not available)');
      return;
    }
    await _inAppPurchase.restorePurchases();
    debugPrint('[SubscriptionIAP] restorePurchases: restore call completed (results via purchase stream)');
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    debugPrint('[SubscriptionIAP] _onPurchaseUpdated: received ${purchaseDetailsList.length} update(s)');
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('[SubscriptionIAP] _onPurchaseUpdated: productId=${purchaseDetails.productID}, status=${purchaseDetails.status}');
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: status=PENDING');
          isLoading.value = true;
          break;
        case PurchaseStatus.purchased:
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: status=PURCHASED, verifying with backend...');
          final isValid = await _verifyPurchaseWithBackend(purchaseDetails);
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: verification result isValid=$isValid');
          if (isValid) {
            _isPremium = true;
            debugPrint('[SubscriptionIAP] _onPurchaseUpdated: success — premium granted');
            // Real-time UI update: refresh Firestore status so premium page updates immediately.
            if (Get.isRegistered<PremiumController>()) {
              await Get.find<PremiumController>().refreshSubscriptionStatus();
            }
          } else {
            debugPrint('[SubscriptionIAP] _onPurchaseUpdated: verification failed — premium not granted');
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
            debugPrint('[SubscriptionIAP] _onPurchaseUpdated: purchase completed');
          }
          isLoading.value = false;
          break;
        case PurchaseStatus.restored:
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: status=RESTORED, verifying with backend...');
          final isValid = await _verifyPurchaseWithBackend(purchaseDetails, isRestore: true);
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: restore verification isValid=$isValid');
          if (isValid) {
            _isPremium = true;
            debugPrint('[SubscriptionIAP] _onPurchaseUpdated: restore success — premium granted');
            // Real-time UI update: refresh Firestore status so premium page updates immediately (like buy flow).
            if (Get.isRegistered<PremiumController>()) {
              await Get.find<PremiumController>().refreshSubscriptionStatus();
            }
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          isLoading.value = false;
          break;
        case PurchaseStatus.error:
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: status=ERROR: ${purchaseDetails.error}');
          isLoading.value = false;
          break;
        case PurchaseStatus.canceled:
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: status=CANCELED (user cancelled)');
          isLoading.value = false;
          break;
        default:
          debugPrint('[SubscriptionIAP] _onPurchaseUpdated: status=OTHER (${purchaseDetails.status})');
          isLoading.value = false;
          break;
      }
    }
  }

  /// Retries getToken() so APNS can become ready on iOS. Ensures notification + Firestore data both work.
  static Future<String?> _getFcmTokenWithRetry({int maxAttempts = 3, Duration delay = const Duration(seconds: 2)}) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('[SubscriptionIAP] _getFcmTokenWithRetry: token obtained on attempt $attempt');
          return token;
        }
      } catch (e) {
        debugPrint('[SubscriptionIAP] _getFcmTokenWithRetry: attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          await Future<void>.delayed(delay);
        }
      }
    }
    debugPrint('[SubscriptionIAP] _getFcmTokenWithRetry: no token after $maxAttempts attempts');
    return null;
  }

  Future<bool> _verifyPurchaseWithBackend(
    PurchaseDetails purchaseDetails, {
    bool isRestore = false,
  }) async {
    debugPrint('[SubscriptionIAP] _verifyPurchaseWithBackend: productId=${purchaseDetails.productID}, isRestore=$isRestore');
    try {
      final receiptData =
          purchaseDetails.verificationData.serverVerificationData;
      final userId = await getOrCreateUserId();
      // Retry getToken() so APNS can become ready (iOS). Ensures notification + data both work.
      String? fcmToken = await _getFcmTokenWithRetry();

      final functionUrl = dotenv.env['CLOUD_FUNCTION_URL'];
      if (functionUrl == null || functionUrl.isEmpty) {
        debugPrint(
          '[SubscriptionIAP] _verifyPurchaseWithBackend: CLOUD_FUNCTION_URL missing in .env',
        );
        return false;
      }

      final uri = Uri.parse(functionUrl);

      final body = <String, dynamic>{
        'receiptData': receiptData,
        'productId': purchaseDetails.productID,
        'userId': userId,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        if (isRestore) 'isRestore': true,
      };

      final response = await http.post(
        uri,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[SubscriptionIAP] _verifyPurchaseWithBackend: failed status=${response.statusCode} body=${response.body}',
        );
        return false;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final isValid = decoded['isValid'] == true;
      debugPrint('[SubscriptionIAP] _verifyPurchaseWithBackend: decoded isValid=$isValid');
      return isValid;
    } catch (e, st) {
      debugPrint('[SubscriptionIAP] _verifyPurchaseWithBackend: exception: $e');
      debugPrint('[SubscriptionIAP] _verifyPurchaseWithBackend: stackTrace: $st');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    isLoading.dispose();
  }
}
