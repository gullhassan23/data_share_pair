import 'package:flutter/material.dart';

class CurvedBackground extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80);

    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 80,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


class BackgroundEllipses extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.fill;

    canvas.drawCircle(
      const Offset(10, -10), // position
      200, // ⬅️ increased size
      paint,
    );

    /// RIGHT TOP – BIGGER OVAL
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width + 60, 70),
        width: 320, // ⬅️ increased
        height: 320, // ⬅️ increased
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
