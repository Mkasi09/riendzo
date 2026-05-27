import 'package:flutter/material.dart';

class CustomIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double? iconSize;

  const CustomIcon({
    super.key,
    required this.icon,
    required this.color,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color, size: iconSize);
  }
}
