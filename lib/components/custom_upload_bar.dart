// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

class CustomUploadProgress extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final double sentMB;
  final double totalMB;
  final double speedMBps;
  final bool showSpeed;
  final bool isSender;
  const CustomUploadProgress({
    Key? key,
    required this.progress,
    required this.sentMB,
    required this.totalMB,
    required this.speedMBps,
    this.showSpeed = true,
    required this.isSender,
  }) : super(key: key);

  String _formatSize(double valueInMB) {
    if (valueInMB >= 1024) {
      return "${(valueInMB / 1024).toStringAsFixed(2)} GB";
    }
    if (valueInMB >= 1) {
      return "${valueInMB.toStringAsFixed(2)} MB";
    }
    if (valueInMB > 0) {
      final kb = valueInMB * 1000;
      return "${kb.toStringAsFixed(0)} KB";
    }
    return "0 MB";
  }

  String _formatSpeed(double speedInMBps) {
    if (speedInMBps >= 1) {
      return "${speedInMBps.toStringAsFixed(2)} MB/s";
    }
    if (speedInMBps > 0) {
      final kbps = speedInMBps * 1000;
      return "${kbps.toStringAsFixed(0)} KB/s";
    }
    return "0 KB/s";
  }

  @override
  Widget build(BuildContext context) {
    final double safeProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD5D9FF), Color(0xFF5F74FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isSender ? "Sending your files" : "Receiving your files",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF232323),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Hang in there, we are almost done!",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3C3C3C),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD0D0D0)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 190,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: safeProgress,
                            strokeWidth: 6,
                            backgroundColor: const Color(0xFFE4E4E4),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE24A35),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E8F8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF5A69F0),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              "${(safeProgress * 100).toInt()}%",
                              style: const TextStyle(
                                color: Color(0xFF5A69F0),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 26),
                            Text(
                              _formatSize(sentMB),
                              style: const TextStyle(
                                color: Color(0xFF4A59E4),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),

                            Text(
                              "of ${_formatSize(totalMB)}",
                              style: const TextStyle(
                                color: Color(0xFF4B4B4B),
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6),
                            if (showSpeed)
                              Text(
                                _formatSpeed(speedMBps),
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 20,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // const SizedBox(height: 8),
                // const Row(
                //   children: [
                //     Expanded(
                //       child: Text(
                //         "Videos",
                //         textAlign: TextAlign.left,
                //         style: TextStyle(
                //           color: Color(0xFF303030),
                //           fontSize: 13,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ),
                //     Expanded(
                //       child: Text(
                //         "Images",
                //         textAlign: TextAlign.center,
                //         style: TextStyle(
                //           color: Color(0xFF303030),
                //           fontSize: 13,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ),
                //     Expanded(
                //       child: Text(
                //         "Contacts",
                //         textAlign: TextAlign.center,
                //         style: TextStyle(
                //           color: Color(0xFF303030),
                //           fontSize: 13,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ),
                //     Expanded(
                //       child: Text(
                //         "Calendar",
                //         textAlign: TextAlign.right,
                //         style: TextStyle(
                //           color: Color(0xFF303030),
                //           fontSize: 13,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 6),
                // Row(
                //   children: [
                //     Expanded(
                //       child: Container(
                //         height: 9,
                //         color: const Color(0xFFE24A35),
                //       ),
                //     ),
                //     Expanded(
                //       child: Container(
                //         height: 9,
                //         color: const Color(0xFF20D56B),
                //       ),
                //     ),
                //     Expanded(
                //       child: Container(
                //         height: 9,
                //         color: const Color(0xFFEAB525),
                //       ),
                //     ),
                //     Expanded(
                //       child: Container(
                //         height: 9,
                //         color: const Color(0xFF4E62DF),
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
