import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/components/on_boardingbutton.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/services/one_time_free_send_store.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Premium subscription screen – dark theme, gradient accents, file-transfer focused content.
/// Pro: Wi‑Fi transfer (unlimited, fast, no server), no ads, priority support.
class PremiumPage extends GetView<PremiumController> {
  const PremiumPage({super.key});

  @override
  String? get tag => null;

  static const Color _bgDark = Colors.white;
  static const Color _cardUnselected = Colors.white;
  static const Color _cyan = Color(0xff22d3ee);
  static const Color _purple = Color(0xffa855f7);

  static const double _screenPaddingH = 24;
  static const double _screenVerticalPadding = 13;

  @override
  Widget build(BuildContext context) {
    // Obx for GetX reactive state + ValueListenableBuilder for IAP loading state.
    return Obx(() {
      final iapService = controller.iapService;
      final isPremium = controller.isPremium || iapService.isPremium;

      final isAndroid = GetPlatform.isAndroid;
      final weeklyId =
          isAndroid
              ? (dotenv.env['IAP_ANDROID_PRODUCT_WEEKLY'] ??
                  'transfer.file.data.app.premium.weekly')
              : (dotenv.env['IAP_PRODUCT_WEEKLY'] ??
                  'com.share.transfer.file.all.data.app.premium.weekly');
      final monthlyId =
          isAndroid
              ? (dotenv.env['IAP_ANDROID_PRODUCT_MONTHLY'] ??
                  'transfer.file.data.app.premium.monthly')
              : (dotenv.env['IAP_PRODUCT_MONTHLY'] ??
                  'com.share.transfer.file.all.data.app.premium.monthly');

      final yearlyId =
          isAndroid
              ? (dotenv.env['IAP_ANDROID_PRODUCT_YEARLY'] ??
                  'transfer.file.data.app.premium.yearly')
              : (dotenv.env['IAP_PRODUCT_YEARLY'] ??
                  'com.share.transfer.file.all.data.app.premium.yearly');
      final monthlyPlan = iapService.planForId(monthlyId);
      final weeklyPlan = iapService.planForId(weeklyId);
      final yearlyPlan = iapService.planForId(yearlyId);

      return ValueListenableBuilder<bool>(
        valueListenable: iapService.isLoading,
        builder: (context, isLoading, _) {
          final disableActions = isLoading || controller.isRestoring.value;

          return Scaffold(
            backgroundColor: _bgDark,
            bottomNavigationBar:
                isPremium
                    ? SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: On_BoardingButton(
                          ontap: () => AppNavigator.toHome(),
                          height: 45,
                          width: double.infinity,
                          text: "Start Transferring",
                          color: const Color.fromARGB(255, 87, 107, 241),
                        ),
                      ),
                    )
                    : null,
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(color: _bgDark),
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
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
                                    style: TextStyle(color: Colors.black54),
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
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFEFF6FF),
                                            Color(0xFFEDE9FE),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.06),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.workspace_premium,
                                              color: _cyan,
                                              size: 38,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            'You are Premium',
                                            style: GoogleFonts.roboto(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'All Pro features are unlocked on your account.',
                                            style: GoogleFonts.roboto(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _PremiumFeatureTile(
                                      icon: Icons.wifi_tethering_rounded,
                                      title: 'Unlimited Wi-Fi Transfer',
                                      subtitle:
                                          'Send any number of files without limits.',
                                    ),
                                    const SizedBox(height: 10),
                                    _PremiumFeatureTile(
                                      icon: Icons.speed_rounded,
                                      title: 'Faster Sharing',
                                      subtitle:
                                          'Quick pairing and smooth transfer speed.',
                                    ),
                                    const SizedBox(height: 10),
                                    _PremiumFeatureTile(
                                      icon: Icons.ads_click_rounded,
                                      title: 'No Ads Experience',
                                      subtitle:
                                          'Enjoy a clean interface without interruptions.',
                                    ),
                                    const SizedBox(height: 10),
                                    _PremiumFeatureTile(
                                      icon: Icons.verified_user_rounded,
                                      title: 'Secure Direct Connection',
                                      subtitle:
                                          'Your data moves directly between devices.',
                                    ),
                                  ],
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 10),
                                  _buildTitle(),
                                  const SizedBox(height: 24),
                                  _buildBenefits(),
                                  const SizedBox(height: 20),
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
                                  const SizedBox(height: 24),
                                  _buildRestoreLink(
                                    onRestore:
                                        disableActions
                                            ? () {}
                                            : controller.restorePurchases,
                                    isRestoring: controller.isRestoring.value,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFooter(context),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isPremium)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: IconButton(
                          onPressed: () {
                            AppNavigator.back();
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Color.fromARGB(30, 0, 0, 0),
                            size: 22,
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

  Widget _buildTitle() {
    return const _AnimatedPremiumTitle();
  }

  Widget _buildBenefits() {
    const items = [
      'Unlimited transfer between iOS and Android.',
      'Instant connection with QR over Wi-Fi.',
      'Ad-free experience with zero interruptions.',
      'Secure direct transfer between devices.',
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
                      const Icon(Icons.check_circle, color: _cyan, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e,
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
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
                        color: Colors.black54,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final privacy =
        (isAndroid
            ? dotenv.env['ANDROID_PRIVACY_POLICY_URL']
            : dotenv.env['PRIVACY_POLICY_URL']) ??
        'https://maxgamesproduction.blogspot.com/2023/01/privacy-policy.html';
    final terms =
        (isAndroid
            ? dotenv.env['ANDROID_TERMS_AND_CONDITIONS_URL']
            : dotenv.env['TERMS_OF_USE_URL']) ??
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
            Icon(Icons.verified_user, size: 16, color: Colors.black38),
            const SizedBox(width: 6),
            Text(
              'Secured with Apple',
              style: GoogleFonts.roboto(fontSize: 12, color: Colors.black38),
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
                  fontSize: 12,
                  color: Colors.black54,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              '  |  ',
              style: GoogleFonts.roboto(fontSize: 12, color: Colors.black38),
            ),
            InkWell(
              onTap: () => _open(terms),
              child: Text(
                'Terms of Use',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.black54,
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

class _AnimatedPremiumTitle extends StatefulWidget {
  const _AnimatedPremiumTitle();

  @override
  State<_AnimatedPremiumTitle> createState() => _AnimatedPremiumTitleState();
}

class _AnimatedPremiumTitleState extends State<_AnimatedPremiumTitle>
    with TickerProviderStateMixin {
  late final AnimationController _crownController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _crownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _crownController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.roboto(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      height: 1,
      color: Colors.white,
      letterSpacing: 0.4,
    );

    return Column(
      children: [
        AnimatedBuilder(
          animation: _crownController,
          builder: (context, child) {
            final t = _crownController.value;
            final step = (t * 10).floor();
            final offsetX = step.isEven ? -1.0 : 1.0;
            final offsetY = -1.5 * (0.5 - (t - 0.5).abs()) * 2;
            return Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: child,
            );
          },
          child: Image.asset('assets/icons/crown.png', height: 48),
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, _) {
            final shimmerX = (_shimmerController.value * 2) - 1.0;
            return Column(
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback:
                      (bounds) => const LinearGradient(
                        colors: [PremiumPage._cyan, PremiumPage._purple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                  child: Text('UNLOCK', style: titleStyle),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: const [
                          PremiumPage._cyan,
                          Colors.white,
                          PremiumPage._purple,
                        ],
                        stops: const [0.2, 0.5, 0.8],
                        begin: Alignment(shimmerX, 0),
                        end: Alignment(shimmerX + 1.8, 0),
                      ).createShader(bounds),
                  child: Text('PRO FILE TRANSFER', style: titleStyle),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PremiumFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PremiumFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PremiumPage._cyan, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _PremiumPlansSectionState extends State<_PremiumPlansSection>
    with WidgetsBindingObserver {
  late String _selectedId;
  bool _isFreeSendUsed = true;

  static const String _fallbackWeeklyPrice = '2500';
  static const String _fallbackMonthlyPrice = '2900';
  static const String _fallbackYearlyPrice = '9900';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedId = widget.yearlyId;
    _loadFreeSendStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFreeSendStatus();
    }
  }

  Future<void> _loadFreeSendStatus() async {
    final used = await OneTimeFreeSendStore.hasUsedLocalThenRemote();
    if (!mounted) return;
    setState(() {
      _isFreeSendUsed = used;
    });
  }

  @override
  Widget build(BuildContext context) {
    final yearlySelected = _selectedId == widget.yearlyId;
    final weeklySelected = _selectedId == widget.weeklyId;
    final monthlySelected = _selectedId == widget.monthlyId;
    final weeklyPrice = _effectivePrice(
      widget.weeklyPlan?.price,
      _fallbackWeeklyPrice,
    );
    final monthlyPrice = _effectivePrice(
      widget.monthlyPlan?.price,
      _fallbackMonthlyPrice,
    );
    final yearlyPrice = _effectivePrice(
      widget.yearlyPlan?.price,
      _fallbackYearlyPrice,
    );
    final ctaText =
        _selectedId == widget.yearlyId ? 'Try for Free' : 'Continue';

    return Column(
      children: [
        _PlanCard(
          title: 'Yearly Plan',
          price: yearlyPrice,
          priceSuffix: 'per year',
          note: '7 DAYS FREE',
          badgeText: 'SAVE UP TO 88%',
          isSelected: yearlySelected,
          onTap: () => setState(() => _selectedId = widget.yearlyId),
        ),
        const SizedBox(height: 14),
        _PlanCard(
          title: 'Monthly Plan',
          price: monthlyPrice,
          priceSuffix: 'per month',
          // note: '3 DAYS FREE',
          badgeText: '3 DAYS TRIAL',
          isSelected: monthlySelected,
          onTap: () => setState(() => _selectedId = widget.monthlyId),
        ),
        const SizedBox(height: 14),
        _PlanCard(
          title: 'Weekly Plan',
          price: weeklyPrice,
          priceSuffix: 'per week',
          isSelected: weeklySelected,
          onTap: () => setState(() => _selectedId = widget.weeklyId),
        ),

        if (!_isFreeSendUsed) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap:
                widget.isDisabled
                    ? null
                    : () {
                      Get.toNamed(
                        AppRoutes.choosemethodscan,
                        arguments: <String, dynamic>{'isReceiver': false},
                      )?.then((_) => _loadFreeSendStatus());
                    },
            child: Text(
              'Continue without subscription (1 free send)',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
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
                    widget.isDisabled ? 'Please wait…' : ctaText,
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

  String _effectivePrice(String? applePrice, String fallbackPrice) {
    if (applePrice == null) return _ensureTwoDecimals(fallbackPrice);
    final normalized = applePrice.trim();
    if (normalized.isEmpty || normalized == '—') {
      return _ensureTwoDecimals(fallbackPrice);
    }
    return _ensureTwoDecimals(normalized);
  }

  String _ensureTwoDecimals(String value) {
    if (!value.contains('.')) return '$value.00';

    final parts = value.split('.');
    if (parts.length < 2) return '$value.00';

    final decimals = parts.last;
    if (decimals.length >= 2) return value;
    if (decimals.length == 1) return '${parts.first}.${decimals}0';
    return '${parts.first}.00';
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String priceSuffix;
  final String? note;
  final String? badgeText;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.priceSuffix,
    this.note,
    this.badgeText,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      : Colors.black.withOpacity(0.10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    // const SizedBox(height: 6),
                    Text(
                      '$price $priceSuffix',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color:
                            isSelected
                                ? Colors.white.withOpacity(0.95)
                                : Colors.black54,
                      ),
                    ),
                    if (note != null) ...[
                      // const SizedBox(height: 4),
                      Text(
                        note!,
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected
                                  ? Colors.white
                                  : const Color(0xff0f766e),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffffb020),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText!,
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  if (badgeText != null) const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 50,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color:
                          isSelected
                              ? Colors.white.withOpacity(0.95)
                              : const Color(0xffe5e7eb),
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
            ],
          ),
        ),
      ),
    );
  }
}
