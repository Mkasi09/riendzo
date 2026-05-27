import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/views/feed/Post.dart';
import 'package:riendzo/views/feed/like_button_widget.dart';
import 'package:riendzo/views/profile/user_profile_screen.dart';
import 'package:riendzo/widgets/network_video_player.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PageController _mediaController = PageController();
  int _mediaIndex = 0;

  User? get _currentUser => _auth.currentUser;

  @override
  void dispose() {
    _mediaController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return timeago.format(timestamp.toDate());
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$userId').get();

    if (!snapshot.exists) {
      return {
        'profilePicture': '',
        'fullName': 'Unknown User',
        'isDefaultImage': true,
      };
    }

    final userData = snapshot.value as Map<dynamic, dynamic>;
    final profilePicture = (userData['profilePicture'] ?? '').toString();
    return {
      'profilePicture': profilePicture,
      'fullName': userData['name'] ?? 'Unknown User',
      'isDefaultImage': profilePicture.isEmpty,
    };
  }

  bool _isVideoMedia(int index) {
    final type = index < widget.post.mediaTypes.length
        ? widget.post.mediaTypes[index]
        : '';
    if (type == 'video') return true;

    final media = widget.post.mediaPaths[index].toLowerCase();
    return media.contains('.mp4') ||
        media.contains('.mov') ||
        media.contains('.m4v') ||
        media.contains('video%2f') ||
        media.contains('video/');
  }

  Future<void> _deletePost() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      await _firestore.collection('posts').doc(widget.post.postId).delete();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Post deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete post. Please try again.'),
        ),
      );
    }
  }

  void _openUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: widget.post.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (widget.post.userId == _currentUser?.uid)
            IconButton(
              tooltip: 'Delete post',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deletePost,
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostAuthorHeader(
                    userFuture: _getUserData(widget.post.userId),
                    timestamp: _formatTimestamp(widget.post.timestamp),
                    onTap: _openUserProfile,
                  ),
                  if (widget.post.content.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(widget.post.content, style: theme.textTheme.bodyLarge),
                  ],
                  if (widget.post.mediaPaths.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildMediaViewer(),
                  ],
                  const SizedBox(height: 16),
                  _buildActions(),
                  const SizedBox(height: 18),
                  InlinePostComments(postId: widget.post.postId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaViewer() {
    final mediaCount = widget.post.mediaPaths.length;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PageView.builder(
              controller: _mediaController,
              itemCount: mediaCount,
              onPageChanged: (index) => setState(() => _mediaIndex = index),
              itemBuilder: (context, index) {
                final media = widget.post.mediaPaths[index];
                if (_isVideoMedia(index)) {
                  return NetworkVideoPlayer(url: media, borderRadius: 12);
                }

                return CachedNetworkImage(
                  imageUrl: media,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                );
              },
            ),
          ),
        ),
        if (mediaCount > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              mediaCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == _mediaIndex ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: index == _mediaIndex
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return SizedBox(width: 170, child: LikeButtonWidget(post: widget.post));
  }
}

class InlinePostComments extends StatefulWidget {
  final String postId;

  const InlinePostComments({super.key, required this.postId});

  @override
  State<InlinePostComments> createState() => _InlinePostCommentsState();
}

class _InlinePostCommentsState extends State<InlinePostComments> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    return timeago.format(timestamp.toDate());
  }

  Future<String> _currentDisplayName(String userId) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$userId').get();
    if (!snapshot.exists) return 'Anonymous';
    return snapshot.child('name').value as String? ?? 'Anonymous';
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (text.isEmpty || currentUser == null || _isPosting) return;

    setState(() => _isPosting = true);

    try {
      final displayName = await _currentDisplayName(currentUser.uid);
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'userId': currentUser.uid,
            'content': text,
            'timestamp': Timestamp.now(),
            'displayName': displayName,
          });

      _commentController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to post comment.')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  prefixIcon: Icon(Icons.mode_comment_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Post comment',
              onPressed: _isPosting ? null : _addComment,
              icon: _isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .orderBy('timestamp', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final comments = snapshot.data?.docs ?? [];
            if (comments.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No comments yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return Column(
              children: comments.map((comment) {
                final data = comment.data() as Map<String, dynamic>;
                final isOwner = currentUser?.uid == data['userId'];
                return _InlineCommentTile(
                  displayName: (data['displayName'] ?? 'Anonymous').toString(),
                  content: (data['content'] ?? '').toString(),
                  timestamp: _formatTimestamp(data['timestamp'] as Timestamp?),
                  isOwner: isOwner,
                  onDelete: () => _deleteComment(comment.id),
                  replies: _InlineReplyList(
                    postId: widget.postId,
                    commentId: comment.id,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InlineCommentTile extends StatelessWidget {
  final String displayName;
  final String content;
  final String timestamp;
  final bool isOwner;
  final VoidCallback onDelete;
  final Widget replies;

  const _InlineCommentTile({
    required this.displayName,
    required this.content,
    required this.timestamp,
    required this.isOwner,
    required this.onDelete,
    required this.replies,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          timestamp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    IconButton(
                      tooltip: 'Delete comment',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(content, style: Theme.of(context).textTheme.bodyMedium),
              replies,
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineReplyList extends StatelessWidget {
  final String postId;
  final String commentId;

  const _InlineReplyList({required this.postId, required this.commentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        final replies = snapshot.data?.docs ?? [];
        if (replies.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 10, left: 24),
          child: Column(
            children: replies.map((reply) {
              final data = reply.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data['displayName'] ?? 'Anonymous').toString(),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text((data['content'] ?? '').toString()),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _PostAuthorHeader extends StatelessWidget {
  final Future<Map<String, dynamic>> userFuture;
  final String timestamp;
  final VoidCallback onTap;

  const _PostAuthorHeader({
    required this.userFuture,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: userFuture,
      builder: (context, snapshot) {
        final userData = snapshot.data;
        final profilePicture = (userData?['profilePicture'] ?? '').toString();
        final fullName = (userData?['fullName'] ?? 'Unknown User').toString();

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: profilePicture.isNotEmpty
                      ? NetworkImage(profilePicture)
                      : null,
                  child: profilePicture.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        timestamp,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
