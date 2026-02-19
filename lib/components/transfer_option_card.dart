// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TransferOptionCard extends StatelessWidget {
  const TransferOptionCard({
    Key? key,
    required this.title,
    required this.image,
    required this.onTap,

  }) : super(key: key);

  final String title;
  final String image;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xffF2F6FF), const Color(0xffEAF0FF)],

                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.blue.shade200, width: 1.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
               
                Image.asset(image, height: 35, width: 35, color: Colors.blue),
                // Icon(icon, size: 30, color: Colors.blue),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          /// Coming Soon Ribbon
        ],
      ),
    );
  }
}
