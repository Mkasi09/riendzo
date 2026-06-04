import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riendzo/views/inbox/inbox.dart';
import 'package:riendzo/views/notifications/notifications_screen.dart';
import 'package:riendzo/views/profile/profile.dart';

class FeedAppBar extends StatefulWidget implements PreferredSizeWidget {
  const FeedAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  State<FeedAppBar> createState() => _FeedAppBarState();
}

class _FeedAppBarState extends State<FeedAppBar> {
  String _profilePictureUrl = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserProfilePicture();
  }

  Future<void> _getUserProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .get();
      final profilePicture = snapshot.child('profilePicture').value as String?;
      if (mounted) {
        setState(() {
          _profilePictureUrl = profilePicture ?? '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 20,
      title: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Profile()),
              );
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: !_isLoading && _profilePictureUrl.isNotEmpty
                  ? CachedNetworkImageProvider(_profilePictureUrl)
                  : null,
              child: _profilePictureUrl.isEmpty
                  ? Icon(Icons.person, color: theme.colorScheme.primary)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Feed', style: theme.textTheme.titleLarge),
                Text(
                  'See what travellers are sharing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton.filledTonal(
          tooltip: 'Inbox',
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Inbox()),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
