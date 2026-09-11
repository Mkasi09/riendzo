import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riendzo/views/feed/Post.dart';
import 'package:riendzo/views/feed/widgets/post_media_carousel.dart';
import 'package:riendzo/views/inbox/inbox.dart';
import 'package:riendzo/views/my_trips/trip_details.dart';
import 'package:riendzo/views/notifications/notifications_screen.dart';
import 'package:riendzo/views/profile/profile.dart';
import 'package:riendzo/views/profile/user_profile_screen.dart';
import 'package:riendzo/widgets/riendzo_sliver_app_bar.dart';
import 'package:riendzo/widgets/network_video_player.dart';
import '../../widgets/Shared Widgets/avatars_row.dart';
import '../../widgets/Shared Widgets/comments_popup.dart';
import 'like_button_widget.dart';
import 'post_detail_screen.dart';
import 'post_creation_screen.dart'; // Import the post creation screen
import 'package:timeago/timeago.dart' as timeago;

enum _FeedFilter { forYou, following, nearby, saved }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // To hold the currently authenticated user
  int commentCount = 0;
  int likeCount = 0;
  bool isLiked = false;
  int _postLimit = 20;
  _FeedFilter _selectedFilter = _FeedFilter.forYou;
  final Set<String> _savedPostIds = {};
  final Set<String> _followingUserIds = {};
  final Map<String, Future<Map<String, dynamic>>> _userDataCache = {};
  String _currentCity = '';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadFeedPreferences();
  }

  Future<void> _loadFeedPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('savedPosts')
            .get(),
        FirebaseDatabase.instance.ref('users/${user.uid}').get(),
      ]);
      final saved = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final profile = results[1] as DataSnapshot;
      final raw = profile.value;
      final userData = raw is Map ? raw : const {};
      final following = userData['following'];
      final followingIds = <String>{};
      if (following is Map) {
        following.forEach((key, value) {
          if (value != false) followingIds.add(key.toString());
        });
      } else if (following is List) {
        followingIds.addAll(
          following.whereType<String>().where((id) => id.isNotEmpty),
        );
      }
      if (!mounted) return;
      setState(() {
        _savedPostIds
          ..clear()
          ..addAll(saved.docs.map((doc) => doc.id));
        _followingUserIds
          ..clear()
          ..addAll(followingIds);
        _currentCity = (userData['city'] ?? userData['location'] ?? '')
            .toString()
            .trim();
      });
    } catch (_) {
      // The feed remains usable when optional preferences are unavailable.
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown time";
    return timeago.format(timestamp.toDate());
  }

  // Fetch user profile picture and name by user ID from Realtime Database
  // Fetch user profile picture and name by user ID from Realtime Database
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    DatabaseReference userRef = FirebaseDatabase.instance.ref('users/$userId');

    DatabaseEvent event = await userRef.once();
    DataSnapshot snapshot = event.snapshot;

    if (snapshot.exists) {
      final userData = snapshot.value as Map<dynamic, dynamic>;
      final profilePicture = userData['profilePicture'];
      final fullName = userData['name'] ?? 'Unknown User';

      return {
        'profilePicture':
            profilePicture ?? '', // If null, fallback to empty string
        'fullName': fullName,
        'isDefaultImage':
            profilePicture == null ||
            profilePicture.isEmpty, // Check if profile picture is missing
      };
    }

    return {
      'profilePicture': '', // No profile picture
      'fullName': 'Unknown User',
      'isDefaultImage': true, // Use default image
    };
  }

  void _openCommentPopup(PostModel post) {
    // Implement your existing comment popup logic here
    showDialog(
      context: context,
      builder: (context) => CommentsPopup(
        contentId: post.postId, // Pass the post ID as contentId
        contentType: 'post', // Specify that the content is a post
      ),
    );
  }

  void _openPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  void _openUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  Future<int> _getTotalCommentCountWithReplies(String postId) async {
    int totalCommentCount = 0;

    final commentsSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .get();

    // Loop through all comments and add the replies count
    for (var commentDoc in commentsSnapshot.docs) {
      totalCommentCount += 1; // Count the comment itself

      // Fetch the number of replies for each comment
      final repliesSnapshot = await commentDoc.reference
          .collection('replies')
          .get();
      totalCommentCount += repliesSnapshot.size; // Add the number of replies
    }

    return totalCommentCount;
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (pickedFile != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostCreationScreen(media: [pickedFile]),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostCreationScreen(media: [pickedFile]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          RiendzoSliverAppBar(
            title: 'Travel feed',
            subtitle: 'Stories, tips, and moments from the community',
            actions: [
              IconButton(
                tooltip: 'Profile',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Profile()),
                ),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              IconButton(
                tooltip: 'Inbox',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Inbox()),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const SizedBox(width: 6),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FeedFilterHeaderDelegate(
              child: _FeedFilterBar(
                selected: _selectedFilter,
                onChanged: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
            ),
          ),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .limit(_postLimit)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildFeedShell(const _FeedSkeletonList());
            }
            if (snapshot.hasError) {
              return _buildFeedShell(
                const _FeedEmptyState(
                  title: 'Feed unavailable',
                  message:
                      'Check your connection. You can still prepare a new post.',
                ),
              );
            }

            final posts = _postsFromDocs(snapshot.data?.docs ?? []);
            final filteredPosts = _filterPosts(posts);
            if (filteredPosts.isEmpty) {
              return _buildFeedShell(_emptyStateForFilter());
            }

            return _buildFeedShell(
              Column(
                children: [
                  for (final post in filteredPosts) _buildTravelPostItem(post),
                  if ((snapshot.data?.docs.length ?? 0) >= _postLimit)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _postLimit += 20),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more stories'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedShell(Widget content) {
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildPostInputSection(),
          const SizedBox(height: 16),
          Text('Travel stories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const Stories(
            radius: 35,
            margin: .01,
            statusUpdate: Colors.blueAccent,
            horizontalPadding: 6,
          ),
          content,
        ],
      ),
    );
  }

  Future<void> _refreshFeed() async {
    _userDataCache.clear();
    await _loadFeedPreferences();
    if (mounted) setState(() {});
  }

  List<PostModel> _postsFromDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return PostModel(
        postId: doc.id,
        content: data['content']?.toString() ?? '',
        mediaPaths: List<String>.from(data['mediaUrls'] ?? const []),
        mediaTypes: List<String>.from(data['mediaTypes'] ?? const []),
        userId: data['userId']?.toString() ?? '',
        timestamp: data['timestamp'] is Timestamp
            ? data['timestamp'] as Timestamp
            : Timestamp.now(),
        location: data['location']?.toString() ?? '',
        tripId: data['tripId']?.toString(),
        commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    return switch (_selectedFilter) {
      _FeedFilter.forYou => posts,
      _FeedFilter.following =>
        posts.where((post) => _followingUserIds.contains(post.userId)).toList(),
      _FeedFilter.nearby => posts.where((post) {
        if (_currentCity.isEmpty || post.location.isEmpty) return false;
        return post.location.toLowerCase().contains(_currentCity.toLowerCase());
      }).toList(),
      _FeedFilter.saved =>
        posts.where((post) => _savedPostIds.contains(post.postId)).toList(),
    };
  }

  Widget _emptyStateForFilter() {
    return switch (_selectedFilter) {
      _FeedFilter.forYou => const _FeedEmptyState(
        title: 'No stories yet',
        message: 'Be the first traveller to share a moment.',
      ),
      _FeedFilter.following => const _FeedEmptyState(
        title: 'Your following feed is quiet',
        message: 'Follow more travellers to see their stories here.',
      ),
      _FeedFilter.nearby => _FeedEmptyState(
        title: 'No nearby stories yet',
        message: _currentCity.isEmpty
            ? 'Add your city to your profile to discover local stories.'
            : 'No recent stories were tagged near $_currentCity.',
      ),
      _FeedFilter.saved => const _FeedEmptyState(
        title: 'Nothing saved yet',
        message: 'Tap the bookmark on a story to keep it here.',
      ),
    };
  }

  Widget _buildPostInputSection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share your journey',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              'Post a moment, practical tip, or update from your trip.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _openComposer(),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 14),
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 10),
                    Text(
                      'What did you discover?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ComposerAction(
                  icon: Icons.photo_outlined,
                  label: 'Photo',
                  onTap: _pickImage,
                ),
                _ComposerAction(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  onTap: _pickVideo,
                ),
                _ComposerAction(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Travel tip',
                  onTap: () => _openComposer(initialText: 'Travel tip: '),
                ),
                _ComposerAction(
                  icon: Icons.card_travel_outlined,
                  label: 'Trip update',
                  onTap: () => _openComposer(initialText: 'Trip update: '),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openComposer({String initialText = ''}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostCreationScreen(media: const [], initialText: initialText),
      ),
    );
  }

  Widget _buildTravelPostItem(PostModel post) {
    final theme = Theme.of(context);
    final isSaved = _savedPostIds.contains(post.postId);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _userDataCache.putIfAbsent(
                      post.userId,
                      () => _getUserData(post.userId),
                    ),
                    builder: (context, snapshot) {
                      final userData = snapshot.data;
                      final fullName =
                          userData?['fullName']?.toString() ?? 'Traveller';
                      final profilePicture =
                          userData?['profilePicture']?.toString() ?? '';
                      return InkWell(
                        onTap: () => _openUserProfile(post.userId),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 21,
                              backgroundImage: profilePicture.isEmpty
                                  ? const AssetImage(
                                          'lib/assets/images/profile/p2.png',
                                        )
                                        as ImageProvider
                                  : NetworkImage(profilePicture),
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
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    [
                                      _formatTimestamp(post.timestamp),
                                      if (post.location.isNotEmpty)
                                        post.location,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _deletePost(post);
                    if (value == 'report') _reportPost(post);
                  },
                  itemBuilder: (_) => [
                    if (post.userId == _currentUser?.uid)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete post'),
                      )
                    else
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report post'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: InkWell(
                onTap: () => _openPostDetail(post),
                child: Text(post.content, style: theme.textTheme.bodyLarge),
              ),
            ),
          if (post.tripId != null && post.tripId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ListTile(
                tileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.card_travel_outlined),
                title: const Text('Linked Riendzo trip'),
                subtitle: const Text('View dates, route and group details'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripDetailScreen(tripId: post.tripId!),
                  ),
                ),
              ),
            ),
          if (post.mediaPaths.isNotEmpty)
            PostMediaCarousel(
              mediaPaths: post.mediaPaths,
              mediaTypes: post.mediaTypes,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                Expanded(child: LikeButtonWidget(post: post)),
                const SizedBox(width: 8),
                _PostActionButton(
                  tooltip: 'Comments',
                  icon: Icons.mode_comment_outlined,
                  count: post.commentCount,
                  onPressed: () => _openCommentPopup(post),
                ),
                _PostActionButton(
                  tooltip: isSaved ? 'Remove saved post' : 'Save post',
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  selected: isSaved,
                  onPressed: () => _toggleSavedPost(post),
                ),
                _PostActionButton(
                  tooltip: 'Share post',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => _sharePost(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSavedPost(PostModel post) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final wasSaved = _savedPostIds.contains(post.postId);
    setState(() {
      wasSaved
          ? _savedPostIds.remove(post.postId)
          : _savedPostIds.add(post.postId);
    });
    final reference = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPosts')
        .doc(post.postId);
    try {
      if (wasSaved) {
        await reference.delete();
      } else {
        await reference.set({
          'postId': post.postId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wasSaved
            ? _savedPostIds.add(post.postId)
            : _savedPostIds.remove(post.postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the saved post.')),
      );
    }
  }

  Future<void> _sharePost(PostModel post) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://riendzo.app/posts/${post.postId}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post link copied.')));
  }

  Future<void> _reportPost(PostModel post) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('postReports').add({
        'postId': post.postId,
        'reportedBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks. The post was reported for review.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not report this post.')),
      );
    }
  }

  // Kept for compatibility with older post layouts referenced by tests.
  // ignore: unused_element
  Widget _buildPostItem(PostModel post) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(top: 14),
      child: InkWell(
        onTap: () => _openPostDetail(post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getUserData(post.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Text("Unknown user");
                          }

                          final userData = snapshot.data!;
                          final fullName = userData['fullName']!;
                          final profilePicture = userData['profilePicture']!;
                          final isDefaultImage =
                              userData['isDefaultImage'] as bool;

                          return InkWell(
                            onTap: () => _openUserProfile(post.userId),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: isDefaultImage
                                        ? AssetImage(
                                                'lib/assets/images/profile/p2.png',
                                              )
                                              as ImageProvider
                                        : NetworkImage(profilePicture),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullName,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      Text(
                                        _formatTimestamp(post.timestamp),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      if (post.userId == _currentUser?.uid)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deletePost(post);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Post'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.content,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),

            // Media (image/video) is placed outside of the Padding widget
            if (post.mediaPaths.isNotEmpty)
              Stack(
                children: [
                  _buildMediaSection(
                    post.mediaPaths,
                    post.mediaTypes,
                  ), // Display the media
                  // Like and comment buttons positioned at the bottom
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Like Button
                            Flexible(child: LikeButtonWidget(post: post)),
                            SizedBox(width: 25),

                            // Comment Button
                            Flexible(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openCommentPopup(post),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200]!.withValues(
                                            alpha: 0.8,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 7,
                                        ),
                                        child: FutureBuilder<int>(
                                          future:
                                              _getTotalCommentCountWithReplies(
                                                post.postId,
                                              ),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.comment,
                                                      color: Colors.blue,
                                                    ),
                                                    Text(
                                                      ' 0 comments',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                            final commentAndReplyCount =
                                                snapshot.data!;
                                            return Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.comment,
                                                    color: Colors.blue,
                                                  ),
                                                  Text(
                                                    ' $commentAndReplyCount comments',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (post.mediaPaths.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    Expanded(child: LikeButtonWidget(post: post)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openCommentPopup(post),
                        icon: const Icon(Icons.mode_comment_outlined),
                        label: const Text('Comments'),
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
    final screenWidth = MediaQuery.of(context).size.width;

    // If there's only one media (either image or video)
    if (mediaPaths.length == 1) {
      final media = mediaPaths[0];

      // If it's a video, display a placeholder or video player
      if (_isVideoMedia(mediaPaths, mediaTypes, 0)) {
        return SizedBox(
          width: screenWidth,
          height: 300,
          child: NetworkVideoPlayer(url: media),
        );
      }

      // If it's an image, display it
      return Container(
        width: screenWidth,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          image: DecorationImage(
            image: NetworkImage(mediaPaths[0]),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // If there are multiple images/videos, use a grid layout
      return GridView.builder(
        shrinkWrap: true,
        physics:
            NeverScrollableScrollPhysics(), // Prevents GridView from scrolling
        itemCount: mediaPaths.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Display two items per row
          childAspectRatio: 1, // Ensure each item is square
          crossAxisSpacing: 10, // Spacing between grid items
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final media = mediaPaths[index];

          if (_isVideoMedia(mediaPaths, mediaTypes, index)) {
            return NetworkVideoPlayer(url: media);
          }

          // If it's an image, display it
          return Image.network(
            media, // The URL of the image
            fit: BoxFit.cover,
            width: screenWidth / 2, // Half the screen width for grid items
            height: screenWidth / 2, // Ensure it is square
          );
        },
      );
    }
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

  void _deletePost(PostModel post) async {
    // Show confirmation dialog before deletion
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    // If the user confirmed deletion
    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.postId)
            .delete();
        if (!mounted) return;
        // Optionally, also delete likes and comments if necessary
        // Handle post deletion confirmation
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Post deleted successfully.')));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post. Please try again.')),
        );
      }
    }
  }
}

class _FeedFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _FeedFilterHeaderDelegate({required this.child});

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: overlapsContent ? 3 : 0,
      shadowColor: Colors.black26,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FeedFilterHeaderDelegate oldDelegate) => true;
}

class _FeedFilterBar extends StatelessWidget {
  final _FeedFilter selected;
  final ValueChanged<_FeedFilter> onChanged;

  const _FeedFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      scrollDirection: Axis.horizontal,
      children: [
        _chip('For you', Icons.auto_awesome_outlined, _FeedFilter.forYou),
        _chip('Following', Icons.people_outline_rounded, _FeedFilter.following),
        _chip('Nearby', Icons.near_me_outlined, _FeedFilter.nearby),
        _chip('Saved', Icons.bookmark_border_rounded, _FeedFilter.saved),
      ],
    );
  }

  Widget _chip(String label, IconData icon, _FeedFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 17),
        label: Text(label),
        selected: selected == filter,
        onSelected: (_) => onChanged(filter),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _PostActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  const _PostActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.count = 0,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: selected ? Theme.of(context).colorScheme.primary : null,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(icon),
      ),
    );
  }
}

class _FeedSkeletonList extends StatelessWidget {
  const _FeedSkeletonList();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          margin: const EdgeInsets.only(top: 14),
          height: 330,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _FeedEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.feed_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
