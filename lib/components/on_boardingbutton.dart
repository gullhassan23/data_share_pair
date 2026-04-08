// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class On_BoardingButton extends StatefulWidget {
  final String text;
  final double height;
  final double width;
  final Color color;
  final VoidCallback ontap;

  const On_BoardingButton({
    Key? key,
    required this.text,
    required this.height,
    required this.width,
    required this.color,
    required this.ontap,
  }) : super(key: key);

  @override
  State<On_BoardingButton> createState() => _On_BoardingButtonState();
}

class _On_BoardingButtonState extends State<On_BoardingButton>
    with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late AnimationController _shimmerController;

  late Animation<double> _arrowAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    /// Arrow animation
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _arrowAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
    _arrowController.repeat(reverse: true);

    /// Subtle shimmer (slower + softer)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.ontap,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 🔥 Text with subtle shimmer behind
            AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment(-1, 0),
                      end: Alignment(1, 0),
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.4), // shimmer highlight
                        Colors.white.withOpacity(0.9),
                      ],
                      stops: [
                        (_shimmerAnimation.value - 0.2).clamp(0.0, 1.0),
                        _shimmerAnimation.value.clamp(0.0, 1.0),
                        (_shimmerAnimation.value + 0.2).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    widget.text,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: Colors.white, // base color
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 10),

            /// Arrow animation
            AnimatedBuilder(
              animation: _arrowAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_arrowAnimation.value, 0),
                  child: child,
                );
              },
              child: Image.asset("assets/icons/back_arrow.png", height: 18),
            ),
          ],
        ),
      ),
    );
  }
}
