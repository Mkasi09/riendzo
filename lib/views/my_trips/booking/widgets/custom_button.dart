import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final double horizontalPadding, TextSize;
  final Color cardColor, textColor;
  final String text;
  final VoidCallback? onPressed;
  final Widget? child;

  const CustomButton({
    super.key,
    required this.cardColor,
    required this.onPressed,
    required this.text,
    required this.textColor,
    required this.horizontalPadding,
    required this.TextSize,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: cardColor,
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: TextStyle(
              fontSize: TextSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          child:
              child ?? Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
