//Sign in Method
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_error_msg_snackBar.dart';

Future<void> signIn({
  required GlobalKey<FormState> formSignInKey,
  required String userEmail,
  required String userPassword,
  required bool rememberPassword,
  required BuildContext context,
}) async {
  // validate text field content
  if (!formSignInKey.currentState!.validate()) {
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: userEmail.trim(),
      password: userPassword,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  } on FirebaseAuthException {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      errorMessage(
        context: context,
        child: const Text('Invalid credentials'),
      );
    }
  }
}
