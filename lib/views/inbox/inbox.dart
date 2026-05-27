import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'user_list_screen.dart'; // Import the user list screen

class Inbox extends StatefulWidget {
  const Inbox({super.key});

  @override
  _InboxState createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  List<Map<String, dynamic>> _conversations = [];
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
    _fetchConversations();
  }

  void _fetchCurrentUserName() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final currentUserRef = FirebaseDatabase.instance.ref('users/$userId');
      final snapshot = await currentUserRef.get();
      if (snapshot.exists) {
        setState(() {
          _currentUserName = snapshot.child('name').value as String? ?? 'Unknown';
        });
      }
    }
  }

  void _fetchConversations() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      final conversationsRef = FirebaseDatabase.instance.ref('user_conversations/$userId');

      conversationsRef.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          List<Map<String, dynamic>> conversations = [];
          data.forEach((key, value) {
            var conversationData = value as Map<dynamic, dynamic>;

            String recipientId = key;
            String lastMessage = conversationData['lastMessage'] ?? 'No messages yet';
            String timestamp = conversationData['timestamp'] ?? DateTime.now().toIso8601String();
            String recipientName = conversationData['recipientName'] ?? 'Unknown';
            String recipientProfilePicture = conversationData['recipientProfilePicture'] ?? 'lib/assets/images/profile/p2.png';
            bool isRead = conversationData['isRead'] ?? false; // Default to unread if missing

            if (recipientId.isNotEmpty) {
              conversations.add({
                'uid': recipientId,
                'lastMessage': lastMessage,
                'timestamp': timestamp,
                'recipientId': recipientId,
                'recipientName': recipientName,
                'recipientProfilePicture': recipientProfilePicture,
                'isRead': isRead,  // Store read/unread status
              });
            }
          });

          conversations.sort((a, b) {
            DateTime timeA = DateTime.parse(a['timestamp']);
            DateTime timeB = DateTime.parse(b['timestamp']);
            return timeB.compareTo(timeA); // Sort newest first
          });

          setState(() {
            _conversations = conversations;
          });
        }
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
      ),
      body: _conversations.isEmpty
          ? const Center(child: Text('No conversations yet.'))
          : ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          bool isUnread = !(conversation['isRead'] as bool); // Check if the message is unread

          return ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Always reserve space for the dot, even if it is not shown
                SizedBox(
                  width: 10.0, // Width of the dot (same for both unread and read)
                  height: 10.0,
                  child: isUnread
                      ? Container(
                    decoration: BoxDecoration(
                      color: Colors.blue, // Blue dot for unread
                      shape: BoxShape.circle,
                    ),
                  )
                      : null, // No dot for read messages
                ),
                const SizedBox(width: 8), // Space between the dot (or placeholder) and the profile picture
                CircleAvatar(
                  backgroundImage: NetworkImage(conversation['recipientProfilePicture'] ?? 'lib/assets/images/profile/p2.png'),
                ),
              ],
            ),
            title: Text(
              conversation['recipientName'],
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal, // Bold for unread
              ),
            ),
            subtitle: Text(
              conversation['lastMessage'],
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal, // Bold for unread
              ),
            ),
            trailing: Text(_formatTimestamp(conversation['timestamp'])),
            onTap: () {
              final userId = FirebaseAuth.instance.currentUser?.uid; // Get the current user's ID

              if (conversation['recipientId'].isNotEmpty && userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      recipientId: conversation['recipientId'],
                      userName: conversation['recipientName'],
                      userProfilePicture: conversation['recipientProfilePicture'] ?? 'lib/assets/images/profile/p2.png',
                      senderName: _currentUserName, // Pass the sender's name
                    ),
                  ),
                );

                // Mark the conversation as read in Firebase
                final conversationRef = FirebaseDatabase.instance.ref('user_conversations/$userId/${conversation['recipientId']}');
                conversationRef.update({'isRead': true});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recipient information is incomplete.')),
                );
              }
            },
          );
        },



      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserListScreen()),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    print('Formatting timestamp: $timestamp'); // Debug log
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
