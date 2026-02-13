import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardtype;
  final String hintname;
  final String validatetext;
  final String icon;
  CustomTextField({
    required this.controller,
    required this.keyboardtype,
    required this.hintname,
    required this.icon,
    required this.validatetext,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardtype,
      decoration: inputDecoration(hint: hintname, icon: icon),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Enter $validatetext";
        }
        return null;
      },
    );
  }
}

InputDecoration inputDecoration({
  required String hint,
  required String icon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white),

    prefixIcon: Padding(
      padding: const EdgeInsets.all(12),
      child: Image.asset(icon, width: 18, height: 18),
    ),
    suffixIcon: suffix,
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white),
    ),
  );
}
