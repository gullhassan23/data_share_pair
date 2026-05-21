import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/services/admob_debug_service.dart';
import 'package:share_app_latest/services/admob_service.dart';

/// Bottom sheet: AdMob diagnostics and one-tap test loads (debug builds).
class AdMobDebugSheet extends StatefulWidget {
  const AdMobDebugSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const AdMobDebugSheet(),
    );
  }

  @override
  State<AdMobDebugSheet> createState() => _AdMobDebugSheetState();
}

class _AdMobDebugSheetState extends State<AdMobDebugSheet> {
  List<String> _lines = [];
  String? _lastTestResult;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  void _refreshReport() {
    setState(() {
      _lines = AdMobDebugService.buildReportLines();
      _lastTestResult = null;
    });
    for (final line in _lines) {
      AdMobDebugService.log(line);
    }
  }

  Future<void> _runTest(Future<String> Function() test) async {
    setState(() {
      _busy = true;
      _lastTestResult = 'Loading…';
    });
    final result = await test();
    AdMobDebugService.log('Test result: $result');
    if (mounted) {
      setState(() {
        _busy = false;
        _lastTestResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'AdMob debug',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Debug builds only. Use tests to see if the SDK, your unit IDs, '
                'or premium status is blocking ads.',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              if (_busy) const LinearProgressIndicator(),
              if (_lastTestResult != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _lastTestResult!.startsWith('OK')
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastTestResult!,
                    style: GoogleFonts.robotoMono(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipButton(
                    'Refresh report',
                    _busy ? null : _refreshReport,
                  ),
                  _chipButton(
                    'Copy report',
                    _busy
                        ? null
                        : () {
                          Clipboard.setData(
                            ClipboardData(text: _lines.join('\n')),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report copied')),
                          );
                        },
                  ),
                  _chipButton(
                    'Google test banner',
                    _busy
                        ? null
                        : () => _runTest(AdMobDebugService.runGoogleTestBannerLoad),
                  ),
                  _chipButton(
                    'Your banner',
                    _busy
                        ? null
                        : () =>
                            _runTest(AdMobDebugService.runConfiguredBannerLoad),
                  ),
                  _chipButton(
                    'Your MREC',
                    _busy
                        ? null
                        : () => _runTest(AdMobDebugService.runConfiguredMrecLoad),
                  ),
                  _chipButton(
                    'Your interstitial',
                    _busy
                        ? null
                        : () => _runTest(
                          AdMobDebugService.runConfiguredInterstitialLoad,
                        ),
                  ),
                  _chipButton(
                    'Preload app open',
                    _busy
                        ? null
                        : () async {
                          await AdMobService.instance.loadAppOpenAd(
                            isPremium: false,
                          );
                          if (mounted) {
                            setState(() {
                              _lastTestResult =
                                  'Triggered app open preload (see logcat)';
                            });
                          }
                          _refreshReport();
                        },
                  ),
                  _chipButton(
                    'Clear premium cache',
                    _busy
                        ? null
                        : () async {
                          await AdMobDebugService.clearPremiumCacheForTesting();
                          _refreshReport();
                        },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _lines.length,
                    itemBuilder: (_, i) => Text(
                      _lines[i],
                      style: GoogleFonts.robotoMono(fontSize: 11.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipButton(String label, VoidCallback? onPressed) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }
}
