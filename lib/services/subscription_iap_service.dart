import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/utils/user_id.dart';
import 'package:share_app_latest/services/adapty_service.dart';
import 'package:share_app_latest/services/premium_status_store.dart';
import 'package:share_app_latest/services/subscription_revenue_policy.dart';
import 'package:share_app_latest/services/subscription_analytics_report_store.dart';
import 'package:share_app_latest/utils/release_safe_log.dart';

/// Result of backend receipt verification.
class SubscriptionVerificationResult {
  const SubscriptionVerificationResult({
    required this.isValid,
    this.verifiedByApple,
    this.environment,
    this.appleStatus,
  });

  final bool isValid;
  /// `true` when Apple verifyReceipt succeeded (status 0). `false` for fallback.
  final bool? verifiedByApple;
  final String? environment;
  final int? appleStatus;
}

Set<String> get kPremiumProductIds {
  final isAndroid = Platform.isAndroid;
  final weekly =
      isAndroid
          ? dotenv.env['IAP_ANDROID_PRODUCT_WEEKLY']
          : dotenv.env['IAP_PRODUCT_WEEKLY'];
  final monthly =
      isAndroid
          ? dotenv.env['IAP_ANDROID_PRODUCT_MONTHLY']
          : dotenv.env['IAP_PRODUCT_MONTHLY'];
  final yearly =
      isAndroid
          ? dotenv.env['IAP_ANDROID_PRODUCT_YEARLY']
          : dotenv.env['IAP_PRODUCT_YEARLY'];

  final ids = <String>{};

  if (yearly != null && yearly.isNotEmpty) ids.add(yearly);
  if (monthly != null && monthly.isNotEmpty) ids.add(monthly);
  if (weekly != null && weekly.isNotEmpty) ids.add(weekly);

  if (ids.isEmpty) {
    iapDebugLog(
      '[SubscriptionIAP] Missing IAP product IDs in .env '
      '(IAP_PRODUCT_* / IAP_ANDROID_PRODUCT_*).',
    );
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

  /// Cached premium flag from remote (Firestore / SharedPreferences).
  /// This lets us respect Pro status even before a purchase event occurs
  /// in the current session.
  bool _cachedPremium = false;

  /// Reactive premium flag so non-GetX widgets can rebuild in real time.
  final ValueNotifier<bool> premiumListenable = ValueNotifier<bool>(false);

  /// Source of truth is the cached/remote premium flag.
  /// This ensures if Firestore flips to false, ads/features re-enable immediately.
  bool get isPremium => _cachedPremium;

  /// Called from PremiumController / startup to sync remote premium status.
  void setCachedPremium(bool value) {
    if (_cachedPremium == value) return;
    _cachedPremium = value;
    premiumListenable.value = value;
  }

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;
  final Set<String> _reportedPurchaseKeys = <String>{};

  Future<void> init() async {
    iapDebugLog('[SubscriptionIAP] init: starting...');
    isLoading.value = true;
    final available = await _inAppPurchase.isAvailable();
    _isAvailable = available;
    iapDebugLog('[SubscriptionIAP] init: isAvailable=$available');
    if (!available) {
      iapDebugLog('[SubscriptionIAP] init: aborting (IAP not available)');
      isLoading.value = false;
      return;
    }

    _subscription ??= _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) {
        iapDebugLog('[SubscriptionIAP] purchaseStream error: $e');
      },
      onDone: () {
        iapDebugLog('[SubscriptionIAP] purchaseStream done');
        _subscription?.cancel();
      },
    );
    iapDebugLog('[SubscriptionIAP] init: purchase stream listener attached');

    await _loadProducts();
    iapDebugLog(
      '[SubscriptionIAP] init: completed (products count: ${_products.length})',
    );
    isLoading.value = false;
  }

  Future<void> _loadProducts() async {
    iapDebugLog(
      '[SubscriptionIAP] _loadProducts: querying product IDs: $kPremiumProductIds',
    );
    final response = await _inAppPurchase.queryProductDetails(
      kPremiumProductIds,
    );

    if (response.error != null) {
      iapDebugLog(
        '[SubscriptionIAP] _loadProducts: query error: ${response.error}',
      );
      return;
    }

    _products = response.productDetails;
    iapDebugLog(
      '[SubscriptionIAP] _loadProducts: fetched ${_products.length} product(s): ${_products.map((p) => p.id).toList()}',
    );
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
    iapDebugLog(
      '[SubscriptionIAP] buy: productId=$productId, isAvailable=$_isAvailable',
    );
    if (!_isAvailable) {
      iapDebugLog('[SubscriptionIAP] buy: aborting (IAP not available)');
      return;
    }

    final product = _products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == productId,
      orElse: () => null,
    );
    if (product == null) {
      iapDebugLog(
        '[SubscriptionIAP] buy: product not found: $productId (available: ${_products.map((p) => p.id).toList()})',
      );
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    iapDebugLog('[SubscriptionIAP] buy: starting purchase for ${product.id}');
    isLoading.value = true;
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      iapDebugLog(
        '[SubscriptionIAP] buy: buyNonConsumable returned (result will come via purchase stream)',
      );
    } catch (e, st) {
      isLoading.value = false;
      final message = e.toString();
      if (message.contains('purchase_cancelled') ||
          message.contains('storekit2_purchase_cancelled')) {
        iapDebugLog('[SubscriptionIAP] buy: user cancelled purchase');
        return;
      }
      iapDebugLog('[SubscriptionIAP] buy: exception: $e');
      iapDebugLog('[SubscriptionIAP] buy: stackTrace: $st');
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    iapDebugLog(
      '[SubscriptionIAP] restorePurchases: starting, isAvailable=$_isAvailable',
    );
    if (!_isAvailable) {
      iapDebugLog(
        '[SubscriptionIAP] restorePurchases: aborting (IAP not available)',
      );
      return;
    }
    await _inAppPurchase.restorePurchases();
    iapDebugLog(
      '[SubscriptionIAP] restorePurchases: restore call completed (results via purchase stream)',
    );
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    iapDebugLog(
      '[SubscriptionIAP] _onPurchaseUpdated: received ${purchaseDetailsList.length} update(s)',
    );
    for (final purchaseDetails in purchaseDetailsList) {
      iapDebugLog(
        '[SubscriptionIAP] _onPurchaseUpdated: productId=${purchaseDetails.productID}, status=${purchaseDetails.status}',
      );
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          iapDebugLog('[SubscriptionIAP] _onPurchaseUpdated: status=PENDING');
          isLoading.value = true;
          break;
        case PurchaseStatus.purchased:
          iapDebugLog(
            '[SubscriptionIAP] _onPurchaseUpdated: status=PURCHASED, verifying with backend...',
          );
          final purchasedVerification =
              await _verifyPurchaseWithBackend(purchaseDetails);
          await _handleVerifiedPurchaseUpdate(
            purchaseDetails: purchaseDetails,
            verification: purchasedVerification,
            isRestoreFlow: false,
          );
          isLoading.value = false;
          break;
        case PurchaseStatus.restored:
          iapDebugLog(
            '[SubscriptionIAP] _onPurchaseUpdated: status=RESTORED, verifying with backend...',
          );
          final restoredVerification = await _verifyPurchaseWithBackend(
            purchaseDetails,
            isRestore: true,
          );
          await _handleVerifiedPurchaseUpdate(
            purchaseDetails: purchaseDetails,
            verification: restoredVerification,
            isRestoreFlow: true,
          );
          isLoading.value = false;
          break;
        case PurchaseStatus.error:
          iapDebugLog(
            '[SubscriptionIAP] _onPurchaseUpdated: status=ERROR: ${purchaseDetails.error}',
          );
          isLoading.value = false;
          break;
        case PurchaseStatus.canceled:
          iapDebugLog(
            '[SubscriptionIAP] _onPurchaseUpdated: status=CANCELED (user cancelled)',
          );
          isLoading.value = false;
          break;
        // ignore: unreachable_switch_default
        default:
          iapDebugLog(
            '[SubscriptionIAP] _onPurchaseUpdated: status=OTHER (${purchaseDetails.status})',
          );
          isLoading.value = false;
          break;
      }
    }
  }

  /// Retries getToken() so APNS can become ready on iOS. Ensures notification + Firestore data both work.
  static Future<String?> _getFcmTokenWithRetry({
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          iapDebugLog(
            '[SubscriptionIAP] _getFcmTokenWithRetry: token obtained on attempt $attempt',
          );
          return token;
        }
      } catch (e) {
        iapDebugLog(
          '[SubscriptionIAP] _getFcmTokenWithRetry: attempt $attempt failed: $e',
        );
        if (attempt < maxAttempts) {
          await Future<void>.delayed(delay);
        }
      }
    }
    iapDebugLog(
      '[SubscriptionIAP] _getFcmTokenWithRetry: no token after $maxAttempts attempts',
    );
    return null;
  }

  /// StoreKit 2 sends a JWS in [serverVerificationData]; legacy verifyReceipt needs
  /// the App Store unified receipt (base64). Refresh when JWS is detected.
  Future<Map<String, String>> _resolveAppleVerificationPayload(
    PurchaseDetails purchaseDetails,
  ) async {
    final serverData =
        purchaseDetails.verificationData.serverVerificationData.trim();

    if (!Platform.isIOS) {
      return {'receiptData': serverData};
    }

    final isJws =
        serverData.startsWith('eyJ') && serverData.split('.').length == 3;
    if (!isJws) {
      return {'receiptData': serverData};
    }

    iapDebugLog(
      '[SubscriptionIAP] StoreKit2 JWS detected — refreshing App Store receipt',
    );

    String? appReceipt;
    try {
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      final refreshed = await addition.refreshPurchaseVerificationData();
      final refreshedReceipt = refreshed?.serverVerificationData.trim() ?? '';
      if (refreshedReceipt.isNotEmpty &&
          !refreshedReceipt.startsWith('eyJ')) {
        appReceipt = refreshedReceipt;
        iapDebugLog('[SubscriptionIAP] refreshed App Store receipt obtained');
      }
    } catch (e) {
      iapDebugLog(
        '[SubscriptionIAP] refreshPurchaseVerificationData failed: $e',
      );
    }

    return {
      'receiptData': appReceipt ?? serverData,
      if (isJws) 'jwsRepresentation': serverData,
      if (purchaseDetails.purchaseID != null &&
          purchaseDetails.purchaseID!.isNotEmpty)
        'transactionId': purchaseDetails.purchaseID!,
    };
  }

  Future<SubscriptionVerificationResult> _verifyPurchaseWithBackend(
    PurchaseDetails purchaseDetails, {
    bool isRestore = false,
  }) async {
    iapDebugLog(
      '[SubscriptionIAP] _verifyPurchaseWithBackend: productId=${purchaseDetails.productID}, isRestore=$isRestore',
    );
    try {
      final applePayload = await _resolveAppleVerificationPayload(purchaseDetails);
      final receiptData = applePayload['receiptData'] ?? '';
      final userId = await getOrCreateUserId();
      // Retry getToken() so APNS can become ready (iOS). Ensures notification + data both work.
      String? fcmToken = await _getFcmTokenWithRetry();

      final functionUrl = dotenv.env['CLOUD_FUNCTION_URL'];
      if (functionUrl == null || functionUrl.isEmpty) {
        iapDebugLog(
          '[RevenueFix] reason=missing_cloud_function_url',
        );
        iapDebugLog(
          '[SubscriptionIAP] _verifyPurchaseWithBackend: CLOUD_FUNCTION_URL missing in .env',
        );
        return const SubscriptionVerificationResult(
          isValid: false,
          verifiedByApple: false,
        );
      }

      final uri = Uri.parse(functionUrl);

      final body = <String, dynamic>{
        'receiptData': receiptData,
        'productId': purchaseDetails.productID,
        'userId': userId,
        if (applePayload['jwsRepresentation'] != null)
          'jwsRepresentation': applePayload['jwsRepresentation'],
        if (applePayload['transactionId'] != null)
          'transactionId': applePayload['transactionId'],
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        if (isRestore) 'isRestore': true,
      };

      final response = await http.post(
        uri,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        iapDebugLog(
          '[RevenueFix] reason=backend_http_error '
          'status=${response.statusCode} body=${response.body}',
        );
        iapDebugLog(
          '[SubscriptionIAP] _verifyPurchaseWithBackend: failed status=${response.statusCode} body=${response.body}',
        );
        return const SubscriptionVerificationResult(
          isValid: false,
          verifiedByApple: false,
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final isValid = decoded['isValid'] == true;
      final environment = decoded['environment'] as String?;
      final verifiedRaw = decoded['verified'];
      final bool? verifiedByApple =
          verifiedRaw is bool ? verifiedRaw : (isValid ? true : false);
      final appleStatus = decoded['appleStatus'] is int
          ? decoded['appleStatus'] as int
          : null;
      iapDebugLog(
        '[RevenueFix] backend_response '
        'isValid=$isValid verifiedByApple=$verifiedByApple '
        'environment=$environment appleStatus=$appleStatus',
      );
      iapDebugLog(
        '[SubscriptionIAP] _verifyPurchaseWithBackend: decoded isValid=$isValid '
        'verifiedByApple=$verifiedByApple environment=$environment',
      );
      return SubscriptionVerificationResult(
        isValid: isValid,
        verifiedByApple: verifiedByApple,
        environment: environment,
        appleStatus: appleStatus,
      );
    } catch (e, st) {
      iapDebugLog(
        '[RevenueFix] reason=backend_exception error=$e',
      );
      iapDebugLog('[SubscriptionIAP] _verifyPurchaseWithBackend: exception: $e');
      iapDebugLog(
        '[SubscriptionIAP] _verifyPurchaseWithBackend: stackTrace: $st',
      );
      return const SubscriptionVerificationResult(
        isValid: false,
        verifiedByApple: false,
      );
    }
  }

  Future<void> _handleVerifiedPurchaseUpdate({
    required PurchaseDetails purchaseDetails,
    required SubscriptionVerificationResult verification,
    required bool isRestoreFlow,
  }) async {
    final sandboxReporting = reportSandboxRevenueToFirebase();
    final revenueDecision = evaluatePurchaseRevenue(
      isValid: verification.isValid,
      isRestore: isRestoreFlow,
      environment: verification.environment,
      productId: purchaseDetails.productID,
      transactionId: purchaseDetails.purchaseID,
      verifiedByApple: verification.verifiedByApple,
      isAndroid: Platform.isAndroid,
      reportSandboxRevenue: sandboxReporting,
    );

    iapDebugLog(
      '[SubscriptionIAP] _onPurchaseUpdated: verification isValid=${verification.isValid} '
      'verifiedByApple=${verification.verifiedByApple} '
      'environment=${verification.environment} '
      'isRestoreFlow=$isRestoreFlow '
      'reportSandboxRevenue=$sandboxReporting '
      'reportRevenue=${revenueDecision.shouldReport}',
    );

    SubscriptionAnalyticsReportStore.instance.recordVerification(
      isValid: verification.isValid,
      verifiedByApple: verification.verifiedByApple,
      environment: verification.environment,
      productId: purchaseDetails.productID,
      transactionId: purchaseDetails.purchaseID,
      willReportRevenue: verification.isValid && revenueDecision.shouldReport,
      skipReason: revenueDecision.skipReason,
      isRestoreFlow: isRestoreFlow,
    );

    if (verification.isValid) {
      setCachedPremium(true);
      await PremiumStatusStore.saveIsPremium(true);

      if (revenueDecision.shouldReport) {
        iapDebugLog(
          '[FirebaseAnalytics] ▶ WILL REPORT to Firebase '
          '(revenue + subscription_purchase_detail event) '
          'productId=${purchaseDetails.productID} '
          'environment=${verification.environment ?? "null"} '
          'sandboxReporting=$sandboxReporting',
        );
        iapDebugLog(
          '[RevenueFix] reporting revenue productId=${purchaseDetails.productID} '
          'environment=${verification.environment ?? "null"} '
          'sandboxReporting=$sandboxReporting',
        );
        await _reportSubscriptionRevenueToFirebase(
          purchaseDetails,
          verification: verification,
          purchaseStatus:
              isRestoreFlow ? 'restored' : purchaseDetails.status.name,
        );
      } else {
        iapDebugLog(
          '[FirebaseAnalytics] ✗ SKIPPED — revenue and event will NOT go to Firebase '
          'reason=${revenueDecision.skipReason}',
        );
        iapDebugLog(
          '[RevenueFix] reason=${revenueDecision.skipReason} '
          'isValid=${verification.isValid} '
          'verifiedByApple=${verification.verifiedByApple} '
          'environment=${verification.environment ?? "null"} '
          'productId=${purchaseDetails.productID} '
          'transactionId=${purchaseDetails.purchaseID ?? "null"} '
          'reportSandboxRevenue=$sandboxReporting',
        );
        iapDebugLog(
          '[SubscriptionIAP] _onPurchaseUpdated: skipping Firebase revenue '
          '(reason=${revenueDecision.skipReason})',
        );
      }

      iapDebugLog(
        '[SubscriptionIAP] _onPurchaseUpdated: success — premium granted',
      );

      if (Get.isRegistered<PremiumController>()) {
        final c = Get.find<PremiumController>();
        c.subscriptionStatus.value = SubscriptionStatus(
          isPremium: true,
          productId: purchaseDetails.productID,
          expiryDate: c.subscriptionStatus.value?.expiryDate,
        );
        await Get.find<PremiumController>().refreshSubscriptionStatus();
      }
    } else {
      iapDebugLog(
        '[SubscriptionIAP] _onPurchaseUpdated: verification failed — premium not granted',
      );
    }

    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
      iapDebugLog('[SubscriptionIAP] _onPurchaseUpdated: purchase completed');
    }

    if (verification.isValid) {
      unawaited(
        AdaptyService.instance.syncAfterPurchaseOrRestore(
          purchaseDetails: purchaseDetails,
        ),
      );
    }
  }

  Future<void> _reportSubscriptionRevenueToFirebase(
    PurchaseDetails purchaseDetails, {
    SubscriptionVerificationResult? verification,
    String? purchaseStatus,
  }) async {
    iapDebugLog(
      '[RevenueFix] _reportSubscriptionRevenueToFirebase: enter '
      'productId=${purchaseDetails.productID} '
      'transactionId=${purchaseDetails.purchaseID ?? "null"} '
      'cachedProducts=${_products.map((p) => p.id).toList()}',
    );
    ProductDetails? product = _products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == purchaseDetails.productID,
      orElse: () => null,
    );
    if (product == null) {
      iapDebugLog(
        '[RevenueFix] reason=missing_product retrying product query '
        'productId=${purchaseDetails.productID}',
      );
      await _loadProducts();
      product = _products.cast<ProductDetails?>().firstWhere(
        (p) => p?.id == purchaseDetails.productID,
        orElse: () => null,
      );
    }
    if (product == null) {
      iapDebugLog(
        '[FirebaseAnalytics] ✗ SKIPPED — product not found, revenue/event NOT sent '
        'productId=${purchaseDetails.productID} '
        'available=${_products.map((p) => p.id).toList()}',
      );
      iapDebugLog(
        '[RevenueFix] reason=missing_product '
        'productId=${purchaseDetails.productID} '
        'available=${_products.map((p) => p.id).toList()}',
      );
      iapDebugLog(
        '[SubscriptionIAP] _reportSubscriptionRevenueToFirebase: product not found for ${purchaseDetails.productID}',
      );
      SubscriptionAnalyticsReportStore.instance.recordSkipped(
        reason: 'missing_product',
      );
      return;
    }

    final transactionId = purchaseDetails.purchaseID;
    if (transactionId == null || transactionId.isEmpty) {
      iapDebugLog(
        '[FirebaseAnalytics] ✗ SKIPPED — missing transactionId, revenue/event NOT sent '
        'productId=${purchaseDetails.productID}',
      );
      iapDebugLog(
        '[RevenueFix] reason=missing_transaction_id '
        'productId=${purchaseDetails.productID}',
      );
      SubscriptionAnalyticsReportStore.instance.recordSkipped(
        reason: 'missing_transaction_id',
      );
      return;
    }

    final purchaseKey = '${purchaseDetails.productID}:$transactionId';
    if (_reportedPurchaseKeys.contains(purchaseKey)) {
      iapDebugLog(
        '[FirebaseAnalytics] ✗ SKIPPED — duplicate purchase, already reported '
        'purchaseKey=$purchaseKey',
      );
      iapDebugLog(
        '[RevenueFix] reason=duplicate_purchase purchaseKey=$purchaseKey',
      );
      SubscriptionAnalyticsReportStore.instance.recordSkipped(
        reason: 'duplicate_purchase',
      );
      return;
    }

    final environment = verification?.environment ?? 'unknown';
    final isSandboxTest = environment == 'sandbox';
    final status = purchaseStatus ?? purchaseDetails.status.name;

    iapDebugLog(
      '[FirebaseAnalytics] Sending purchase revenue (logPurchase) ... '
      'productId=${product.id} value=${product.rawPrice} ${product.currencyCode} '
      'transactionId=$transactionId environment=$environment',
    );
    iapDebugLog(
      '[RevenueFix] FirebaseAnalytics.logPurchase: invoking '
      'productId=${product.id} title=${product.title} '
      'currency=${product.currencyCode} value=${product.rawPrice} '
      'price=${product.price} transactionId=$transactionId '
      'environment=$environment',
    );
    try {
      await FirebaseAnalytics.instance.logPurchase(
        currency: product.currencyCode,
        value: product.rawPrice,
        transactionId: transactionId,
        affiliation: environment,
        items: [
          AnalyticsEventItem(
            itemId: product.id,
            itemName: product.title,
            itemCategory: 'subscription',
            price: product.rawPrice,
            currency: product.currencyCode,
            quantity: 1,
          ),
        ],
      );

      iapDebugLog(
        '[FirebaseAnalytics] ✓ REVENUE SENT — event=purchase '
        'value=${product.rawPrice} currency=${product.currencyCode} '
        'transactionId=$transactionId affiliation=$environment',
      );
      SubscriptionAnalyticsReportStore.instance.recordRevenueSent(
        productId: product.id,
        transactionId: transactionId,
        value: product.rawPrice,
        currency: product.currencyCode,
        environment: environment,
      );

      final detailParams = <String, Object>{
        'product_id': product.id,
        'product_title': _truncateAnalyticsParam(product.title),
        'product_description': _truncateAnalyticsParam(product.description),
        'product_price_display': product.price,
        'product_price_raw': product.rawPrice,
        'product_currency': product.currencyCode,
        'transaction_id': transactionId,
        'purchase_environment': environment,
        'purchase_status': status,
        'verified_by_apple': verification?.verifiedByApple ?? false,
        'is_sandbox_test': isSandboxTest,
        'apple_status': verification?.appleStatus ?? -1,
      };

      iapDebugLog(
        '[FirebaseAnalytics] Sending custom event (subscription_purchase_detail) ... '
        'params=$detailParams',
      );

      await FirebaseAnalytics.instance.logEvent(
        name: 'subscription_purchase_detail',
        parameters: detailParams,
      );

      iapDebugLog(
        '[FirebaseAnalytics] ✓ EVENT SENT — event=subscription_purchase_detail '
        'productId=${product.id} environment=$environment isSandbox=$isSandboxTest',
      );
      SubscriptionAnalyticsReportStore.instance.recordEventSent(
        productId: product.id,
        transactionId: transactionId,
        environment: environment,
      );

      _reportedPurchaseKeys.add(purchaseKey);

      iapDebugLog(
        '[FirebaseAnalytics] ═══════════════════════════════════════',
      );
      iapDebugLog(
        '[FirebaseAnalytics] ✓✓ DONE — revenue + event both reported to Firebase',
      );
      iapDebugLog(
        '[FirebaseAnalytics]   Revenue  → purchase | '
        '${product.rawPrice} ${product.currencyCode} | tx=$transactionId',
      );
      iapDebugLog(
        '[FirebaseAnalytics]   Event    → subscription_purchase_detail | '
        'productId=${product.id} | env=$environment | status=$status',
      );
      iapDebugLog(
        '[FirebaseAnalytics]   Verify in Firebase Console → DebugView (realtime)',
      );
      iapDebugLog(
        '[FirebaseAnalytics] ═══════════════════════════════════════',
      );
      iapDebugLog(
        '[RevenueFix] FirebaseAnalytics.logPurchase: SUCCESS '
        'productId=${product.id} value=${product.rawPrice} ${product.currencyCode} '
        'environment=$environment purchaseKey=$purchaseKey',
      );
      iapDebugLog(
        '[SubscriptionIAP] _reportSubscriptionRevenueToFirebase: logged product=${product.id} value=${product.rawPrice} ${product.currencyCode}',
      );
    } catch (e, st) {
      iapDebugLog(
        '[FirebaseAnalytics] ✗ FAILED — Firebase revenue/event NOT reported error=$e',
      );
      SubscriptionAnalyticsReportStore.instance.recordFailed(error: e.toString());
      iapDebugLog(
        '[RevenueFix] reason=log_purchase_failed error=$e',
      );
      iapDebugLog(
        '[SubscriptionIAP] _reportSubscriptionRevenueToFirebase: failed: $e',
      );
      iapDebugLog(
        '[SubscriptionIAP] _reportSubscriptionRevenueToFirebase: stackTrace: $st',
      );
    }
  }

  static String _truncateAnalyticsParam(String value, {int maxLen = 99}) {
    if (value.length <= maxLen) return value;
    return value.substring(0, maxLen);
  }

  void dispose() {
    _subscription?.cancel();
    isLoading.dispose();
    premiumListenable.dispose();
  }
}
