import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsPopup extends StatefulWidget {
  final String contentId; // Can be tripId or postId
  final String contentType; // Either 'trip' or 'post'


  const CommentsPopup({
    super.key,
    required this.contentId,
    required this.contentType,

  });



  @override
  _CommentsPopupState createState() => _CommentsPopupState();
}

class _CommentsPopupState extends State<CommentsPopup> {
  final TextEditingController _commentController = TextEditingController();
  String? replyingToCommentId;
  String? replyingToDisplayName;
  int commentCount = 0;
  String? editingCommentId; // To track which comment is being edited
  String? editingReplyId; // To track which reply is being edited
  Map<String, bool> repliesVisibility = {};

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown time";
    return timeago.format(timestamp.toDate());
  }

  @override
  void initState() {
    super.initState();
    _getCommentCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _getCommentCount() async {
    final commentsSnapshot = await FirebaseFirestore.instance
        .collection(widget.contentType == 'post' ? 'posts' : 'trips')
        .doc(widget.contentId)
        .collection('comments')
        .get();

    int totalCommentCount = commentsSnapshot.size;

    for (var comment in commentsSnapshot.docs) {
      final repliesSnapshot = await FirebaseFirestore.instance
          .collection(widget.contentType == 'post' ? 'posts' : 'trips')
          .doc(widget.contentId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies')
          .get();

      totalCommentCount += repliesSnapshot.size;
    }

    setState(() {
      commentCount = totalCommentCount;
    });
  }

  Future<void> _addComment() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty')),
      );
      return;
    }

    try {
      final userRef = FirebaseDatabase.instance.ref().child('users').child(currentUser.uid);
      final userSnapshot = await userRef.get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final displayName = userData['name'] ?? 'Anonymous';

        final commentData = {
          'userId': currentUser.uid,
          'content': _commentController.text,
          'timestamp': Timestamp.now(),
          'displayName': displayName,
        };

        String collectionPath = widget.contentType == 'post' ? 'posts' : 'trips';

        if (editingCommentId != null) {
          // Update the existing comment
          await FirebaseFirestore.instance
              .collection(collectionPath)
              .doc(widget.contentId)
              .collection('comments')
              .doc(editingCommentId)
              .update({'content': _commentController.text});

          setState(() {
            editingCommentId = null;
            _commentController.clear();
          });
        } else if (editingReplyId != null && replyingToCommentId != null) {
          // Update the existing reply
          await FirebaseFirestore.instance
              .collection(collectionPath)
              .doc(widget.contentId)
              .collection('comments')
              .doc(replyingToCommentId)
              .collection('replies')
              .doc(editingReplyId)
              .update({'content': _commentController.text});

          setState(() {
            editingReplyId = null;
            replyingToCommentId = null;
            _commentController.clear();
          });
        } else if (replyingToCommentId == null) {
          // Add new comment
          await FirebaseFirestore.instance
              .collection(collectionPath)
              .doc(widget.contentId)
              .collection('comments')
              .add(commentData);
          setState(() {
            commentCount++;
          });
        } else {
          // Add new reply
          await FirebaseFirestore.instance
              .collection(collectionPath)
              .doc(widget.contentId)
              .collection('comments')
              .doc(replyingToCommentId)
              .collection('replies')
              .add(commentData);

          setState(() {
            replyingToCommentId = null;
          });
        }

        _commentController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found in database')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    }
  }

