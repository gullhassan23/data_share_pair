import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        .collection('users')
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

  Future<void> restorePurchases() async {
    await iapService.restorePurchases();
  }

  @override
  void onClose() {
    _firestoreSub?.cancel();
    super.onClose();
  }
}
