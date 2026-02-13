// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

class Custombutton extends StatelessWidget {
  final String text;
  final Color textColor;
  final List<Color> colors; // can be 1 or more colors
  final VoidCallback ontap;

  Custombutton({
    Key? key,
    required this.text,
    required this.textColor,
    required this.colors,
    required this.ontap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        height: 50,
        width: 230,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                colors.length == 1
                    ? [colors[0], colors[0]] // if only 1 color, repeat it
                    : colors, // else use all colors
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
