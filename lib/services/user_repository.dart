import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;

class UserRepository {
  const UserRepository._();

  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static DocumentReference<Map<String, dynamic>> profileRef(String userId) {
    return _users.doc(userId);
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final snapshot = await profileRef(userId).get();
    return snapshot.data();
  }

  static Future<void> saveProfile({
    required String userId,
    required String name,
    required String email,
    String profilePicture = '',
  }) {
    return profileRef(userId).set({
      'name': name,
      'email': email,
      'profilePicture': profilePicture,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> createProfile(User user, {required String name}) {
    return profileRef(user.uid).set({
      'name': name,
      'email': user.email ?? '',
      'profilePicture': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> migrateCurrentUserFromRealtimeDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestoreProfile = await profileRef(user.uid).get();
    final firestoreData = firestoreProfile.data();
    final legacySnapshot = await rtdb.FirebaseDatabase.instance
        .ref('users/${user.uid}')
        .get();
    final legacy = legacySnapshot.value is Map
        ? Map<dynamic, dynamic>.from(legacySnapshot.value as Map)
        : <dynamic, dynamic>{};

    final name =
        (firestoreData?['name'] ??
                legacy['name'] ??
                user.displayName ??
                'Traveller')
            .toString()
            .trim();
    final email =
        (firestoreData?['email'] ?? legacy['email'] ?? user.email ?? '')
            .toString();
    final profilePicture =
        (firestoreData?['profilePicture'] ??
                legacy['profilePicture'] ??
                user.photoURL ??
                '')
            .toString();

    final batch = FirebaseFirestore.instance.batch();
    batch.set(profileRef(user.uid), {
      'name': name.isEmpty ? 'Traveller' : name,
      'email': email,
      'profilePicture': profilePicture,
      'migratedFromRealtimeDatabaseAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _legacyIds(legacy['following']).forEach((targetId) {
      batch.set(
        profileRef(user.uid).collection('following').doc(targetId),
        {'userId': targetId, 'createdAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    });
    _legacyIds(legacy['followers']).forEach((followerId) {
      batch.set(
        profileRef(user.uid).collection('followers').doc(followerId),
        {'userId': followerId, 'createdAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    });

    await batch.commit();
  }

  static List<String> _legacyIds(dynamic value) {
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value != false && entry.value != null)
          .map((entry) => entry.key.toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value.whereType<String>().where((id) => id.isNotEmpty).toList();
    }
    return const [];
  }
}
