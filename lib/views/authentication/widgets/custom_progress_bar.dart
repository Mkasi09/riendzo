import 'package:flutter/material.dart';

void progressBar({context, child}) {
  showDialog(
    context: context,
    builder: (context) {
      return Center(
        child: child,
      );
    },
  );
}