import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../views/inbox/chat_screen.dart';

class StoryViewer extends StatefulWidget {
  final String content;
  final String type;
  final AnimationController progressController;
  final String userName;
  final String timestamp;
  final String profilePictureUrl;
  final String userId;
  final String storyKey;
  final String? caption; // Add caption to the widget

  const StoryViewer({
    super.key,
    required this.content,
    required this.type,
    required this.progressController,
    required this.userName,
    required this.timestamp,
    required this.profilePictureUrl,
    required this.userId,
    required this.storyKey,
    this.caption, // Accept caption as an optional parameter
  });

  @override
  _StoryViewerState createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with TickerProviderStateMixin {
  late String formattedTime;
  final user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'stories',
  );

  @override
  void initState() {
    super.initState();

    String getFormattedTime(String timestamp) {
      DateTime storyTime = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp),
      );
      DateTime now = DateTime.now();
      Duration difference = now.difference(storyTime);

      if (difference.inMinutes < 1) {
        return "Just now";
      } else if (difference.inMinutes < 60) {
        return "${difference.inMinutes} minutes ago";
      } else if (difference.inHours < 24 && storyTime.day == now.day) {
        return "Today, ${DateFormat('HH:mm').format(storyTime)}";
      } else if (difference.inHours < 48 && now.day - storyTime.day == 1) {
        return "Yesterday, ${DateFormat('HH:mm').format(storyTime)}";
      } else {
        return DateFormat('MMM d, HH:mm').format(storyTime);
      }
    }

    formattedTime = getFormattedTime(widget.timestamp);

    // Listen for progress completion to automatically navigate to the next story
    widget.progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextStory(); // Navigate to the next story
      }
    });

    widget.progressController.forward();
  }

  void _navigateToNextStory() {
    // Implement logic to navigate to the next story
    // You could use a page controller, a list of stories, or other methods depending on how stories are structured in your app

    // Example: Show the next story or return to the first if it's the last one
    bool isLastStory =
        false; // You can add a check here to see if it's the last story
    if (isLastStory) {
      Navigator.pop(context); // Exit the viewer if this is the last story
    } else {
      setState(() {
        widget.progressController.reset();
        widget.progressController
            .forward(); // Restart the animation for the next story
        // Update widget.content, widget.type, etc., to the next story's content
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            // Swipe Left: Navigate to the next story
            print('Swiped Left');
            // Add logic to navigate to the next story
          } else if (details.primaryVelocity! > 0) {
            // Swipe Right: Navigate to the previous story
            print('Swiped Right');
            // Add logic to navigate to the previous story
          }
        },
        child: Center(
          child: Stack(
            children: [
              widget.type == 'text'
                  ? Center(
                      child: Text(
                        widget.content,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Stack(
                      children: [
                        Center(
                          child: Image.network(
                            widget.content,
                            fit: BoxFit.contain,
                            height: double.infinity,
                            width: double.infinity,
                          ),
                        ),
                        if (widget.caption != null &&
                            widget.caption!.isNotEmpty)
                          Positioned(
                            bottom: 50,
                            left: 20,
                            right: 20,
                            child: Text(
                              widget.caption!,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: widget.progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: widget.progressController.value,
                      backgroundColor: Colors.grey[600],
                      color: Colors.blue,
                    );
                  },
                ),
              ),
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        widget.progressController.stop();
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 5),
                    CircleAvatar(
                      backgroundImage: NetworkImage(widget.profilePictureUrl),
                      radius: 22,
                    ),
                    const SizedBox(width: 7),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteStory();
                        } else if (value == 'message') {
                          _messageUser();
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return widget.userName == "My Story"
                            ? [
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Delete Story'),
                                ),
                              ]
                            : [
                                const PopupMenuItem<String>(
                                  value: 'message',
                                  child: Text('Message User'),
                                ),
                              ];
                      },
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

  // Function to delete the story
  void _deleteStory() {
    FirebaseFirestore.instance
        .collection('stories')
        .doc(widget.storyKey)
        .delete()
        .then((_) {
          print('Story deleted');
          Navigator.pop(context);
        })
        .catchError((error) {
          print('Failed to delete story: $error');
        });
  }

  // Function to message the user
  void _messageUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid);
      final DataSnapshot snapshot = await userRef.child('name').get();

      String currentUserName = snapshot.exists
          ? snapshot.value as String
          : 'Unknown';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userName: widget.userName,
            recipientId: widget.userId,
            userProfilePicture: widget.profilePictureUrl,
            senderName: currentUserName, // Pass currentUserName as sender
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.progressController.dispose();
    super.dispose();
  }
}
