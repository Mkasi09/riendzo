import 'package:flutter/material.dart';

void errorMessage({context, child}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Center(
        child: child,
      ),
    ),
  );
}