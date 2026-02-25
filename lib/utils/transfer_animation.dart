import 'dart:math';
import 'package:flutter/material.dart';

class TransferAnimation extends StatefulWidget {
  final double height;
  final bool isTransferring;

  const TransferAnimation({
    super.key,
    this.height = 260,
    this.isTransferring = true,
  });

  @override
  State<TransferAnimation> createState() => _TransferAnimationState();
}

class _TransferAnimationState extends State<TransferAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final icons = [Icons.insert_drive_file, Icons.image, Icons.videocam];
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (widget.isTransferring) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant TransferAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isTransferring && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isTransferring) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _calculateBezier(double t, Offset p0, Offset p1, Offset p2) {
    final x =
        pow(1 - t, 2) * p0.dx + 2 * (1 - t) * t * p1.dx + pow(t, 2) * p2.dx;

    final y =
        pow(1 - t, 2) * p0.dy + 2 * (1 - t) * t * p1.dy + pow(t, 2) * p2.dy;

    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final start = Offset(60, height / 2);
          final end = Offset(width - 60, height / 2);
          final control = Offset(width / 2, height / 2 - 80);
          final phoneSize = 100.0;
          final phoneTop = (height - phoneSize) / 2 + 10;

          return Stack(
            children: [
              /// LEFT PHONE
              Positioned(left: 0, top: phoneTop, child: _phone()),
              //  RIGHT PHONE
              Positioned(right: 0, top: phoneTop, child: _phone2()),

              /// MOVING FILE
              // AnimatedBuilder(
              //   animation: _controller,
              //   builder: (context, child) {
              //     final position = _calculateBezier(
              //       _controller.value,
              //       start,
              //       control,
              //       end,
              //     );

              //     return Positioned(
              //       left: position.dx - 20,
              //       top: position.dy - 20,
              //       child: Opacity(
              //         opacity: _controller.value < 0.9 ? 1 : 0,
              //         child: child,
              //       ),
              //     );
              //   },
              //   child: _file(),
              // ),

              /// MOVING FILES (3)
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    double progress = (_controller.value - (index * 0.25));

                    if (progress < 0) progress = 0;
                    if (progress > 1) progress = 1;

                    final position = _calculateBezier(
                      progress,
                      start,
                      control,
                      end,
                    );

                    return Positioned(
                      left: position.dx - 14,
                      top: position.dy - 14,
                      child: Opacity(
                        opacity: progress > 0 && progress < 1 ? 1 : 0,
                        child: Transform.scale(
                          scale: 0.85 + (progress * 0.25),
                          child: child!,
                        ),
                      ),
                    );
                  },
                  child: Icon(icons[index], size: 26, color: Colors.blue),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _phone() {
    return Image.asset(
      "assets/icons/phone.webp",
      width: 100,
      height: 110,
      fit: BoxFit.contain,
    );
  }

  Widget _phone2() {
    return Image.asset(
      "assets/icons/phone2.png",
      width: 100,
      height: 110,
      fit: BoxFit.contain,
    );
  }

  // Widget _file() {
  //   return const Icon(Icons.insert_drive_file, color: Colors.blue, size: 22);
  // }
}
