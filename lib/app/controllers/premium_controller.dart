import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/utils/user_id.dart';

class SubscriptionStatus {
  final bool isPremium;
  final String? productId;
  final DateTime? expiryDate;

  const SubscriptionStatus({
    required this.isPremium,
    this.productId,
    this.expiryDate,
  });
}

class PremiumController extends GetxController {
  final SubscriptionIAPService iapService = SubscriptionIAPService();

  final Rxn<String> userId = Rxn<String>();
  final Rx<SubscriptionStatus?> subscriptionStatus =
      Rx<SubscriptionStatus?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isRestoring = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreSub;

  bool get isPremium => subscriptionStatus.value?.isPremium ?? false;

  @override
  void onInit() {
    super.onInit();
    _initUserId();
  }

  Future<void> _initUserId() async {
    try {
      final id = await getOrCreateUserId();
      userId.value = id;
      _listenToFirestore(id);
    } catch (e) {
      isLoading.value = false;
    }
  }

  void _listenToFirestore(String uid) {
    _firestoreSub?.cancel();
    _firestoreSub = FirebaseFirestore.instance
        .collection('UsersFileTransfer')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        subscriptionStatus.value = const SubscriptionStatus(isPremium: false);
      } else {
        final data = doc.data()!;
        subscriptionStatus.value = SubscriptionStatus(
          isPremium: data['isPremium'] == true,
          productId: data['productId'] as String?,
          expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
        );
      }
      isLoading.value = false;
    });
  }

  Future<void> buy(String productId) async {
    await iapService.buy(productId);
  }

  /// Fetches subscription status from Firestore once (used after restore so UI updates).
  Future<void> refreshSubscriptionStatus() async {
    final uid = userId.value;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('UsersFileTransfer')
          .doc(uid)
          .get();
      if (!doc.exists) {
        subscriptionStatus.value = const SubscriptionStatus(isPremium: false);
        return;
      }
      final data = doc.data()!;
      subscriptionStatus.value = SubscriptionStatus(
        isPremium: data['isPremium'] == true,
        productId: data['productId'] as String?,
        expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      // Keep current status on error
    }
  }

  Future<void> restorePurchases() async {
    if (isRestoring.value) return;
    isRestoring.value = true;
    try {
      await iapService.restorePurchases();
      // Backend updates Firestore asynchronously after verifying restored receipt.
      // Wait then refresh so the UI shows the updated premium status.
      await Future<void>.delayed(const Duration(seconds: 2));
      await refreshSubscriptionStatus();
      // Retry once more in case backend was slow
      if (!isPremium) {
        await Future<void>.delayed(const Duration(seconds: 2));
        await refreshSubscriptionStatus();
      }
      if (isPremium) {
        Get.snackbar(
          'Restore successful',
          'Your premium subscription has been restored.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xff1a1a24),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
        );
      } else {
        Get.snackbar(
          'Restore completed',
          'If you had a subscription, it has been restored. No active subscription found for this account.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xff1a1a24),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Restore failed',
        'Please try again. If the problem continues, contact support.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xff1a1a24),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isRestoring.value = false;
    }
  }

  @override
  void onClose() {
    _firestoreSub?.cancel();
    super.onClose();
  }
}
