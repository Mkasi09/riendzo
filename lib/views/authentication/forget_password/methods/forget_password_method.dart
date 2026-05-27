import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../signIn/sign_in.dart';
import '../../widgets/custom_error_msg_snackBar.dart';
import '../../widgets/custom_progress_bar.dart';

void forgetPassword({userEmail, context}) async {
//Show progress bar while signing in
  progressBar(
    context: context,
    child: const CircularProgressIndicator(),
  );
//Authenticate user with Firebase
  await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);

//remove the circle indicator as soon as logged in
  Navigator.pop(context);

  errorMessage(
    context: context,
    child: const Text('Link sent to your Email'),
  );

  Navigator.pop(context);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (e) => const SignInPage(),
    ),
  );
}
