import 'package:flutter/material.dart';

class Sections extends StatelessWidget {
  final String sectionName;
  final String trailingText;
  final double veritcalMargin;
  final VoidCallback? onTrailingTap;

  const Sections({
    super.key,
    required this.sectionName,
    required this.trailingText,
    required this.veritcalMargin,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: veritcalMargin),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sectionName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (trailingText.isNotEmpty)
            TextButton(onPressed: onTrailingTap, child: Text(trailingText)),
        ],
      ),
    );
  }
}
