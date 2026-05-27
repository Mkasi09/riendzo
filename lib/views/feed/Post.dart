// Post.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String content;
  final List<String> mediaPaths;
  final List<String> mediaTypes;
  final String userId;
  final Timestamp timestamp;
  bool isLiked;
  int likeCount;

  PostModel({
    required this.postId,
    required this.content,
    required this.mediaPaths,
    this.mediaTypes = const [],
    required this.userId,
    required this.timestamp,
    this.isLiked = false,
    this.likeCount = 0,
  });
}