Future<void> _deleteComment(String commentId, {String? replyId}) async {
    try {
      if (replyId == null) {
        await FirebaseFirestore.instance
            .collection(widget.contentType == 'post' ? 'posts' : 'trips')
            .doc(widget.contentId)
            .collection('comments')
            .doc(commentId)
            .delete();
      } else {
        await FirebaseFirestore.instance
            .collection(widget.contentType == 'post' ? 'posts' : 'trips')
            .doc(widget.contentId)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .doc(replyId)
            .delete();
      }

      setState(() {
        commentCount--;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  void _toggleReply(String commentId, String commentDisplayName) {
    setState(() {
      if (replyingToCommentId == commentId) {
        replyingToCommentId = null;
        replyingToDisplayName = null;
        _commentController.clear();
      } else {
        replyingToCommentId = commentId;
        replyingToDisplayName = commentDisplayName;
      }
    });
  }

  void _toggleRepliesVisibility(String commentId) {
    setState(() {
      repliesVisibility[commentId] = !(repliesVisibility[commentId] ?? false);
    });
  }

  void _showCommentOptions(String commentId, bool isOwner,
      {String? replyId, String? content}) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  _toggleReply(commentId, ''); // Use the actual display name
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context); // Close the modal
                    if (replyId == null) {
                      // Editing a comment
                      setState(() {
                        editingCommentId = commentId;
                        _commentController.text = content ?? '';
                      });
                    } else {
                      // Editing a reply
                      setState(() {
                        editingReplyId = replyId;
                        replyingToCommentId = commentId;
                        _commentController.text = content ?? '';
                      });
                    }
                  },
                ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(context); // Close the modal
                    _deleteComment(commentId, replyId: replyId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('$commentCount comments'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(widget.contentType == 'post' ? 'posts' : 'trips')
                  .doc(widget.contentId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final commentId = comment.id;
                    final commentContent = comment['content'] ?? 'No content';
                    final displayName = comment['displayName'] ?? 'Anonymous';
                    final formattedDate = _formatTimestamp(comment['timestamp']);


                    final isOwner = currentUser?.uid == comment['userId'];

                    return GestureDetector(
                      onLongPress: () =>
                          _showCommentOptions(commentId, isOwner),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(commentContent),
                                  Text(formattedDate,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Aligns children at the two ends
                                    children: [
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection(widget.contentType == 'post' ? 'posts' : 'trips')
                                            .doc(widget.contentId)
                                            .collection('comments')
                                            .doc(commentId)
                                            .collection('replies')
                                            .snapshots(),
                                        builder: (context, replySnapshot) {
                                          if (!replySnapshot.hasData) {
                                            return const SizedBox();
                                          }

                                          final replyCount = replySnapshot.data!.size;

                                          return TextButton(
                                            onPressed: () => _toggleRepliesVisibility(commentId),
                                            child: Text(
                                              repliesVisibility[commentId] == true
                                                  ? 'Hide Replies ($replyCount)'
                                                  : 'View Replies ($replyCount)',
                                            ),
                                          );
                                        },
                                      ),
                                      // Moved the reply button to the right
                                      InkWell(
                                        onTap: () => _toggleReply(commentId, displayName), // Add your onTap functionality
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.reply,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4.0),
                                            Text(
                                              'Reply',
                                              style: TextStyle(color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                ],
                              ),
                            ),
                            if (repliesVisibility[commentId] == true)
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection(widget.contentType == 'post' ? 'posts' : 'trips')
                                    .doc(widget.contentId)
                                    .collection('comments')
                                    .doc(commentId)
                                    .collection('replies')
                                    .snapshots(),
                                builder: (context, replySnapshot) {
                                  if (!replySnapshot.hasData) {
                                    return const SizedBox();
                                  }

                                  final replies = replySnapshot.data!.docs;

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: replies.length,
                                    itemBuilder: (context, replyIndex) {
                                      final reply = replies[replyIndex];
                                      final replyId = reply.id;
                                      final replyContent =
                                          reply['content'] ?? 'No content';
                                      final replyDisplayName =
                                          reply['displayName'] ?? 'Anonymous';
                                      final formattedReplyDate = _formatTimestamp(reply['timestamp']);
                                      final isReplyOwner =
                                          currentUser?.uid == reply['userId'];

                                      return GestureDetector(
                                        onLongPress: () => _showCommentOptions(
                                            commentId, isReplyOwner,
                                            replyId: replyId),
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4.0, horizontal: 16.0),
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(replyDisplayName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(replyContent),
                                              const SizedBox(height: 4),
                                              Text(formattedReplyDate,
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (replyingToDisplayName != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Replying to $replyingToDisplayName'),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: replyingToCommentId == null
                          ? 'Write a comment...'
                          : 'Write a reply...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(20.0), // Rounded corners
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            20.0), // Rounded corners when focused
                        borderSide: const BorderSide(
                            color: Colors
                                .blue), // Customize border color when focused
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            20.0), // Rounded corners when not focused
                        borderSide: const BorderSide(
                            color: Colors
                                .grey), // Customize border color when enabled
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
