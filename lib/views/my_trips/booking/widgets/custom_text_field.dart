import 'package:flutter/material.dart';

class CustomBookingTextField extends StatelessWidget {
  final TextEditingController? controller; // Add this line for controller
  final IconData? icon;
  final String text;
  final String hintText;
  final TextInputType keyboardType;
  final bool readOnly;

  const CustomBookingTextField({
    super.key,
    this.controller, // Add this line to initialize controller
    this.icon,
    required this.text,
    required this.hintText,
    required this.keyboardType,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: TextField(
        controller: controller, // Controller to manage input text
        keyboardType: keyboardType,
        readOnly: readOnly,
        maxLines: null,
        textAlign: TextAlign.justify,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon) : null, // Add icon if provided
          labelText: text, // Field label
          hintText: hintText,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 1.0),
          ),
        ),
      ),
    );
  }
}
