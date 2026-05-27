import 'package:flutter/material.dart';

class IconTextRow extends StatelessWidget {
  final IconData icon;
  final int iconSize;
  final String text;
  final Color color;

  const IconTextRow({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: iconSize * 1.0),
        Text(text, style: const TextStyle(fontSize: 15)),
      ],
    );
  }
}
