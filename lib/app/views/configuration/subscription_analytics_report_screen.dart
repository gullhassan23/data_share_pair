import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/subscription_analytics_report_store.dart';
import 'package:share_plus/share_plus.dart';

class SubscriptionAnalyticsReportScreen extends StatefulWidget {
  const SubscriptionAnalyticsReportScreen({super.key});

  @override
  State<SubscriptionAnalyticsReportScreen> createState() =>
      _SubscriptionAnalyticsReportScreenState();
}

class _SubscriptionAnalyticsReportScreenState
    extends State<SubscriptionAnalyticsReportScreen> {
  static const Color _primaryBlue = Color(0xFF3B59FF);
  static const Color _textDark = Color(0xFF333333);

  final SubscriptionAnalyticsReportStore _store =
      SubscriptionAnalyticsReportStore.instance;

  @override
  void initState() {
    super.initState();
    _store.refreshSandboxFlag();
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _store.buildShareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard')),
    );
  }

  Future<void> _shareReport() async {
    final box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box != null
        ? Rect.fromLTWH(
            box.localToGlobal(Offset.zero).dx,
            box.localToGlobal(Offset.zero).dy,
            box.size.width,
            box.size.height,
          )
        : null;
    await Share.share(
      _store.buildShareText(),
      subject: 'Firebase IAP Analytics Report',
      sharePositionOrigin: origin,
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
                child: ListenableBuilder(
                  listenable: _store,
                  builder: (context, _) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 14),
                        _buildStatusCard(
                          title: 'Revenue (logPurchase)',
                          subtitle: _revenueSubtitle(),
                          ok: _store.revenueReported,
                          pending: _store.reportingAttempted &&
                              !_store.revenueReported &&
                              _store.lastError == null &&
                              !_store.wasSkipped,
                        ),
                        const SizedBox(height: 10),
                        _buildStatusCard(
                          title: 'Event (subscription_purchase_detail)',
                          subtitle: _eventSubtitle(),
                          ok: _store.eventReported,
                          pending: _store.revenueReported &&
                              !_store.eventReported &&
                              _store.lastError == null,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailsCard(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyReport,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _shareReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _store.clear,
                          child: const Text('Clear report'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Recent logs',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_store.logs.isEmpty)
                          _emptyLogsCard()
                        else
                          ..._store.logs.map(_buildLogTile),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _revenueSubtitle() {
    if (_store.revenueReported) {
      final value = _store.lastRevenueValue ?? '—';
      final currency = _store.lastRevenueCurrency ?? '';
      return 'Reported: $value $currency';
    }
    if (_store.wasSkipped) {
      return 'Skipped: ${_store.lastSkipReason ?? "unknown"}';
    }
    if (_store.lastError != null) {
      return 'Failed';
    }
    if (_store.reportingAttempted) {
      return 'Waiting / in progress...';
    }
    return 'No purchase logged yet';
  }

  String _eventSubtitle() {
    if (_store.eventReported) {
      return 'Custom event sent to Firebase';
    }
    if (_store.wasSkipped) {
      return 'Skipped with revenue';
    }
    if (_store.lastError != null) {
      return 'Failed before event send';
    }
    if (_store.revenueReported) {
      return 'Revenue sent, event pending...';
    }
    return 'No event logged yet';
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
              onPressed: AppNavigator.back,
              icon: Icon(Icons.adaptive.arrow_back),
              label: Text(
                'Back',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Text(
            'Firebase IAP Report',
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

  Widget _buildSummaryCard() {
    final bothOk = _store.bothReported;
    final hasData = _store.lastUpdatedAt != null;
    final Color bg;
    final IconData icon;
    final String title;
    final String body;

    if (bothOk) {
      bg = Colors.green.shade50;
      icon = Icons.check_circle_rounded;
      title = 'All good';
      body = 'Revenue and custom event both reported to Firebase.';
    } else if (_store.wasSkipped) {
      bg = Colors.orange.shade50;
      icon = Icons.info_outline_rounded;
      title = 'Reporting skipped';
      body =
          'Premium may still work, but Firebase revenue/event were not sent. Reason: ${_store.lastSkipReason ?? "unknown"}.';
    } else if (_store.lastError != null) {
      bg = Colors.red.shade50;
      icon = Icons.error_outline_rounded;
      title = 'Reporting failed';
      body = _store.lastError!;
    } else if (!hasData) {
      bg = Colors.blue.shade50;
      icon = Icons.analytics_outlined;
      title = 'No data yet';
      body =
          'Make a sandbox or TestFlight subscription, then open this screen again.';
    } else {
      bg = Colors.orange.shade50;
      icon = Icons.hourglass_top_rounded;
      title = 'Incomplete';
      body =
          'Purchase was processed but revenue/event reporting is not fully confirmed yet.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryBlue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required bool ok,
    required bool pending,
  }) {
    final Color color;
    final IconData icon;
    if (ok) {
      color = Colors.green;
      icon = Icons.check_circle_rounded;
    } else if (pending) {
      color = Colors.orange;
      icon = Icons.schedule_rounded;
    } else {
      color = Colors.red;
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            ok ? 'YES' : (pending ? '...' : 'NO'),
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last purchase details',
            style: GoogleFonts.roboto(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _detailRow('Sandbox reporting', '${_store.sandboxReportingEnabled}'),
          _detailRow('Verified', '${_store.lastVerificationValid ?? "—"}'),
          _detailRow('Apple verified', '${_store.lastVerifiedByApple ?? "—"}'),
          _detailRow('Environment', _store.lastEnvironment ?? '—'),
          _detailRow('Product ID', _store.lastProductId ?? '—'),
          _detailRow('Transaction ID', _store.lastTransactionId ?? '—'),
          _detailRow('Purchase status', _store.lastPurchaseStatus ?? '—'),
          _detailRow(
            'Updated',
            _store.lastUpdatedAt == null
                ? '—'
                : _formatTime(_store.lastUpdatedAt!),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyLogsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Logs will appear here after a subscription attempt.',
        style: GoogleFonts.roboto(fontSize: 14, color: Colors.black54),
      ),
    );
  }

  Widget _buildLogTile(SubscriptionReportLogLine line) {
    Color dotColor;
    switch (line.level) {
      case SubscriptionReportLogLevel.success:
        dotColor = Colors.green;
      case SubscriptionReportLogLevel.warning:
        dotColor = Colors.orange;
      case SubscriptionReportLogLevel.error:
        dotColor = Colors.red;
      case SubscriptionReportLogLevel.info:
        dotColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: dotColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(line.timestamp),
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  line.message,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
