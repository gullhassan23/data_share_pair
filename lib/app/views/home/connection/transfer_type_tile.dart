// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// /// A clickable tile for a transfer type (Bluetooth, Wi‑Fi Scanner, Wi‑Fi Same Network).
// /// Shows selection state and an optional PRO badge.
// class TransferTypeTile extends StatelessWidget {
//   const TransferTypeTile({
//     super.key,
//     required this.title,
//     this.subtitle,
//     required this.icon,
//     required this.isSelected,
//     required this.onTap,
//     this.isPro = false,
//   });

//   final String title;
//   final String? subtitle;
//   final IconData icon;
//   final bool isSelected;
//   final VoidCallback onTap;
//   final bool isPro;

//   static const double _horizontalPadding = 20;
//   static const double _verticalPadding = 16;
//   static const double _spacing = 12;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final primary = theme.colorScheme.primary;
//     final surface = theme.colorScheme.surface;
//     final onSurface = theme.colorScheme.onSurface;
//     final outline = theme.colorScheme.outline;

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(16),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: const EdgeInsets.symmetric(
//             horizontal: _horizontalPadding,
//             vertical: _verticalPadding,
//           ),
//           decoration: BoxDecoration(
//             color: isSelected ? primary.withOpacity(0.12) : surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(
//               color: isSelected ? primary : outline.withOpacity(0.4),
//               width: isSelected ? 2 : 1,
//             ),
//             boxShadow: isSelected
//                 ? [
//                     BoxShadow(
//                       color: primary.withOpacity(0.15),
//                       blurRadius: 12,
//                       offset: const Offset(0, 4),
//                     ),
//                   ]
//                 : null,
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color: isSelected
//                       ? primary.withOpacity(0.2)
//                       : outline.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(
//                   icon,
//                   size: 26,
//                   color: isSelected ? primary : onSurface.withOpacity(0.7),
//                 ),
//               ),
//               const SizedBox(width: _spacing),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Row(
//                       children: [
//                         Flexible(
//                           child: Text(
//                             title,
//                             style: GoogleFonts.roboto(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                               color: onSurface,
//                             ),
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                         if (isPro) ...[
//                           const SizedBox(width: 8),
//                           _ProChip(),
//                         ],
//                       ],
//                     ),
//                     if (subtitle != null && subtitle!.isNotEmpty) ...[
//                       const SizedBox(height: 4),
//                       Text(
//                         subtitle!,
//                         style: GoogleFonts.roboto(
//                           fontSize: 13,
//                           color: outline,
//                         ),
//                         maxLines: 3,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//               Icon(
//                 isSelected ? Icons.check_circle : Icons.circle_outlined,
//                 size: 24,
//                 color: isSelected ? primary : outline.withOpacity(0.5),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _ProChip extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final primary = Theme.of(context).colorScheme.primary;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: primary.withOpacity(0.15),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: primary.withOpacity(0.5), width: 1),
//       ),
//       child: Text(
//         'PRO',
//         style: GoogleFonts.roboto(
//           fontSize: 11,
//           fontWeight: FontWeight.bold,
//           color: primary,
//           letterSpacing: 0.5,
//         ),
//       ),
//     );
//   }
// }
