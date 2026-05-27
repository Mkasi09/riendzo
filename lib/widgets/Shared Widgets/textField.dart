import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  String hintText, labelText;
  TextInputType keyboardType;
  bool hideText;
  var suffixIcon;

  CustomTextField({
    super.key,
    required this.hintText,
    required this.labelText,
    required this.keyboardType,
    required this.hideText,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          suffixIcon: suffixIcon,
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.white,
            ),
          ),
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Colors.white12,
          ),
          label: Text(labelText),
          labelStyle: const TextStyle(color: Colors.white),
        ),
        keyboardType: keyboardType,
        obscureText: hideText,
      ),
    );
  }
}
