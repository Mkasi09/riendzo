import 'package:cached_network_image/cached_network_image.dart';
import 'package:riendzo/services/app_image_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/services/follow_service.dart';
import 'package:riendzo/services/user_repository.dart';
import 'package:riendzo/views/feed/Post.dart';
import 'package:riendzo/views/feed/like_button_widget.dart';
import 'package:riendzo/views/feed/post_detail_screen.dart';
import 'package:riendzo/views/trips/trips.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final Future<_PublicProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_PublicProfile> _loadProfile() async {
    final data = await UserRepository.getProfile(widget.userId);
    if (data == null) return const _PublicProfile.unknown();
    final name = data['name']?.toString().trim() ?? '';
    return _PublicProfile(
      name: name.isEmpty ? 'Traveller' : name,
      email: data['email']?.toString() ?? '',
      photoUrl: data['profilePicture']?.toString() ?? '',
    );
  }

  Future<List<PostModel>> _loadPosts(List<QueryDocumentSnapshot> documents) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Future.wait(
      documents.map((document) async {
        final data = document.data() as Map<String, dynamic>;
        final like = currentUserId == null
            ? null
            : await document.reference
                  .collection('likes')
                  .doc(currentUserId)
                  .get();
        return PostModel(
          postId: document.id,
          content: data['content']?.toString() ?? '',
          mediaPaths: List<String>.from(data['mediaUrls'] ?? const []),
          mediaTypes: List<String>.from(data['mediaTypes'] ?? const []),
          userId: data['userId']?.toString() ?? '',
          timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
          isLiked: like?.data()?['liked'] == true,
          likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_PublicProfile>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            final profile =
                profileSnapshot.data ?? const _PublicProfile.unknown();
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .where('userId', isEqualTo: widget.userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, postSnapshot) {
                final documents = postSnapshot.data?.docs ?? const [];
                return FutureBuilder<List<PostModel>>(
                  future: _loadPosts(documents),
                  builder: (context, postsSnapshot) {
                    final posts = postsSnapshot.data ?? const <PostModel>[];
                    final loading =
                        postSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        postsSnapshot.connectionState ==
                            ConnectionState.waiting;
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _TopBar(title: profile.name)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: _ProfileHero(
                              profile: profile,
                              postCount: posts.length,
                              isOwnProfile:
                                  FirebaseAuth.instance.currentUser?.uid ==
                                  widget.userId,
                              userId: widget.userId,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                            child: _TripsSection(userId: widget.userId),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                            child: Row(
                              children: [
                                Text(
                                  'Posts',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const Spacer(),
                                if (!loading) Text('${posts.length}'),
                              ],
                            ),
                          ),
                        ),
                        if (loading)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        else if (posts.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: _EmptyState(
                                icon: Icons.photo_library_outlined,
                                text: 'No posts shared yet.',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            sliver: SliverList.separated(
                              itemCount: posts.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) => _PostCard(
                                post: posts[index],
                                profile: profile,
                              ),
                            ),
                          ),
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
}

class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final _PublicProfile profile;
  final int postCount;
  final bool isOwnProfile;
  final String userId;

  const _ProfileHero({
    required this.profile,
    required this.postCount,
    required this.isOwnProfile,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white,
                backgroundImage: profile.photoUrl.isEmpty
                    ? null
                    : CachedNetworkImageProvider(profile.photoUrl),
                child: profile.photoUrl.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 38,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (profile.email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOwnProfile
                        ? 'This is your public profile.'
                        : 'Travel stories and trips shared by this traveller.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$postCount posts', style: theme.textTheme.labelLarge),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FollowSummary(userId: userId, postCount: postCount),
          if (!isOwnProfile) ...[
            const SizedBox(height: 12),
            _FollowButton(targetUserId: userId, targetName: profile.name),
          ],
        ],
      ),
    );
  }
}

class _FollowSummary extends StatelessWidget {
  final String userId;
  final int postCount;

  const _FollowSummary({required this.userId, required this.postCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialMetric(label: 'Posts', value: postCount, onTap: null),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FollowService.followersStream(userId),
            builder: (context, snapshot) => _SocialMetric(
              label: 'Followers',
              value: FollowService.count(snapshot.data),
              onTap: () => _openList(context, 'Followers', true),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FollowService.followingStream(userId),
            builder: (context, snapshot) => _SocialMetric(
              label: 'Following',
              value: FollowService.count(snapshot.data),
              onTap: () => _openList(context, 'Following', false),
            ),
          ),
        ),
      ],
    );
  }

  void _openList(BuildContext context, String title, bool followers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FollowListScreen(
          userId: userId,
          title: title,
          showFollowers: followers,
        ),
      ),
    );
  }
}

