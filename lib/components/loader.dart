import 'package:flutter/material.dart';
import 'package:share_app_latest/utils/color.dart';

class LoaderScreen extends StatelessWidget {
  final Color? color;
  const LoaderScreen({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: color));
  }
}

class TransformScaleOfLoader extends StatelessWidget {
  final Color? color;
  const TransformScaleOfLoader({super.key, this.color = AppColors.whiteColor});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.7,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: LoaderScreen(color: color),
      ),
    );
  }
}
