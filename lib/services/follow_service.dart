import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riendzo/services/user_notification_service.dart';
import 'package:riendzo/services/user_repository.dart';

class FollowService {
  const FollowService._();

  static CollectionReference<Map<String, dynamic>> _relationshipRef(
    String userId,
    String relationship,
  ) {
    return UserRepository.profileRef(userId).collection(relationship);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> followersStream(
    String userId,
  ) {
    return _relationshipRef(userId, 'followers').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> followingStream(
    String userId,
  ) {
    return _relationshipRef(userId, 'following').snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> relationshipStream({
    required String followerId,
    required String targetUserId,
  }) {
    return _relationshipRef(
      followerId,
      'following',
    ).doc(targetUserId).snapshots();
  }

  static Future<void> setFollowing({
    required String followerId,
    required String targetUserId,
    required bool shouldFollow,
    required String followerName,
  }) async {
    if (followerId.isEmpty ||
        targetUserId.isEmpty ||
        followerId == targetUserId) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final followingRef = _relationshipRef(
      followerId,
      'following',
    ).doc(targetUserId);
    final followerRef = _relationshipRef(
      targetUserId,
      'followers',
    ).doc(followerId);
    if (shouldFollow) {
      batch.set(followingRef, {
        'userId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(followerRef, {
        'userId': followerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.delete(followingRef);
      batch.delete(followerRef);
    }
    await batch.commit();

    if (shouldFollow) {
      await UserNotificationService.create(
        userId: targetUserId,
        type: 'new_follower',
        title: 'New follower',
        message: '$followerName started following you.',
        actorUserId: followerId,
      );
    }
  }

  static int count(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    return snapshot?.size ?? 0;
  }

  static bool isFollowing(DocumentSnapshot<Map<String, dynamic>>? snapshot) {
    return snapshot?.exists == true;
  }
}
