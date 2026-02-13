import 'package:flutter/material.dart';

class CustomUploadProgress extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final double sentMB;
  final double totalMB;
  final double speedMBps;

  const CustomUploadProgress({
    super.key,
    required this.progress,
    required this.sentMB,
    required this.totalMB,
    required this.speedMBps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D88FC),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "UPLOADING...",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                /// Background track
                Container(height: 10, color: const Color(0xFF353535)),

                /// Gradient progress
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 10,
                      width: constraints.maxWidth * progress,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF00FFE9),
                            Color(0xFF2F3944),
                            Color(0xFFBDFF70),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// Bottom Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${sentMB.toStringAsFixed(2)}MB  OF  ${totalMB.toStringAsFixed(1)}MB",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                "${speedMBps.toStringAsFixed(1)}MB/S",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
