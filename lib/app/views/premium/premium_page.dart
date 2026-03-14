import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class PremiumPage extends GetView<PremiumController> {
  const PremiumPage({super.key});

  @override
  String? get tag => null;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final iapService = controller.iapService;
      final isPremium = controller.isPremium;
      final isLoading = iapService.isLoading.value;

      final monthlyId = dotenv.env['IAP_PRODUCT_MONTHLY'] ?? 'com.yourapp.premium.monthly';
      final yearlyId = dotenv.env['IAP_PRODUCT_YEARLY'] ?? 'com.yourapp.premium.yearly';
      final monthlyPlan = iapService.planForId(monthlyId);
      final yearlyPlan = iapService.planForId(yearlyId);

      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffEEF4FF), Color(0xffF8FAFF), Color(0xffFFFFFF)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => AppNavigator.back(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Premium',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!iapService.isAvailable) ...[
                  if (isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'In-App Purchases are not available on this device.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ] else if (isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (isPremium)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 72),
                          const SizedBox(height: 16),
                          Text(
                            'You are Premium!',
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All premium features are unlocked.',
                            style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your plan',
                            style: GoogleFonts.roboto(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Monthly or yearly. Cancel anytime.',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _PlanTile(
                            title: monthlyPlan?.title ?? 'Monthly Premium',
                            subtitle: 'Billed monthly. Auto-renewal.',
                            price: monthlyPlan?.price ?? '—',
                            onTap: () {
                              debugPrint('[PremiumPage] onTap: monthly plan');
                              controller.buy(monthlyId);
                            },
                          ),
                          const SizedBox(height: 16),
                          _PlanTile(
                            title: yearlyPlan?.title ?? 'Yearly Premium',
                            subtitle: 'Best value. Billed yearly. Auto-renewal.',
                            price: yearlyPlan?.price ?? '—',
                            highlight: true,
                            onTap: () {
                              debugPrint('[PremiumPage] onTap: yearly plan');
                              controller.buy(yearlyId);
                            },
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                debugPrint('[PremiumPage] onPressed: restore purchases');
                                controller.restorePurchases();
                              },
                              child: const Text('Restore purchases'),
                            ),
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
    });
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onTap;
  final bool highlight;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = highlight
        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
        : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: highlight
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
