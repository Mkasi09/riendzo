import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riendzo/views/feed/Post.dart';
import 'package:riendzo/views/profile/user_profile_screen.dart';
import 'package:riendzo/widgets/Shared%20Widgets/feed_app_bar.dart';
import 'package:riendzo/widgets/network_video_player.dart';
import '../../widgets/Shared Widgets/avatars_row.dart';
import '../../widgets/Shared Widgets/comments_popup.dart';
import 'like_button_widget.dart';
import 'post_detail_screen.dart';
import 'post_creation_screen.dart'; // Import the post creation screen
import 'package:timeago/timeago.dart' as timeago;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // To hold the currently authenticated user
  int commentCount = 0;
  int likeCount = 0;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
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
      extendBodyBehindAppBar: false, // Allow body to extend behind the AppBar
      appBar: FeedAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildFeedShell(
              const _FeedEmptyState(
                title: 'Feed is ready',
                message: 'Saved posts will appear here when available.',
              ),
            );
          }

          // Fetch posts data with like status
          return FutureBuilder<List<PostModel>>(
            future: _getPostsWithLikes(snapshot.data?.docs ?? []),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return _buildFeedShell(
                  const _FeedEmptyState(
                    title: 'Feed is ready',
                    message: 'Preparing saved posts.',
                  ),
                );
              }

              if (futureSnapshot.hasError) {
                return _buildFeedShell(
                  const _FeedEmptyState(
                    title: 'Offline mode',
                    message:
                        'Posts are unavailable right now. You can still create a post draft.',
                  ),
                );
              }

              final posts = futureSnapshot.data ?? [];

              if (posts.isEmpty) {
                return _buildFeedShell(
                  const _FeedEmptyState(
                    title: 'No posts yet',
                    message: 'Be the first to share something.',
                  ),
                );
              }

              return _buildFeedShell(
                Column(
                  children: posts.map((post) => _buildPostItem(post)).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFeedShell(Widget content) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        _buildPostInputSection(),
        const SizedBox(height: 14),
        const Stories(
          radius: 35,
          margin: .01,
          statusUpdate: Colors.blueAccent,
          horizontalPadding: 6,
        ),
        content,
      ],
    );
  }

  // Asynchronous function to get posts and check like status
  Future<List<PostModel>> _getPostsWithLikes(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return []; // No user logged in, return empty list

    try {
      return await Future.wait(
        docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;

          // Check if the current user has liked the post
          final likeDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(doc.id)
              .collection('likes')
              .doc(currentUser.uid)
              .get();

          final isLiked = likeDoc.exists && likeDoc.data() != null
              ? likeDoc.data()!['liked'] ?? false
              : false;

          return PostModel(
            postId: doc.id,
            content: data['content'] ?? '',
            mediaPaths: List<String>.from(data['mediaUrls'] ?? []),
            mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
            userId: data['userId'] ?? '',
            timestamp: data['timestamp'],
            isLiked: isLiked, // Include the like status
            likeCount: data['likeCount'] ?? 0, // Fetch and include like count
          );
        }).toList(),
      );
    } catch (e) {
      print('Error fetching posts with likes: $e');
      return [];
    }
  }

  Widget _buildPostInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Navigate to PostCreationScreen without media
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostCreationScreen(media: []),
                    ),
                  );
                },
                child: TextField(
                  enabled: false, // Disable direct text entry
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.edit_outlined),
                    hintText: "What's on your mind?",
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Add photo',
              icon: const Icon(Icons.photo_outlined),
              onPressed: () => _pickImage(), // Open gallery to select an image
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Add video',
              icon: const Icon(Icons.videocam_outlined),
              onPressed: _pickVideo,
            ),
          ],
        ),
      ),
    );
  }

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
                                          color: Colors.grey[200]!.withOpacity(
                                            0.8,
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
        // Optionally, also delete likes and comments if necessary
        // Handle post deletion confirmation
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Post deleted successfully.')));
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post. Please try again.')),
        );
      }
    }
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
