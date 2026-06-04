import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationService {
  const UserNotificationService._();

  static Future<void> create({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? tripId,
    String? actorUserId,
  }) async {
    if (userId.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(userId)
        .collection('items')
        .add({
          'type': type,
          'title': title,
          'message': message,
          'tripId': tripId,
          'actorUserId': actorUserId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> markRead({
    required String userId,
    required String notificationId,
  }) async {
    if (userId.trim().isEmpty || notificationId.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(userId)
        .collection('items')
        .doc(notificationId)
        .update({'read': true});
  }
}
