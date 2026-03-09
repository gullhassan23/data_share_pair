import 'package:flutter/material.dart';
import 'package:share_app_latest/components/app_dialog.dart';

class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(error),
    );
  }
}

class CenterTextShow extends StatelessWidget {
  final String title;
  const CenterTextShow({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}

void showMessageDialog(
  BuildContext context,
  String message, {
  String title = '',
}) {
  showAppDialog<void>(
    title: title.isNotEmpty ? title : 'Message',
    message: message,
    barrierDismissible: true,
  );
}

