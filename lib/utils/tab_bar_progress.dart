import 'package:flutter/material.dart';

/// Step-based progress bar built from rectangular segments (tabs).
/// Active step = filled segment; inactive = unfilled with rounded corners.
/// Matches the "Choose Transfer Method" style: horizontal bar with even segments.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.activeColor,
    this.inactiveColor,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.height = 6,
    this.segmentSpacing = 5,
    this.padding,
  }) : assert(currentStep >= 1 && currentStep <= totalSteps),
       assert(totalSteps >= 1);

  /// Current step (1-based). Step 1 = first segment filled.
  final int currentStep;

  /// Total number of steps (segments).
  final int totalSteps;

  /// Fill color for the active (current and completed) segments.
  final Color? activeColor;

  /// Background color for inactive (future) segments.
  final Color? inactiveColor;

  /// Whether to animate when [currentStep] changes.
  final bool animate;

  /// Duration of the animation.
  final Duration animationDuration;

  /// Height of each segment.
  final double height;

  /// Horizontal gap between segments.
  final double segmentSpacing;

  /// Padding around the whole bar.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? Colors.white;

    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final step = index + 1;
          final isActive = step <= currentStep;
          final isFirst = index == 0;
          final isLast = index == totalSteps - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: isFirst ? 0 : segmentSpacing / 2,
                right: isLast ? 0 : segmentSpacing / 2,
              ),
              child: _Segment(
                isActive: isActive,
                activeColor: active,
                inactiveColor: inactive,
                height: height,
                animate: animate,
                duration: animationDuration,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.height,
    required this.animate,
    required this.duration,
  });

  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animate ? duration : Duration.zero,
      curve: Curves.easeInOut,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow:
            isActive
                ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
                : null,
      ),
    );
  }
}
