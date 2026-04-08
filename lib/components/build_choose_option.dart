import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BuildChooseOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showTrailingArrow;

  const BuildChooseOption({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isSelected = false,
    this.showTrailingArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4A67F6) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected
                          ? const Color(0xFF4A67F6)
                          : Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 34 / 2,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            if (showTrailingArrow)
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade600,
                size: 26,
              ),
          ],
        ),
      ),
    );
  }
}
