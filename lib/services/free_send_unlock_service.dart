import 'package:get/get.dart';

/// Holds temporary "free send" credits earned by watching rewarded ads.
/// Each credit unlocks sender flow for a single successful send.
class FreeSendUnlockService extends GetxService {
  final RxInt _remainingCredits = 0.obs;

  bool get hasCredit => _remainingCredits.value > 0;

  void grantOneCredit() {
    _remainingCredits.value += 1;
  }

  void consumeOneCredit() {
    if (_remainingCredits.value <= 0) return;
    _remainingCredits.value -= 1;
  }
}
