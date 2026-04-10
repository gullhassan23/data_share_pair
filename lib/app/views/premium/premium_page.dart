import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/admob_service.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Premium subscription screen – dark theme, gradient accents, file-transfer focused content.
/// Pro: Wi‑Fi transfer (unlimited, fast, no server), no ads, priority support.
class PremiumPage extends GetView<PremiumController> {
  const PremiumPage({super.key});

  @override
  String? get tag => null;

  static const Color _bgDark = Color(0xff12121a);
  static const Color _cardUnselected = Color(0xff1a1a24);
  static const Color _cyan = Color(0xff22d3ee);
  static const Color _purple = Color(0xffa855f7);

  static const double _screenPaddingH = 24;
  static const double _sectionSpacing = 20;
  static const double _titleBottom = 28;
  static const double _benefitsBottom = 28;
  static const double _footerTop = 20;
  static const double _footerBottom = 32;
  static const double _screenVerticalPadding = 13;

  @override
  Widget build(BuildContext context) {
    // Obx for GetX reactive state + ValueListenableBuilder for IAP loading state.
    return Obx(() {
      final iapService = controller.iapService;
      final isPremium = controller.isPremium || iapService.isPremium;

      final monthlyId =
          dotenv.env['IAP_PRODUCT_MONTHLY'] ??
          'com.share.transfer.file.all.data.app.premium.monthly';
      final weeklyId =
          dotenv.env['IAP_PRODUCT_WEEKLY'] ??
          'com.share.transfer.file.all.data.app.premium.weekly';
      final yearlyId =
          dotenv.env['IAP_PRODUCT_YEARLY'] ??
          'com.share.transfer.file.all.data.app.premium.yearly';
      final monthlyPlan = iapService.planForId(monthlyId);
      final weeklyPlan = iapService.planForId(weeklyId);
      final yearlyPlan = iapService.planForId(yearlyId);

      return ValueListenableBuilder<bool>(
        valueListenable: iapService.isLoading,
        builder: (context, isLoading, _) {
          final disableActions = isLoading || controller.isRestoring.value;

          return Scaffold(
            backgroundColor: _bgDark,
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(color: _bgDark),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(
                      context,
                      showCloseInHeader:
                          !iapService.isAvailable || isLoading || isPremium,
                    ),
                    if (!iapService.isAvailable) ...[
                      if (isLoading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(color: _cyan),
                          ),
                        )
                      else
                        const Expanded(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                'In-App Purchases are not available on this device.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                    ] else if (isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: _cyan),
                        ),
                      )
                    else if (isPremium)
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: _screenPaddingH,
                            vertical: _screenVerticalPadding,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.of(context).size.height * 0.6,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.workspace_premium,
                                    color: _cyan,
                                    size: 72,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'You are Premium!',
                                    style: GoogleFonts.roboto(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Wi‑Fi transfer, no ads & all Pro features unlocked.',
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: _screenPaddingH,
                            vertical: _screenVerticalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: _sectionSpacing),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed:
                                        disableActions
                                            ? null
                                            : () async {
                                              await AdMobService.instance
                                                  .showInterstitial();
                                              AppNavigator.back();
                                            },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                              _buildTitle(),
                              const SizedBox(height: _titleBottom),
                              _buildBenefits(),
                              const SizedBox(height: _benefitsBottom),
                              _PremiumPlansSection(
                                monthlyId: monthlyId,
                                weeklyId: weeklyId,
                                yearlyId: yearlyId,
                                monthlyPlan: monthlyPlan,
                                weeklyPlan: weeklyPlan,
                                yearlyPlan: yearlyPlan,
                                isDisabled: disableActions,
                                onBuy: controller.buy,
                              ),
                              const SizedBox(height: _sectionSpacing),
                              _buildRestoreLink(
                                onRestore:
                                    disableActions
                                        ? () {}
                                        : controller.restorePurchases,
                                isRestoring: controller.isRestoring.value,
                              ),
                              const SizedBox(height: _footerTop),
                              _buildFooter(context),
                              const SizedBox(height: _footerBottom),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildHeader(BuildContext context, {required bool showCloseInHeader}) {
    if (!showCloseInHeader) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () async {
              await AdMobService.instance.showInterstitial();
              AppNavigator.back();
            },
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback:
          (bounds) => const LinearGradient(
            colors: [_cyan, _purple],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
      child: Text(
        'UNLOCK PRO\nFILE TRANSFER',
        style: GoogleFonts.roboto(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          height: 1.25,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBenefits() {
    const items = [
      'Share files between iOS and Android devices without limits.',
      'Connect instantly via QR code and transfer files smoothly over the same Wi-Fi network.',
      'Enjoy a clean, ad-free experience without interruptions.',
      'Files are sent directly between your devices with a secure connection.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: _cyan, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          e,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildRestoreLink({
    required VoidCallback onRestore,
    required bool isRestoring,
  }) {
    return Center(
      child:
          isRestoring
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _cyan,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Restoring purchases…',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              )
              : TextButton(
                onPressed: onRestore,
                child: Text(
                  'RESTORE PURCHASES',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
              ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final privacy =
        dotenv.env['PRIVACY_POLICY_URL'] ??
        'https://maxgamesproduction.blogspot.com/2023/01/privacy-policy.html';
    final terms =
        dotenv.env['TERMS_OF_USE_URL'] ??
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

    Future<void> _open(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 16, color: Colors.white38),
            const SizedBox(width: 6),
            Text(
              'Secured with Apple',
              style: GoogleFonts.roboto(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _open(privacy),
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              '  |  ',
              style: GoogleFonts.roboto(fontSize: 11, color: Colors.white38),
            ),
            InkWell(
              onTap: () => _open(terms),
              child: Text(
                'Terms of Use',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumPlansSection extends StatefulWidget {
  final String monthlyId;
  final String weeklyId;
  final String yearlyId;
  final PremiumPlan? monthlyPlan;
  final PremiumPlan? weeklyPlan;
  final PremiumPlan? yearlyPlan;
  final bool isDisabled;
  final void Function(String) onBuy;

  const _PremiumPlansSection({
    required this.monthlyId,
    required this.weeklyId,
    required this.yearlyId,
    this.monthlyPlan,
    this.weeklyPlan,
    this.yearlyPlan,
    required this.isDisabled,
    required this.onBuy,
  });

  @override
  State<_PremiumPlansSection> createState() => _PremiumPlansSectionState();
}

class _PremiumPlansSectionState extends State<_PremiumPlansSection> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.yearlyId;
  }

  @override
  Widget build(BuildContext context) {
    final yearlySelected = _selectedId == widget.yearlyId;
    final weeklySelected = _selectedId == widget.weeklyId;
    final monthlySelected = _selectedId == widget.monthlyId;

    return Column(
      children: [
        _PlanCard(
          title: 'Premium Yearly Subscription',
          price: widget.yearlyPlan?.price ?? '—',
          priceSuffix: 'per year',
          isSelected: yearlySelected,
          onTap: () => setState(() => _selectedId = widget.yearlyId),
        ),

        const SizedBox(height: 14),
        _PlanCard(
          title: 'Premium Monthly Subscription',
          price: widget.monthlyPlan?.price ?? '—',
          priceSuffix: 'per month',
          isSelected: monthlySelected,
          onTap: () => setState(() => _selectedId = widget.monthlyId),
        ),
        const SizedBox(height: 14),
        _PlanCard(
          title: 'Premium Weekly Subscription',
          price: widget.weeklyPlan?.price ?? '—',
          priceSuffix: 'per week',
          isSelected: weeklySelected,
          onTap: () => setState(() => _selectedId = widget.weeklyId),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [PremiumPage._cyan, PremiumPage._purple],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: PremiumPage._cyan.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap:
                    widget.isDisabled ? null : () => widget.onBuy(_selectedId),
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Text(
                    widget.isDisabled ? 'Please wait…' : 'Subscribe',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String priceSuffix;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.priceSuffix,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient:
                isSelected
                    ? const LinearGradient(
                      colors: [PremiumPage._cyan, PremiumPage._purple],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                    : null,
            color: isSelected ? null : PremiumPage._cardUnselected,
            border: Border.all(
              color:
                  isSelected
                      ? PremiumPage._cyan.withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: PremiumPage._cyan.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: PremiumPage._purple.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$price . $priceSuffix',
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color:
                            isSelected
                                ? Colors.white.withOpacity(0.95)
                                : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 50,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color:
                      isSelected
                          ? Colors.white.withOpacity(0.95)
                          : Colors.white.withOpacity(0.15),
                ),
                alignment: Alignment(isSelected ? 1.0 : -1.0, 0),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
