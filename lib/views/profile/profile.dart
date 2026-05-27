import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riendzo/views/feed/Post.dart';
import 'package:riendzo/views/feed/like_button_widget.dart';
import 'package:riendzo/views/inbox/inbox.dart';
import 'package:riendzo/views/my_trips/my_trips.dart';
import 'package:riendzo/views/profile/ContactUsScreen.dart';
import 'package:riendzo/views/profile/widgets/profile_card.dart';
import 'package:riendzo/views/profile/widgets/profile_summary.dart';
import 'package:riendzo/widgets/network_video_player.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/Shared Widgets/comments_popup.dart';
import 'LegalInformationScreen.dart';
import 'SupportCenterScreen.dart';
import '../feed/post_detail_screen.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final TextEditingController _nameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  File? _selectedImage;
  String? _profilePictureUrl;

  User? get _currentUser => _auth.currentUser;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getUserData() async {
    final user = _currentUser;
    if (user == null) {
      return {'fullName': 'Guest', 'email': '', 'profilePicture': ''};
    }

    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(user.uid)
        .get();

    if (!snapshot.exists) {
      return {
        'fullName': user.displayName ?? 'Traveller',
        'email': user.email ?? '',
        'profilePicture': '',
      };
    }

    final fullName = snapshot.child('name').value as String? ?? 'Traveller';
    final email = snapshot.child('email').value as String? ?? user.email ?? '';
    final profilePicture =
        snapshot.child('profilePicture').value as String? ?? '';

    _nameController.text = fullName;
    _profilePictureUrl = profilePicture;

    return {
      'fullName': fullName,
      'email': email,
      'profilePicture': profilePicture,
    };
  }

  Future<Map<String, dynamic>> _getUserDataForPost(String userId) async {
    final event = await FirebaseDatabase.instance.ref('users/$userId').once();
    final snapshot = event.snapshot;

    if (snapshot.exists && snapshot.value is Map) {
      final userData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final profilePicture = (userData['profilePicture'] ?? '').toString();
      return {
        'profilePicture': profilePicture,
        'fullName': (userData['name'] ?? 'Unknown User').toString(),
        'isDefaultImage': profilePicture.isEmpty,
      };
    }

    return {
      'profilePicture': '',
      'fullName': 'Unknown User',
      'isDefaultImage': true,
    };
  }

  Future<void> _updateName() async {
    final user = _currentUser;
    final newName = _nameController.text.trim();
    if (user == null || newName.isEmpty) return;

    await FirebaseDatabase.instance.ref().child('users').child(user.uid).update(
      {'name': newName},
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name updated successfully')));
    setState(() {});
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    setState(() => _selectedImage = File(pickedFile.path));
    await _updateProfilePicture();
  }

  Future<String> _uploadImage(File image) async {
    final ref = FirebaseStorage.instance.ref().child(
      "profilePictures/${DateTime.now().millisecondsSinceEpoch}",
    );
    final uploadTask = ref.putFile(
      image,
      SettableMetadata(cacheControl: 'max-age=60', contentType: 'image/jpeg'),
    );
    final taskSnapshot = await uploadTask;
    return taskSnapshot.ref.getDownloadURL();
  }

  Future<void> _updateProfilePicture() async {
    final image = _selectedImage;
    final user = _currentUser;
    if (image == null || user == null) return;

    final downloadUrl = await _uploadImage(image);
    await FirebaseDatabase.instance.ref().child('users').child(user.uid).update(
      {'profilePicture': downloadUrl},
    );

    if (!mounted) return;
    setState(() => _profilePictureUrl = downloadUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated successfully')),
    );
  }

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Enter new name'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.pop(context);
              _updateName();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateName();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileOptions(String profilePictureUrl) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                enabled: profilePictureUrl.isNotEmpty,
                leading: const Icon(Icons.image_outlined),
                title: const Text('See Profile Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _showProfilePicture(profilePictureUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Update Profile Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfilePicture(String profilePictureUrl) {
    if (profilePictureUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: profilePictureUrl,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.person, size: 64),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, String>>(
          future: _getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Unable to load profile.'));
            }

            final userData = snapshot.data!;
            final profilePicture =
                _profilePictureUrl ?? userData['profilePicture'] ?? '';

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .where('userId', isEqualTo: _currentUser?.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, postsSnapshot) {
                if (postsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return FutureBuilder<List<PostModel>>(
                  future: _getPostsWithLikes(postsSnapshot.data?.docs ?? []),
                  builder: (context, futureSnapshot) {
                    final posts = futureSnapshot.data ?? [];

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                        _ProfileHeader(
                          fullName: userData['fullName'] ?? 'Traveller',
                          email: userData['email'] ?? '',
                          profilePicture: profilePicture,
                          onEditName: _showEditNameDialog,
                          onAvatarTap: () =>
                              _showProfileOptions(profilePicture),
                          onInboxTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Inbox(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        const ProfileSummary(),
                        const SizedBox(height: 14),
                        _ProfileActionSection(
                          title: 'General',
                          children: [
                            ProfileCard(
                              leadingIcon: const Icon(
                                Icons.notifications_none_rounded,
                              ),
                              textTitle: 'Notifications',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No new notifications'),
                                    ),
                                  ),
                            ),
                            ProfileCard(
                              leadingIcon: const Icon(Icons.map_outlined),
                              textTitle: 'My Trips',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MyTrips(),
                                  ),
                                );
                              },
                            ),
                            ProfileCard(
                              leadingIcon: const Icon(
                                Icons.account_balance_wallet,
                              ),
                              textTitle: 'Wallet',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () => _showComingSoon('Wallet'),
                            ),
                            ProfileCard(
                              leadingIcon: const Icon(Icons.people_outline),
                              textTitle: 'Travellers',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () => _showComingSoon('Travellers'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ProfileActionSection(
                          title: 'Support',
                          children: [
                            ProfileCard(
                              leadingIcon: const Icon(Icons.info_outline),
                              textTitle: 'Legal Information',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LegalInformationScreen(),
                                  ),
                                );
                              },
                            ),
                            ProfileCard(
                              leadingIcon: const Icon(Icons.help_outline),
                              textTitle: 'Help Center',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SupportCenterScreen(),
                                  ),
                                );
                              },
                            ),
                            ProfileCard(
                              leadingIcon: const Icon(
                                Icons.contact_support_outlined,
                              ),
                              textTitle: 'Contact Us',
                              trailingIcon: Icons.chevron_right_rounded,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ContactUsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ProfileCard(
                          leadingIcon: const Icon(Icons.logout_rounded),
                          textTitle: 'Logout',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: signOut,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Your Posts',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        if (futureSnapshot.connectionState ==
                            ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (posts.isEmpty)
                          const _EmptyPostsCard()
                        else
                          ...posts.map((post) => _buildPostItem(post)),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  Future<List<PostModel>> _getPostsWithLikes(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final currentUser = _currentUser;
    if (currentUser == null) return [];

    return Future.wait(
      docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final likeDoc = await _firestore
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
          isLiked: isLiked,
          likeCount: data['likeCount'] ?? 0,
        );
      }),
    );
  }

  Widget _buildPostItem(PostModel post) {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getUserDataForPost(post.userId),
                    builder: (context, snapshot) {
                      final userData = snapshot.data;
                      final profilePicture = (userData?['profilePicture'] ?? '')
                          .toString();

                      return CircleAvatar(
                        radius: 20,
                        backgroundImage: profilePicture.isNotEmpty
                            ? NetworkImage(profilePicture)
                            : null,
                        child: profilePicture.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getUserDataForPost(post.userId),
                          builder: (context, snapshot) {
                            final fullName =
                                snapshot.data?['fullName']?.toString() ??
                                'Unknown User';
                            return Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            );
                          },
                        ),
                        Text(
                          _formatTimestamp(post.timestamp),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (post.userId == _currentUser?.uid)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') _deletePost(post);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Post'),
                        ),
                      ],
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
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(width: 150, child: LikeButtonWidget(post: post)),
                  _CommentButton(
                    countFuture: _getTotalCommentCountWithReplies(post.postId),
                    onTap: () => _openCommentPopup(post),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCommentPopup(PostModel post) {
    showDialog(
      context: context,
      builder: (context) =>
          CommentsPopup(contentId: post.postId, contentType: 'post'),
    );
  }

  void _openPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
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

  Widget _buildMediaSection(List<String> mediaPaths, List<String> mediaTypes) {
    if (mediaPaths.length == 1) {
      final media = mediaPaths.first;
      if (_isVideoMedia(mediaPaths, mediaTypes, 0)) {
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: NetworkVideoPlayer(borderRadius: 0, url: media),
        );
      }

      return AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: media,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) =>
              const Icon(Icons.broken_image_outlined, size: 56),
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

  Future<void> _deletePost(PostModel post) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      await _firestore.collection('posts').doc(post.postId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete post. Please try again.'),
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown time";
    return timeago.format(timestamp.toDate());
  }
}

class _ProfileHeader extends StatelessWidget {
  final String fullName;
  final String email;
  final String profilePicture;
  final VoidCallback onEditName;
  final VoidCallback onAvatarTap;
  final VoidCallback onInboxTap;

  const _ProfileHeader({
    required this.fullName,
    required this.email,
    required this.profilePicture,
    required this.onEditName,
    required this.onAvatarTap,
    required this.onInboxTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
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
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onEditName,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit name'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onInboxTap,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Inbox'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileActionSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        ),
      ],
    );
  }
}

class _CommentButton extends StatelessWidget {
  final Future<int> countFuture;
  final VoidCallback onTap;

  const _CommentButton({required this.countFuture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return ActionChip(
          avatar: const Icon(Icons.comment_outlined, size: 18),
          label: Text(
            '$count comments',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: onTap,
        );
      },
    );
  }
}

class _EmptyPostsCard extends StatelessWidget {
  const _EmptyPostsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Icon(
              Icons.article_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your posts will appear here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
