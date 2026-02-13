import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/models/device_info.dart';

class RadarView extends StatelessWidget {
  final double size;
  final List<DeviceInfo> devices;
  final double sweep;

  const RadarView({
    super.key,
    required this.size,
    required this.devices,
    required this.sweep,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(devices: devices, sweep: sweep),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<DeviceInfo> devices;
  final double sweep;

  _RadarPainter({required this.devices, required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    /// ================== Radar Rings ==================
    final ringPaint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, ringPaint);
    }

    /// ================== Radar Sweep (NO center line) ==================
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepPaint =
        Paint()
          ..shader = SweepGradient(
            startAngle: sweep,
            endAngle: sweep + 0.45,
            colors: [
              Colors.blue.withOpacity(0.0),
              Colors.blue.withOpacity(0.35),
            ],
          ).createShader(rect)
          ..style = PaintingStyle.fill;

    // 🔥 useCenter = false → removes green straight line
    canvas.drawArc(rect, sweep, 0.45, false, sweepPaint);

    /// ================== Device Dots ==================
    final dotPaint = Paint()..color = Colors.blueAccent;

    for (final d in devices) {
      final hash = d.ip.hashCode;
      final angle = (hash % 360) * math.pi / 180.0;
      final r = radius * (0.4 + ((hash % 100) / 100.0) * 0.6);

      final pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );

      // Draw device dot
      canvas.drawCircle(pos, 4, dotPaint);

      // Draw device initial/label
      if (d.name.isNotEmpty) {
        final initial = d.name.substring(0, 1).toUpperCase();

        final textPainter = TextPainter(
          text: TextSpan(
            text: initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        final textOffset = Offset(
          pos.dx - textPainter.width / 2,
          pos.dy - textPainter.height / 2,
        );

        textPainter.paint(canvas, textOffset);
      }
    }

    /// ================== Center Dot ==================
    canvas.drawCircle(center, 4, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweep != sweep ||
        oldDelegate.devices.length != devices.length;
  }
}

class ScanningRadarPainter extends CustomPainter {
  final List<DeviceInfo> devices;
  final double sweep;

  ScanningRadarPainter({this.devices = const [], this.sweep = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw sweeping arc
    final sweepPaint =
        Paint()
          // small light
          ..color = Colors.green.shade200
          ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius * 0.9);
    canvas.drawArc(rect, -0.3, 0.6, true, sweepPaint);

    // Draw radar lines
    final linePaint =
        Paint()
          ..color = Colors.blueAccent
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    // Draw cross lines
    canvas.drawLine(
      Offset(center.dx - radius * 0.3, center.dy),
      Offset(center.dx + radius * 0.3, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.3),
      Offset(center.dx, center.dy + radius * 0.3),
      linePaint,
    );

    // Draw diagonal lines
    final diagonalPaint =
        Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final startRadius = radius * 0.4;
      final endRadius = radius * 0.9;
      canvas.drawLine(
        Offset(
          center.dx + startRadius * math.cos(angle),
          center.dy + startRadius * math.sin(angle),
        ),
        Offset(
          center.dx + endRadius * math.cos(angle),
          center.dy + endRadius * math.sin(angle),
        ),
        diagonalPaint,
      );
    }

    /// ================== Device Dots ==================
    final dotPaint = Paint()..color = Colors.greenAccent;

    for (final d in devices) {
      final hash = d.ip.hashCode;
      final angle = (hash % 360) * math.pi / 180.0;
      final r = radius * (0.4 + ((hash % 100) / 100.0) * 0.6);

      final pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );

      // Draw device dot
      canvas.drawCircle(pos, 4, dotPaint);

      // Draw device initial/label
      if (d.name.isNotEmpty) {
        final initial = d.name.substring(0, 1).toUpperCase();

        final textPainter = TextPainter(
          text: TextSpan(
            text: initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        final textOffset = Offset(
          pos.dx - textPainter.width / 2,
          pos.dy - textPainter.height / 2,
        );

        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScanningRadarPainter oldDelegate) {
    return oldDelegate.sweep != sweep ||
        oldDelegate.devices.length != devices.length;
  }
}
