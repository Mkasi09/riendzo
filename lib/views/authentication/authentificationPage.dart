import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/services/user_repository.dart';
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
            return _MigrationGate(user: snapshot.data!);
          }

          return const SignInPage();
        },
      ),
    );
  }
}

class _MigrationGate extends StatefulWidget {
  final User user;

  const _MigrationGate({required this.user});

  @override
  State<_MigrationGate> createState() => _MigrationGateState();
}

class _MigrationGateState extends State<_MigrationGate> {
  @override
  void initState() {
    super.initState();
    UserRepository.migrateCurrentUserFromRealtimeDatabase().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen();
  }
}
