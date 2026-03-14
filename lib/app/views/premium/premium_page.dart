import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Premium subscription screen – dark theme, gradient accents, file-transfer focused content.
/// Pro account includes: No Ads, unlimited transfers, priority support, regular updates.
class PremiumPage extends GetView<PremiumController> {
  const PremiumPage({super.key});

  @override
  String? get tag => null;

  static const Color _bgDark = Color(0xff12121a);
  static const Color _cyan = Color(0xff22d3ee);
  static const Color _purple = Color(0xffa855f7);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final iapService = controller.iapService;
      final isPremium = controller.isPremium;
      final isLoading = iapService.isLoading.value;

      final monthlyId =
          dotenv.env['IAP_PRODUCT_MONTHLY'] ?? 'com.yourapp.premium.monthly';
      final yearlyId =
          dotenv.env['IAP_PRODUCT_YEARLY'] ?? 'com.yourapp.premium.yearly';
      final monthlyPlan = iapService.planForId(monthlyId);
      final yearlyPlan = iapService.planForId(yearlyId);

      return Scaffold(
        backgroundColor: _bgDark,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: _bgDark),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                if (!iapService.isAvailable) ...[
                  if (isLoading)
                    const Expanded(
                        child: Center(
                            child: CircularProgressIndicator(color: _cyan)))
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
                        child: CircularProgressIndicator(color: _cyan)),
                  )
                else if (isPremium)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium,
                              color: _cyan, size: 72),
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
                            'Ad-free file transfer & all premium features unlocked.',
                            style: GoogleFonts.roboto(
                                fontSize: 14, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildTitle(),
                          const SizedBox(height: 24),
                          _buildBenefits(),
                          const SizedBox(height: 28),
                          _PremiumPlansSection(
                            monthlyId: monthlyId,
                            yearlyId: yearlyId,
                            monthlyPlan: monthlyPlan,
                            yearlyPlan: yearlyPlan,
                            onBuy: controller.buy,
                          ),
                          const SizedBox(height: 16),
                          _buildRestoreLink(controller.restorePurchases),
                          const SizedBox(height: 24),
                          _buildFooter(context),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => AppNavigator.back(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
          TextButton(
            onPressed: () {
              debugPrint('[PremiumPage] Restore');
              controller.restorePurchases();
            },
            child: Text(
              'RESTORE',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_cyan, _purple],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        'UNLOCK PREMIUM\nFILE TRANSFER',
        style: GoogleFonts.roboto(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBenefits() {
    const items = [
      'UNLIMITED FILE TRANSFERS',
      'NO ADS',
      'REGULAR APP UPDATES',
      'PRIORITY SUPPORT',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: _cyan, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRestoreLink(VoidCallback onRestore) {
    return Center(
      child: TextButton(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user, size: 16, color: Colors.white38),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Secured with Apple. Privacy Policy and Terms of Use',
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PremiumPlansSection extends StatefulWidget {
  final String monthlyId;
  final String yearlyId;
  final PremiumPlan? monthlyPlan;
  final PremiumPlan? yearlyPlan;
  final void Function(String) onBuy;

  const _PremiumPlansSection({
    required this.monthlyId,
    required this.yearlyId,
    this.monthlyPlan,
    this.yearlyPlan,
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

    return Column(
      children: [
        _PlanCard(
          title: 'PREMIUM YEARLY SUBSCRIPTION',
          price: widget.yearlyPlan?.price ?? '—',
          priceSuffix: 'per year',
          isSelected: yearlySelected,
          useGradient: true,
          onTap: () => setState(() => _selectedId = widget.yearlyId),
        ),
        const SizedBox(height: 14),
        _PlanCard(
          title: 'Premium Monthly Subscription',
          price: widget.monthlyPlan?.price ?? '—',
          priceSuffix: 'per month',
          isSelected: !yearlySelected,
          useGradient: false,
          onTap: () => setState(() => _selectedId = widget.monthlyId),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [PremiumPage._cyan, PremiumPage._purple],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onBuy(_selectedId),
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: Text(
                    'Start Free Trial',
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
  final bool useGradient;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.priceSuffix,
    required this.isSelected,
    required this.useGradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: useGradient
                ? const LinearGradient(
                    colors: [PremiumPage._cyan, PremiumPage._purple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: useGradient ? null : const Color(0xff1e1e28),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$price . $priceSuffix',
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.2),
                ),
                alignment: Alignment(
                  isSelected ? 1.0 : -1.0,
                  0,
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
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
