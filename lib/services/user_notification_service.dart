import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationService {
  const UserNotificationService._();

  static Future<void> create({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? tripId,
    String? tripName,
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
          'tripName': tripName,
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

  static Future<void> markAllRead(String userId) async {
    if (userId.trim().isEmpty) return;
    final unread = await FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(userId)
        .collection('items')
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final item in unread.docs) {
      batch.update(item.reference, {'read': true});
    }
    if (unread.docs.isNotEmpty) await batch.commit();
  }
}
