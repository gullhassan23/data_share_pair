abstract class AppRoutes {
  static const splash = '/splash';
  static const onboaring = '/onboaring';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const pairing = '/pairing';
  static const connectionMethod = '/connection-method';
  static const qrSender = '/send-scan-qr'; // Sender scans QR
  static const qrReceiver = '/receive-show-qr'; // Receiver shows QR
  static const transferProgress = '/transfer-progress';
  static const transferRecovery = '/transfer-recovery';
  static const transferFile = '/transfer-file';
  static const chooseMethod = '/choose-method';
  static const receivedFiles = '/received-files';
  static const choosemethodscan = '/choose-method-scan';
  static const removeDuplicates = '/remove-duplicates';
  static const duplicatePreview = '/duplicate-preview';
  static const premium = '/premium';
  static const configuration = '/configuration';

  /// Used with Get.to(..., routeName: ...) so analytics matches named flows.
  static const bluetoothReceiver = '/bluetooth-receiver';
  static const bluetoothSender = '/bluetooth-sender';
  static const selectDevice = '/select-device';
  static const transferComplete = '/transfer-complete';
  static const contactsSelection = '/contacts-selection';
  static const howItWorks = '/how-it-works';
}
