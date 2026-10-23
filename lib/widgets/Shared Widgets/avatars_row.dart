import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // For Realtime Database
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:riendzo/widgets/Shared%20Widgets/story_viewer.dart';
import 'user_avatar.dart'; // Your custom UserAvatar widget
import 'story_add_button.dart';

class Stories extends StatefulWidget {
  final int radius;
  final int horizontalPadding;
  final double margin;
  final Color statusUpdate;

  const Stories({
    super.key,
    required this.radius,
    required this.horizontalPadding,
    required this.statusUpdate,
    required this.margin,
  });

  @override
  _StoriesState createState() => _StoriesState();
}

class _StoriesState extends State<Stories> {
  List<Map<String, String>> stories = []; // List to store story metadata
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'stories',
  );
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  @override
  void initState() {
    super.initState();
    _listenForStories(); // Start listening for real-time story updates
    _scheduleStoryCleanup(); // Schedule cleanup for expired stories
  }

  // Schedule a periodic cleanup task
  void _scheduleStoryCleanup() {
    Timer.periodic(Duration(hours: 1), (timer) {
      _dbRef.once().then((snapshot) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        for (var child in snapshot.snapshot.children) {
          final data = child.value as Map<dynamic, dynamic>?;
          final storyTimestamp = data?['timestamp'] ?? 0;

          if (currentTime - storyTimestamp > 86400000) {
            _dbRef.child(child.key!).remove(); // Delete expired story
          }
        }
      });
    });
  }

  void _listenForStories() {
    final user = FirebaseAuth.instance.currentUser;

    // Listening for Firestore story changes
    FirebaseFirestore.instance.collection('stories').snapshots().listen((
      snapshot,
    ) {
      final int currentTime = DateTime.now().millisecondsSinceEpoch;

      for (var docChange in snapshot.docChanges) {
        final doc = docChange.doc;
        final data = doc.data();
        final String key = doc.id;

        if (data != null) {
          final storyTimestamp = _storyTimestamp(data['timestamp']);

          if (storyTimestamp > 0 && currentTime - storyTimestamp > 86400000) {
            // If the story is older than 24 hours, delete it from Firestore
            FirebaseFirestore.instance.collection('stories').doc(key).delete();
          } else {
            switch (docChange.type) {
              case DocumentChangeType.added:
                _processStoryData(key, data, user);
                break;
              case DocumentChangeType.modified:
                _updateStoryData(key, data, user);
                break;
              case DocumentChangeType.removed:
                _removeStoryData(key);
                break;
            }
          }
        }
      }
    });
    _dbRef.onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final key = event.snapshot.key;
      _processStoryData(key!, data, user);
    });

    _dbRef.onChildChanged.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final key = event.snapshot.key;
      _updateStoryData(key!, data, user);
    });

    _dbRef.onChildRemoved.listen((event) {
      final key = event.snapshot.key;
      _removeStoryData(key!);
    });
  }

  int _storyTimestamp(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _updateStoryData(String key, Map<dynamic, dynamic> value, User? user) {
    setState(() {
      final index = stories.indexWhere((story) => story['key'] == key);
      if (index != -1) {
        stories[index] = {
          'key': key,
          'type': value['type'],
          'content': value['content'],
          'userName':
              value['userName'], // Presuming you set userName in the value
          'timestamp': value['timestamp']?.toString() ?? '',
          'profilePicture': value['profilePicture'] ?? '',
          'caption': value['caption'] ?? '',
        };
      }
    });
  }

  // Remove story data
  void _removeStoryData(String key) {
    setState(() {
      stories.removeWhere((story) => story['key'] == key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        itemCount: stories.length + 1, // Add +1 for the "Add Story" button
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: StoryAddButton(size: widget.radius * 2.0),
            );
          }

          final story = stories[index - 1]; // Adjust index for story content
          return GestureDetector(
            onTap: () => _openStoryViewer(context, story),
            child: SizedBox(
              width: widget.radius * 2.0 + 16,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: widget.statusUpdate,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: story['type'] == 'text'
                        ? CircleAvatar(
                            radius: widget.radius.toDouble(),
                            child: Text(
                              story['content'] ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          )
                        : UserAvatar(
                            size: widget.radius.toDouble(),
                            picture: story['content'] ?? '',
                          ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    story['userName'] == 'My Story'
                        ? 'My Story'
                        : (story['userName'] ?? 'Story'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processStoryData(
    String key,
    Map<dynamic, dynamic> value,
    User? user,
  ) async {
    final userId = value['userId'];
    String userName = 'Unknown'; // Default username if not found
    final String timestamp = _storyTimestamp(value['timestamp']).toString();
    String profilePictureUrl = ''; // Initialize profile picture URL

    if (userId != null) {
      // Check if the story belongs to the current user
      if (userId == user?.uid) {
        userName =
            "My Story"; // If it's the current user's story, show "My Story"
      } else {
        // Fetch the username and profile picture from the users database
        final userSnapshot = await _usersRef.child(userId).once();
        if (userSnapshot.snapshot.value != null) {
          final userData = Map<String, dynamic>.from(
            userSnapshot.snapshot.value as Map,
          );
          userName = userData['name'] ?? 'Unknown';
          profilePictureUrl =
              userData['profilePicture'] ?? ''; // Get profile picture URL
        }
      }
    }

    setState(() {
      final Map<String, String> story = {
        'key': key, // Add the key for easy reference
        'userId': userId?.toString() ?? '',
        'type': value['type']?.toString() ?? 'image',
        'content': value['content']?.toString() ?? '',
        'userName': userName, // Set "My Story" or the fetched username
        'timestamp': timestamp, // Add the timestamp
        'profilePicture': profilePictureUrl, // Add profile picture URL
        'caption':
            value['caption']?.toString() ?? '', // Add caption if available
      };
      final index = stories.indexWhere((item) => item['key'] == key);
      if (index < 0) {
        stories.add(story);
      } else {
        stories[index] = story;
      }
    });
  }

  // Open the story viewer for both text and image
  void _openStoryViewer(BuildContext context, Map<String, String> story) {
    final index = stories.indexWhere((item) => item['key'] == story['key']);
    if (index < 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoryViewer(stories: List.of(stories), initialIndex: index),
        fullscreenDialog: true,
      ),
    );
  }
}
