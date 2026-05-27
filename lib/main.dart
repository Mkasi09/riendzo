import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:riendzo/firebase_options.dart';
import 'package:riendzo/settings/themes.dart';
import 'package:riendzo/views/authentication/authentificationPage.dart';
import 'package:riendzo/widgets/userProfileProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (_) {
    // Persistence can only be enabled before database references are created.
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProfileProvider(),
      child: const Riendzo(),
    ),
  );

  unawaited(
    FirebaseAppCheck.instance
        .activate(androidProvider: AndroidProvider.debug)
        .catchError((_) {}),
  );
}

class Riendzo extends StatelessWidget {
  const Riendzo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.defaultTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthPage(),
    );
  }
}
