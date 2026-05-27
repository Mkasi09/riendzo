import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/views/authentication/signIn/sign_in.dart';
import 'package:riendzo/widgets/persistent_navbar.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth;
    try {
      auth = FirebaseAuth.instance;
    } catch (_) {
      return const Scaffold(body: SignInPage());
    }

    return Scaffold(
      body: StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        initialData: auth.currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }

          return const SignInPage();
        },
      ),
    );
  }
}
