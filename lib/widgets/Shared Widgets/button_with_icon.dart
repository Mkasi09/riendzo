import 'package:flutter/material.dart';

class ButtonWithIcon extends StatelessWidget {
  final double horizontalPadding, verticalPadding, TextSize;
  final Color cardColor, textColor;
  final String text;
  final VoidCallback? onPressed;
  final IconData? iconData;
  final Color? iconColor;

  const ButtonWithIcon({
    super.key,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.cardColor,
    required this.onPressed,
    required this.text,
    required this.textColor,
    required this.TextSize,
    this.iconData,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            iconData ?? Icons.arrow_forward_rounded,
            color: enabled ? iconColor ?? textColor : null,
          ),
          label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: cardColor,
            foregroundColor: textColor,
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10 + verticalPadding,
            ),
            textStyle: TextStyle(
              fontSize: TextSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
