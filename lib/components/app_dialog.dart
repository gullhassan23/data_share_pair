import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized app dialog used across the app to keep
/// all popups consistent in terms of shape, padding and typography.
Future<T?> showAppDialog<T>({
  required String title,
  String? message,
  Widget? body,
  String primaryLabel = 'OK',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  bool barrierDismissible = false,
  ButtonStyle? primaryButtonStyle,
  ButtonStyle? secondaryButtonStyle,
}) {
  final theme = Get.context?.theme ?? ThemeData.light();

  return Get.dialog<T>(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (message != null && message.isNotEmpty)
                Text(
                  message,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
              if (body != null) ...[
                if (message != null && message.isNotEmpty)
                  const SizedBox(height: 16)
                else
                  const SizedBox(height: 8),
                body,
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryLabel != null && secondaryLabel.isNotEmpty)
                    TextButton(
                      style: secondaryButtonStyle,
                      onPressed: () {
                        Get.back<T>();
                        onSecondary?.call();
                      },
                      child: Text(
                        secondaryLabel,
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: primaryButtonStyle ??
                        ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                    onPressed: () {
                      Get.back<T>();
                      onPrimary?.call();
                    },
                    child: Text(
                      primaryLabel,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    barrierDismissible: barrierDismissible,
  );
}

