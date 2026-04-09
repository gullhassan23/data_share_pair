import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_app_latest/app/views/configuration/how_it_works_screen.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings / Configuration — light gradient, Go Pro banner, and menu rows.
class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  static const Color _primaryBlue = Color(0xFF3B59FF);
  static const Color _orangeBadge = Color(0xFFFFB347);
  static const Color _textDark = Color(0xFF333333);

  static const Color _iconCircleFill = Color(0xFFE8EEFF);

  static const String _supportEmail = 'admin@maxgamesproduction.com';
  static const String _iosAppStoreId = '6759640831';

  Future<void> _shareAppLink(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final url =
        'https://apps.apple.com/us/app/share-all-file-transfer-app/id6759640831';
    final text = '${info.appName}\n$url';
    final box = context.findRenderObject() as RenderBox?;
    final Rect? origin =
        box != null
            ? Rect.fromLTWH(
              box.localToGlobal(Offset.zero).dx,
              box.localToGlobal(Offset.zero).dy,
              box.size.width,
              box.size.height,
            )
            : null;
    await Share.share(text, subject: info.appName, sharePositionOrigin: origin);
  }

  Future<void> _openFeedbackEmail(BuildContext context) async {
    // 1. Standard mailto URI (Most reliable)
    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('Feedback & Troubleshooting')}',
    );

    try {
      // Try launching the default mail app
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email app';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open mail app: $e')));
      }
    }
  }

  Future<void> _openRateUs(BuildContext context) async {
    int selectedStars = 5;
    final bool? shouldOpenStore = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy changes live as soon as user taps a star.
                        ...(() {
                          final content = _ratingContent(selectedStars);
                          const rateCta = 'RATE ON APP STORE';
                          return [
                            Text(
                              content.emoji,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              content.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              content.subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 17,
                                height: 1.25,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final bool filled = index < selectedStars;
                                return IconButton(
                                  onPressed: () {
                                    setDialogState(
                                      () => selectedStars = index + 1,
                                    );
                                  },
                                  splashRadius: 22,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minHeight: 40,
                                    minWidth: 40,
                                  ),
                                  icon: Icon(
                                    filled
                                        ? Icons.star_rounded
                                        : Icons.star_outline,
                                    size: 39,
                                    color:
                                        filled
                                            ? _primaryBlue
                                            : Colors.grey.shade400,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The best we can get :)',
                              style: GoogleFonts.roboto(
                                fontSize: 17,
                                color: _primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    () => Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  selectedStars == 5 ? rateCta : 'RATE',
                                  style: GoogleFonts.roboto(
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ];
                        })(),
                      ],
                    ),
                  ),
                ),
          ),
    );

    if (shouldOpenStore != true) {
      return;
    }

    await _openNativeReviewOrStore(context);
  }

  Future<void> _openNativeReviewOrStore(BuildContext context) async {
    final InAppReview inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return;
      }
      await inAppReview.openStoreListing(appStoreId: _iosAppStoreId);
      return;
    } catch (_) {
      final Uri appStoreUri = Uri.parse(
        'https://apps.apple.com/us/app/share-all-file-transfer-app/id$_iosAppStoreId',
      );
      if (await canLaunchUrl(appStoreUri)) {
        await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open store for rating')),
        );
      }
    }
  }

  _RatePopupContent _ratingContent(int stars) {
    if (stars == 4) {
      return const _RatePopupContent(
        emoji: '😀',
        title: 'Thanks! We like you too!',
        subtitle: 'Please leave us some feedback',
      );
    }
    if (stars >= 4) {
      return const _RatePopupContent(
        emoji: '🥰',
        title: 'Thanks! We like you too!',
        subtitle:
            'There is no better way to share your love for Castto than giving us a nice review!',
      );
    }
    return const _RatePopupContent(
      emoji: '😢',
      title: 'Oh, no!',
      subtitle: 'Please leave us some feedback',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    const SizedBox(height: 8),
                    _buildGoProBanner(),
                    const SizedBox(height: 18),
                    _buildMenuTile(
                      icon: "assets/icons/How to works.png",
                      label: 'How It Works',
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HowItWorksScreen(),
                            ),
                          ),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: "assets/icons/Share with family & friends.png",
                      label: 'Share with family & friends',
                      onTap: () => _shareAppLink(context),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      icon: "assets/icons/Rate Us.png",
                      label: 'Rate Us',
                      onTap: () => _openRateUs(context),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuTile(
                      leading: _feedbackIcon(),
                      label: 'Feedback & Troubleshooting',
                      onTap: () => _openFeedbackEmail(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 18, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => AppNavigator.back(),
              icon: Icon(Icons.arrow_back),
              label: Text(
                'Back',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          Text(
            'Configuration',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoProBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AppNavigator.toPremium(),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _orangeBadge,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Go Pro',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unlimited Transfers',
                        style: GoogleFonts.roboto(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Transfer anything, 0 resistance',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _ProBannerGraphic(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedbackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: _iconCircleFill,
        shape: BoxShape.circle,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: _primaryBlue, size: 22),
          Positioned(
            right: 8,
            bottom: 8,
            child: Icon(Icons.star, color: _primaryBlue, size: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    String? icon,
    Widget? leading,
    required String label,
    required VoidCallback onTap,
  }) {
    assert(icon != null || leading != null);
    final Widget left =
        leading ??
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _iconCircleFill,
            shape: BoxShape.circle,
          ),
          child: Image.asset(icon!),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  left,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White line-art style diamond + laurel + sparkles (matches reference layout).
class _ProBannerGraphic extends StatelessWidget {
  const _ProBannerGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 88,
      child: CustomPaint(painter: _ProBannerArtPainter()),
    );
  }
}

class _RatePopupContent {
  final String emoji;
  final String title;
  final String subtitle;

  const _RatePopupContent({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class _ProBannerArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;

    final fill =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    final cx = size.width * 0.42;
    final cy = size.height * 0.52;

    // Laurel-like arcs
    final leftArc =
        Path()..addArc(
          Rect.fromCircle(center: Offset(cx - 8, cy), radius: 28),
          2.1,
          1.25,
        );
    final rightArc =
        Path()..addArc(
          Rect.fromCircle(center: Offset(cx + 8, cy), radius: 28),
          0.35,
          -1.25,
        );
    canvas.drawPath(leftArc, stroke);
    canvas.drawPath(rightArc, stroke);

    // Diamond
    const dw = 18.0;
    const dh = 22.0;
    final diamond =
        Path()
          ..moveTo(cx, cy - dh)
          ..lineTo(cx + dw, cy)
          ..lineTo(cx, cy + dh)
          ..lineTo(cx - dw, cy)
          ..close();
    canvas.drawPath(diamond, fill);

    // Small sparkle crosses
    void drawPlus(Offset o, double s) {
      final p =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      canvas.drawLine(Offset(o.dx - s, o.dy), Offset(o.dx + s, o.dy), p);
      canvas.drawLine(Offset(o.dx, o.dy - s), Offset(o.dx, o.dy + s), p);
    }

    drawPlus(Offset(size.width * 0.78, size.height * 0.22), 3);
    drawPlus(Offset(size.width * 0.88, size.height * 0.55), 2.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
