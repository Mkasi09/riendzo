import 'package:flutter/material.dart';

class LineDivider extends StatelessWidget {
  final int screenWidthPercentage;
  final Color color;

  const LineDivider({
    super.key,
    required this.screenWidthPercentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: MediaQuery.of(context).size.width * screenWidthPercentage / 100,
      color: color,
    );
  }
}