class _SocialMetric extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _SocialMetric({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String targetUserId;
  final String targetName;

  const _FollowButton({required this.targetUserId, required this.targetName});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FollowService.relationshipStream(
        followerId: currentUser.uid,
        targetUserId: targetUserId,
      ),
      builder: (context, snapshot) {
        final following = FollowService.isFollowing(snapshot.data);
        return SizedBox(
          width: double.infinity,
          child: following
              ? OutlinedButton.icon(
                  onPressed: () => _setFollowing(context, currentUser, false),
                  icon: const Icon(Icons.person_remove_alt_1_outlined),
                  label: const Text('Following'),
                )
              : FilledButton.icon(
                  onPressed: () => _setFollowing(context, currentUser, true),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Follow'),
                ),
        );
      },
    );
  }

  Future<void> _setFollowing(
    BuildContext context,
    User currentUser,
    bool shouldFollow,
  ) async {
    try {
      await FollowService.setFollowing(
        followerId: currentUser.uid,
        targetUserId: targetUserId,
        shouldFollow: shouldFollow,
        followerName: currentUser.displayName ?? currentUser.email ?? 'Someone',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldFollow
                ? 'Could not follow $targetName.'
                : 'Could not unfollow $targetName.',
          ),
        ),
      );
    }
  }
}

class _FollowListScreen extends StatelessWidget {
  final String userId;
  final String title;
  final bool showFollowers;

  const _FollowListScreen({
    required this.userId,
    required this.title,
    required this.showFollowers,
  });

  @override
  Widget build(BuildContext context) {
    final stream = showFollowers
        ? FollowService.followersStream(userId)
        : FollowService.followingStream(userId);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = _userIds(snapshot.data);
          if (ids.isEmpty) {
            return Center(child: Text('No $title yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: ids.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => _FollowUserRow(userId: ids[index]),
          );
        },
      ),
    );
  }

  List<String> _userIds(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    final ids =
        snapshot?.docs.map((document) => document.id).toList() ?? <String>[];
    ids.sort();
    return ids;
  }
}

class _FollowUserRow extends StatelessWidget {
  final String userId;

  const _FollowUserRow({required this.userId});

  Future<_PublicProfile> _loadProfile() async {
    final data = await UserRepository.getProfile(userId);
    final name = data?['name']?.toString().trim() ?? '';
    return _PublicProfile(
      name: name.isEmpty ? 'Traveller' : name,
      email: data?['email']?.toString() ?? '',
      photoUrl: data?['profilePicture']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PublicProfile>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const _PublicProfile.unknown();
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: userId),
            ),
          ),
          leading: CircleAvatar(
            backgroundImage: profile.photoUrl.isEmpty
                ? null
                : CachedNetworkImageProvider(profile.photoUrl),
            child: profile.photoUrl.isEmpty
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          title: Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: profile.email.isEmpty
              ? null
              : Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

class _TripsSection extends StatelessWidget {
  final String userId;

  const _TripsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'ongoing')
          .snapshots(),
      builder: (context, snapshot) {
        final trips = snapshot.data?.docs ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Active trips',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                if (snapshot.hasData) Text('${trips.length}'),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (trips.isEmpty)
              const _EmptyState(
                icon: Icons.route_outlined,
                text: 'No active trips are shared yet.',
              )
            else
              SizedBox(
                height: 318,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: trips.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) => SizedBox(
                    width: (MediaQuery.sizeOf(context).width * 0.82).clamp(
                      300.0,
                      380.0,
                    ),
                    child: DiscoverTripCard(trip: trips[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final _PublicProfile profile;

  const _PostCard({required this.post, required this.profile});

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundImage: profile.photoUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(profile.photoUrl),
                      child: profile.photoUrl.isEmpty
                          ? const Icon(Icons.person_outline_rounded)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      timeago.format(post.timestamp.toDate()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (post.content.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(post.content, style: theme.textTheme.bodyLarge),
                ),
              if (post.mediaPaths.isNotEmpty) _PostMedia(post: post),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: LikeButtonWidget(post: post)),
                    IconButton(
                      tooltip: 'Open post',
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
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

class _PostMedia extends StatelessWidget {
  final PostModel post;

  const _PostMedia({required this.post});

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.m4v') ||
        lower.contains('video%2f');
  }

  @override
  Widget build(BuildContext context) {
    final images = post.mediaPaths.where((url) => !_isVideo(url)).toList();
    if (images.isEmpty) {
      return const SizedBox(
        height: 116,
        child: Center(child: Icon(Icons.play_circle_outline_rounded, size: 44)),
      );
    }
    if (images.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: _PostImage(url: images.first),
      );
    }
    return SizedBox(
      height: 230,
      child: Row(
        children: [
          Expanded(flex: 3, child: _PostImage(url: images.first)),
          const SizedBox(width: 2),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: _PostImage(url: images[1])),
                if (images.length > 2) ...[
                  const SizedBox(height: 2),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _PostImage(url: images[2]),
                        if (images.length > 3)
                          ColoredBox(
                            color: const Color(0x88000000),
                            child: Center(
                              child: Text(
                                '+${images.length - 3}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String url;

  const _PostImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppImageCache.instance,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PublicProfile {
  final String name;
  final String email;
  final String photoUrl;

  const _PublicProfile({
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  const _PublicProfile.unknown()
    : name = 'Traveller',
      email = '',
      photoUrl = '';
}
