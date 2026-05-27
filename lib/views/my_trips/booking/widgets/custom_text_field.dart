import 'package:flutter/material.dart';

class CustomBookingTextField extends StatelessWidget {
  final TextEditingController? controller; // Add this line for controller
  final IconData? icon;
  final String text;
  final String hintText;
  final TextInputType keyboardType;


  const CustomBookingTextField({
    super.key,
    this.controller, // Add this line to initialize controller
    this.icon,
    required this.text,
    required this.hintText,
    required this.keyboardType,
    required bool readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: TextField(
        controller: controller, // Controller to manage input text
        keyboardType: keyboardType,
        maxLines: null,
        textAlign: TextAlign.justify,
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon) : null, // Add icon if provided
          labelText: text, // Field label
          hintText: hintText,
    border: OutlineInputBorder( // Single border style
    borderSide: BorderSide(color: Colors.grey, width: 1.0),
          // Placeholder text
           // Box around the field
        ),
      ),
    ));
  }
}
