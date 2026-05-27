import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

Future<void> signUp({
  required BuildContext context,
  required String userEmail,
  required String userPassword,
  required String userName,
}) async {
  try {
    // Create a user with Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: userEmail,
      password: userPassword,
    );

    // Get the created user
    User? user = userCredential.user;

    // Check if the user is successfully created
    if (user != null) {
      String userId = user.uid;

      // Reference to the Realtime Database for the specific user
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId");

      // Save user details to the Realtime Database
      await userRef.set({
        "email": userEmail,
        "name": userName,
        "onlineStatus": false,
        "profilePicture": "",
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up successful!')),
      );

      // Navigate to sign-in page after successful sign-up
      Navigator.pushReplacementNamed(context, '/SignIn');
    }
  } on FirebaseAuthException catch (e) {
    String errorMessage;
    switch (e.code) {
      case 'weak-password':
        errorMessage = 'The password provided is too weak.';
        break;
      case 'email-already-in-use':
        errorMessage = 'The account already exists for that email.';
        break;
      case 'invalid-email':
        errorMessage = 'The email address is badly formatted.';
        break;
      default:
        errorMessage = 'Something went wrong. Error: ${e.message}';
    }

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  } catch (e) {
    // Handle any other errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to sign up: ${e.toString()}')),
    );
  }
}
