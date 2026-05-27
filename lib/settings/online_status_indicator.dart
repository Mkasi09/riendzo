import 'package:flutter/material.dart';

class OnlineStatusIndicator extends StatelessWidget {
  Color borderColor, statusColor;

  OnlineStatusIndicator({
    super.key,
    required this.borderColor,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: borderColor,
        borderRadius: BorderRadius.circular(
          25,
        ),
      ),
      child: Icon(
        Icons.circle,
        color: statusColor,
        size: 15,
      ),
    );
  }
}
