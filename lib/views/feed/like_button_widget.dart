import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'Post.dart';

class LikeButtonWidget extends StatefulWidget {
  final PostModel post;

  const LikeButtonWidget({super.key, required this.post});

  @override
  _LikeButtonWidgetState createState() => _LikeButtonWidgetState();
}

class _LikeButtonWidgetState extends State<LikeButtonWidget> {
  bool isLiked = false;
  int likeCount = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchLikeStatus();
    _listenToLikeCount();
  }

  void _fetchLikeStatus() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final likeRef = FirebaseDatabase.instance.ref(
      'posts/${widget.post.postId}/likes/${currentUser.uid}',
    );

    final likeSnapshot = await likeRef.get();
    if (!mounted) return;
    setState(() {
      isLiked = likeSnapshot.exists && likeSnapshot.value == true;
    });
  }

  void _listenToLikeCount() {
    FirebaseDatabase.instance
        .ref('posts/${widget.post.postId}/likeCount')
        .onValue
        .listen((event) {
          final newLikeCount = event.snapshot.value as int? ?? 0;
          if (!mounted) return;
          setState(() {
            likeCount = newLikeCount;
          });
        });
  }

  void _toggleLike() async {
    if (_isProcessing) return; // Debounce tap events
    _isProcessing = true;

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _isProcessing = false;
      return;
    }

    final likeRef = FirebaseDatabase.instance.ref(
      'posts/${widget.post.postId}/likes/${currentUser.uid}',
    );
    final likeCountRef = FirebaseDatabase.instance.ref(
      'posts/${widget.post.postId}/likeCount',
    );

    final likeSnapshot = await likeRef.get();
    final wasLiked = likeSnapshot.exists && likeSnapshot.value == true;

    // Optimistically update the UI
    if (mounted) {
      setState(() {
        isLiked = !wasLiked;
        likeCount += wasLiked ? -1 : 1;
      });
    }

    // Update Firebase using a transaction for `likeCount`
    if (wasLiked) {
      await likeRef.remove();
      likeCountRef.runTransaction((currentCount) {
        int updatedCount =
            (currentCount as int? ?? 0) - 1; // Cast to int and subtract
        return Transaction.success(updatedCount);
      });
    } else {
      await likeRef.set(true);
      likeCountRef.runTransaction((currentCount) {
        int updatedCount =
            (currentCount as int? ?? 0) + 1; // Cast to int and add
        return Transaction.success(updatedCount);
      });
    }

    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _toggleLike,
            child: Container(
              decoration: BoxDecoration(
                color: isLiked
                    ? Colors.red[100]!.withOpacity(0.8)
                    : Colors.grey[200]!.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked
                          ? Colors.red.withOpacity(0.9)
                          : Colors.grey,
                    ),
                    SizedBox(width: 5.0),
                    Text(
                      '$likeCount likes',
                      style: TextStyle(
                        fontSize: 14,
                        color: isLiked ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
