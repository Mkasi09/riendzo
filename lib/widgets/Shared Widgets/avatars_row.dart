import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage
import 'package:firebase_database/firebase_database.dart'; // For Realtime Database
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:riendzo/widgets/Shared%20Widgets/story_viewer.dart';
import 'add_story.dart';
import 'user_avatar.dart'; // Your custom UserAvatar widget

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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  File? _selectedImage;

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
          final int storyTimestamp = data['timestamp'] ?? 0;

          if (currentTime - storyTimestamp > 86400000) {
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
      height: MediaQuery.of(context).size.height * 0.085,
      child: ListView.builder(
        itemCount: stories.length + 1, // Add +1 for the "Add Story" button
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.margin),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _pickImage();
                    },
                    child: CircleAvatar(
                      radius: widget.radius * 0.9,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(
                        Icons.add,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // Space between button and icons
                ],
              ),
            );
          }

          final story = stories[index - 1]; // Adjust index for story content
          return GestureDetector(
            onTap: () => _openStoryViewer(context, story),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: widget.margin),
              decoration: BoxDecoration(
                color: widget.statusUpdate,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: story['type'] == 'text'
                  ? CircleAvatar(
                      radius: widget.radius * 1.0,
                      child: Text(
                        story['content'] ?? '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    )
                  : UserAvatar(
                      size: widget.radius * 1.0,
                      picture: story['content'] ?? '', // Load the image URL
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
    String timestamp =
        value['timestamp']?.toString() ?? ''; // Get the timestamp
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
      stories.add({
        'key': key, // Add the key for easy reference
        'type': value['type'],
        'content': value['content'],
        'userName': userName, // Set "My Story" or the fetched username
        'timestamp': timestamp, // Add the timestamp
        'profilePicture': profilePictureUrl, // Add profile picture URL
        'caption': value['caption'] ?? '', // Add caption if available
      });
    });
  }

  /// Handle adding a picture story with a popup preview and caption input
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File selectedImage = File(pickedFile.path);

      // Show the custom popup with the image preview and caption input
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.black.withOpacity(0.9), // Black background
        builder: (context) => AddStoryPopup(imageFile: selectedImage),
      );
    }
  }

  // Open the story viewer for both text and image
  void _openStoryViewer(BuildContext context, Map<String, String> story) {
    String userId = story['userId'] ?? '';
    _usersRef.child(userId).once().then((userSnapshot) {
      String profilePictureUrl = '';
      if (userSnapshot.snapshot.value != null) {
        final userData = Map<String, dynamic>.from(
          userSnapshot.snapshot.value as Map,
        );
        profilePictureUrl =
            userData['profilePicture'] ?? ''; // Get the profile picture URL
      }

      AnimationController progressController = AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(seconds: 5), // Adjust the duration as needed
      );

      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => StoryViewer(
                content: story['content'] ?? '',
                type: story['type'] ?? 'text',
                progressController: progressController,
                userName: story['userName'] ?? 'Unknown',
                timestamp: story['timestamp'] ?? 'Unknown',
                profilePictureUrl: profilePictureUrl,
                userId: userId,
                storyKey: story['key'] ?? '',
                caption:
                    story['caption'] ?? '', // Use the key from the story map
              ),
              fullscreenDialog: true,
            ),
          )
          .then((_) {
            progressController.dispose();
          });
    });
  }
}
