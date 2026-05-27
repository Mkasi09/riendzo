import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Sign out Method
Future<void> signOut(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  Navigator.pushReplacementNamed(context, '/login'); // Navigate to the login screen after sign out
}

// Show Logout Confirmation Dialog
void showLogoutConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              signOut(context); // Pass context to signOut
            },
            child: const Text('Logout'),
          ),
        ],
      );
    },
  );
}
