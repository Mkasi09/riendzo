import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/material.dart';
import 'package:riendzo/views/feed/Post.dart';
import 'package:riendzo/views/feed/like_button_widget.dart';
import 'package:riendzo/views/feed/post_detail_screen.dart';
import 'package:riendzo/views/my_trips/trip_details.dart';
import 'package:riendzo/widgets/network_video_player.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/Shared Widgets/comments_popup.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> _getUserData() async {
    final snapshot = await rtdb.FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.userId)
        .get();

    if (!snapshot.exists) {
      return {'fullName': 'Unknown User', 'email': '', 'profilePicture': ''};
    }

    return {
      'fullName': snapshot.child('name').value as String? ?? 'Unknown User',
      'email': snapshot.child('email').value as String? ?? '',
      'profilePicture': snapshot.child('profilePicture').value as String? ?? '',
    };
  }

  Future<List<PostModel>> _getPostsWithLikes(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final currentUser = _auth.currentUser;

    return Future.wait(
      docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        var isLiked = false;

        if (currentUser != null) {
          final likeDoc = await _firestore
              .collection('posts')
              .doc(doc.id)
              .collection('likes')
              .doc(currentUser.uid)
              .get();
          isLiked = likeDoc.exists && (likeDoc.data()?['liked'] ?? false);
        }

        return PostModel(
          postId: doc.id,
          content: data['content'] ?? '',
          mediaPaths: List<String>.from(data['mediaUrls'] ?? []),
          mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
          userId: data['userId'] ?? '',
          timestamp: data['timestamp'],
          isLiked: isLiked,
          likeCount: data['likeCount'] ?? 0,
        );
      }),
    );
  }

  Future<int> _getTotalCommentCountWithReplies(String postId) async {
    var totalCommentCount = 0;
    final commentsSnapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .get();

    for (final commentDoc in commentsSnapshot.docs) {
      totalCommentCount += 1;
      final repliesSnapshot = await commentDoc.reference
          .collection('replies')
          .get();
      totalCommentCount += repliesSnapshot.size;
    }

    return totalCommentCount;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return timeago.format(timestamp.toDate());
  }

  bool _isVideoMedia(
    List<String> mediaPaths,
    List<String> mediaTypes,
    int index,
  ) {
    final type = index < mediaTypes.length ? mediaTypes[index] : '';
    if (type == 'video') return true;
    final media = mediaPaths[index].toLowerCase();
    return media.contains('.mp4') ||
        media.contains('.mov') ||
        media.contains('.m4v') ||
        media.contains('video%2f') ||
        media.contains('video/');
  }

  void _openPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  void _openCommentPopup(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CommentsPopup(contentId: post.postId, contentType: 'post'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getUserData(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data;
        final fullName = userData?['fullName'] ?? 'Profile';
        final profilePicture = userData?['profilePicture'] ?? '';
        final email = userData?['email'] ?? '';

        return Scaffold(
          appBar: AppBar(title: Text(fullName)),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('posts')
                .where('userId', isEqualTo: widget.userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, postsSnapshot) {
              return FutureBuilder<List<PostModel>>(
                future: _getPostsWithLikes(postsSnapshot.data?.docs ?? []),
                builder: (context, postsFuture) {
                  final posts = postsFuture.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _PublicProfileHeader(
                        fullName: fullName,
                        email: email,
                        profilePicture: profilePicture,
                        postCount: posts.length,
                        isLoading:
                            userSnapshot.connectionState ==
                            ConnectionState.waiting,
                      ),
                      const SizedBox(height: 14),
                      _UserTripSection(
                        title: 'Ongoing Trips',
                        emptyText: 'No ongoing trips yet.',
                        query: _firestore
                            .collection('trips')
                            .where('userId', isEqualTo: widget.userId)
                            .where('status', isEqualTo: 'ongoing'),
                      ),
                      const SizedBox(height: 14),
                      _UserTripSection(
                        title: 'Past Trips',
                        emptyText: 'No past trips yet.',
                        query: _firestore
                            .collection('trips')
                            .where('userId', isEqualTo: widget.userId)
                            .where('status', isEqualTo: 'completed'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Posts',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      if (postsSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          postsFuture.connectionState ==
                              ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (posts.isEmpty)
                        const _EmptyPublicPostsCard()
                      else
                        ...posts.map((post) => _buildPostItem(post, fullName)),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostItem(PostModel post, String fullName) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _openPostDetail(post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(fullName, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    _formatTimestamp(post.timestamp),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (post.content.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(post.content, style: theme.textTheme.bodyLarge),
              ),
            if (post.mediaPaths.isNotEmpty)
              _buildMediaSection(post.mediaPaths, post.mediaTypes),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(child: LikeButtonWidget(post: post)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FutureBuilder<int>(
                      future: _getTotalCommentCountWithReplies(post.postId),
                      builder: (context, snapshot) {
                        return FilledButton.tonalIcon(
                          onPressed: () => _openCommentPopup(post),
                          icon: const Icon(Icons.mode_comment_outlined),
                          label: Text('${snapshot.data ?? 0} comments'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(List<String> mediaPaths, List<String> mediaTypes) {
    if (mediaPaths.length == 1) {
      final media = mediaPaths.first;
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _isVideoMedia(mediaPaths, mediaTypes, 0)
            ? NetworkVideoPlayer(borderRadius: 0, url: media)
            : CachedNetworkImage(
                imageUrl: media,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image_outlined, size: 48),
              ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: mediaPaths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final media = mediaPaths[index];
        if (_isVideoMedia(mediaPaths, mediaTypes, index)) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NetworkVideoPlayer(url: media, borderRadius: 12),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: media,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }
}

class _PublicProfileHeader extends StatelessWidget {
  final String fullName;
  final String email;
  final String profilePicture;
  final int postCount;
  final bool isLoading;

  const _PublicProfileHeader({
    required this.fullName,
    required this.email,
    required this.profilePicture,
    required this.postCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: profilePicture.isNotEmpty
                  ? CachedNetworkImageProvider(profilePicture)
                  : null,
              child: profilePicture.isEmpty
                  ? Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 40,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    const LinearProgressIndicator()
                  else
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium,
                    ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('$postCount posts', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTripSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final Query query;

  const _UserTripSection({
    required this.title,
    required this.emptyText,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final trips = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                if (snapshot.hasData)
                  Text(
                    '${trips.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (trips.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(emptyText),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: trips.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _PublicTripCard(trip: trips[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PublicTripCard extends StatelessWidget {
  final QueryDocumentSnapshot trip;

  const _PublicTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final data = trip.data() as Map<String, dynamic>;
    final imageUrl = (data['imagePath'] ?? '').toString();
    final tripName = (data['tripName'] ?? '').toString().trim().isNotEmpty
        ? data['tripName'].toString()
        : 'Unnamed trip';
    final destination = (data['destination'] ?? 'Unknown destination')
        .toString();
    final startDate = (data['startDate'] ?? '').toString();
    final endDate = (data['endDate'] ?? '').toString();

    return SizedBox(
      width: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailScreen(tripId: trip.id),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : ColoredBox(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: const Center(
                          child: Icon(Icons.card_travel_outlined, size: 42),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tripName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (startDate.isNotEmpty || endDate.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$startDate - $endDate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPublicPostsCard extends StatelessWidget {
  const _EmptyPublicPostsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(padding: EdgeInsets.all(18), child: Text('No posts yet.')),
    );
  }
}
