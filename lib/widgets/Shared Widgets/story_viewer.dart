import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/app_image_cache.dart';

import '../../views/inbox/chat_screen.dart';

class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  final List<Map<String, String>> stories;
  final int initialIndex;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  late int _index;
  Timer? _advanceTimer;
  DateTime? _timerStartedAt;
  Duration _timeLeft = const Duration(seconds: 5);
  bool _isHolding = false;

  Map<String, String> get _story => widget.stories[_index];
  String get _content => _story['content'] ?? '';
  String get _type => _story['type'] ?? 'image';
  String get _caption => _story['caption'] ?? '';
  String get _userName => _story['userName'] ?? 'Unknown';
  String get _userId => _story['userId'] ?? '';
  String get _storyKey => _story['key'] ?? '';
  String get _profilePicture => _story['profilePicture'] ?? '';

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();
    _startAdvanceTimer();
  }

  void _showStory(int index) {
    if (index < 0 || index >= widget.stories.length) return;
    _advanceTimer?.cancel();
    _progress.stop();
    setState(() => _index = index);
    _timeLeft = const Duration(seconds: 5);
    _progress
      ..reset()
      ..forward();
    _startAdvanceTimer();
  }

  void _startAdvanceTimer() {
    if (_isHolding) return;
    _advanceTimer?.cancel();
    _timerStartedAt = DateTime.now();
    _advanceTimer = Timer(_timeLeft, () {
      if (!mounted || _isHolding) return;
      if (_index + 1 < widget.stories.length) {
        _showStory(_index + 1);
      } else {
        // Keep the last story visible until the user closes it or swipes back.
        _progress
          ..stop()
          ..value = 1;
      }
    });
  }

  void _pauseStory() {
    if (_isHolding) return;
    _isHolding = true;
    _advanceTimer?.cancel();
    final startedAt = _timerStartedAt;
    if (startedAt != null) {
      _timeLeft -= DateTime.now().difference(startedAt);
      if (_timeLeft.isNegative) _timeLeft = Duration.zero;
    }
    _progress.stop();
  }

  void _resumeStory() {
    if (!_isHolding) return;
    _isHolding = false;
    _progress.forward();
    _startAdvanceTimer();
  }

  String _formattedTime(String raw) {
    final millis = int.tryParse(raw);
    if (millis == null) return 'Recently';
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    final age = DateTime.now().difference(time);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes} minutes ago';
    if (age.inHours < 24 && time.day == DateTime.now().day) {
      return 'Today, ${DateFormat('HH:mm').format(time)}';
    }
    return DateFormat('MMM d, HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(_content);
    final remote =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    final local = uri?.scheme == 'file' && uri?.path.isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -150) _showStory(_index + 1);
          if (velocity > 150) _showStory(_index - 1);
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 250) {
            _advanceTimer?.cancel();
            Navigator.of(context).maybePop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(.08, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_storyKey),
                  child: _buildStoryMedia(uri, remote, local),
                ),
              ),
            ),
            if (_caption.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 42,
                child: Text(
                  _caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => LinearProgressIndicator(
                        value: _progress.value,
                        backgroundColor: Colors.white38,
                        color: Colors.white,
                        minHeight: 3,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 8, 0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: Colors.white24,
                          backgroundImage: _validRemote(_profilePicture)
                              ? CachedNetworkImageProvider(
                                  _profilePicture,
                                  cacheManager: AppImageCache.instance,
                                )
                              : null,
                          child: _validRemote(_profilePicture)
                              ? null
                              : const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _formattedTime(_story['timestamp'] ?? ''),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          iconColor: Colors.white,
                          onSelected: (value) {
                            if (value == 'delete') _deleteStory();
                            if (value == 'message') _messageUser();
                          },
                          itemBuilder: (_) => _userName == 'My Story'
                              ? const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete story'),
                                  ),
                                ]
                              : const [
                                  PopupMenuItem(
                                    value: 'message',
                                    child: Text('Message user'),
                                  ),
                                ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.stories.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Text(
                  '${_index + 1} of ${widget.stories.length} · swipe to switch',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryMedia(Uri? uri, bool remote, bool local) {
    if (_type == 'text') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _content,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      );
    }
    if (local && uri != null) {
      return Image.file(
        File.fromUri(uri),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _StoryUnavailable(),
      );
    }
    if (remote) {
      return CachedNetworkImage(
        imageUrl: _content,
        cacheManager: AppImageCache.instance,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (_, __, ___) => const _StoryUnavailable(),
      );
    }
    return const _StoryUnavailable();
  }

  Future<void> _deleteStory() async {
    try {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(_storyKey)
          .delete();
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this story.')),
        );
    }
  }

  Future<void> _messageUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _userId.isEmpty) return;
    final snapshot = await FirebaseDatabase.instance
        .ref('users/${currentUser.uid}/name')
        .get();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userName: _userName,
          recipientId: _userId,
          userProfilePicture: _profilePicture,
          senderName: snapshot.value?.toString() ?? 'Unknown',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }
}

bool _validRemote(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

class _StoryUnavailable extends StatelessWidget {
  const _StoryUnavailable();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white70, size: 54),
        SizedBox(height: 10),
        Text(
          'This story photo is unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}
