import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserProfileProvider with ChangeNotifier {
  String? _profilePictureUrl;
  bool _isLoading = true;

  String? get profilePictureUrl => _profilePictureUrl;
  bool get isLoading => _isLoading;

  Future<void> fetchUserProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref().child('users').child(user.uid);
      try {
        final snapshot = await userRef.get();
        if (snapshot.exists) {
          _profilePictureUrl = snapshot.child('profilePicture').value as String?;
        }
      } catch (e) {
        // Handle error
      }
    }
    _isLoading = false;
    notifyListeners();
  }
}
