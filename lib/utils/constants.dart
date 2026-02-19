import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}

enum SendMode { bluetooth, scanner }

enum TransferRole { sender, receiver }

enum BluetoothMode { sender, receiver }

enum TransferSessionState {
  idle,
  pairing,
  waiting,
  connected,
  transferring,
  completed,
  error,
}

const int kTransferFlowTotalSteps = 7;
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024)
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String getDisplayName(BluetoothDevice d) {
  if (d.name.trim().isNotEmpty) return d.name.trim();
  if (d.platformName.trim().isNotEmpty) return d.platformName.trim();
  return d.remoteId.str;
}
