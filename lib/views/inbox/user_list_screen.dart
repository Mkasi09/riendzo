import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user =
              users.values.toList()[index] as Map<dynamic, dynamic>;
              final userId = users.keys.toList()[index];

              // Filter out the current user
              if (userId == currentUserId) {
                return Container(); // Skip current user
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(user['profilePicture'] ??
                      'lib/assets/images/profile/p2.png'), // Local fallback asset
                ),
                title: Text(user['name'] ?? 'Unknown'),
                onTap: () async {
                  if (currentUserId != null) {
                    final timestamp = DateTime.now().toIso8601String();

                    // Fetch current user's data (name and profile picture)
                    final currentUserSnapshot = await FirebaseDatabase.instance
                        .ref('users/$currentUserId')
                        .once();
                    final currentUserData = currentUserSnapshot.snapshot.value
                    as Map<dynamic, dynamic>?;
                    final currentUserName =
                        currentUserData?['name'] ?? 'Unknown';
                    final currentUserProfilePicture =
                        currentUserData?['profilePicture'] ??
                            'lib/assets/images/profile/p2.png'; // Local fallback asset

                    // Reference to both users' conversations
                    final conversationsRef = FirebaseDatabase.instance
                        .ref('user_conversations/$currentUserId/$userId');
                    final otherUserConversationsRef = FirebaseDatabase.instance
                        .ref('user_conversations/$userId/$currentUserId');

                    // Check if conversation exists
                    final existingConversation = await conversationsRef.once();

                    if (existingConversation.snapshot.value == null) {
                      // If conversation doesn't exist, set it for both users
                      await conversationsRef.set({
                        'lastMessage': '',
                        'timestamp': timestamp,
                        'recipientId': userId,
                        'recipientName': user['name'] ?? 'Unknown',
                        'recipientProfilePicture': user['profilePicture'] ??
                            'lib/assets/images/profile/p2.png',
                        'senderName': currentUserName,
                        'senderProfilePicture': currentUserProfilePicture,
                      });

                      await otherUserConversationsRef.set({
                        'lastMessage': '',
                        'timestamp': timestamp,
                        'recipientId': currentUserId,
                        'recipientName': currentUserName,
                        'recipientProfilePicture': currentUserProfilePicture,
                        'senderName': user['name'] ?? 'Unknown',
                        'senderProfilePicture': user['profilePicture'] ??
                            'lib/assets/images/profile/p2.png',
                      });
                    }

                    // Navigate to ChatScreen and pass necessary details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          recipientId: userId,
                          userName: user['name'] ?? 'Unknown',
                          userProfilePicture: user['profilePicture'] ??
                              'lib/assets/images/profile/p2.png',
                          senderName: currentUserName, // Pass sender name
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
