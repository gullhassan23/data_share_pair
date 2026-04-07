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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade200, width: 1.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/icons/bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(image, height: 35, width: 35, color: Colors.blue),
                  const SizedBox(height: 14),
                  Text(
                    textAlign: TextAlign.center,
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
