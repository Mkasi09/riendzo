import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String userName;
  final String userProfilePicture;
  final String senderName; // New senderName parameter

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.userName,
    required this.userProfilePicture,
    required this.senderName, // New senderName
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to the latest message when the chat loads
    FirebaseFirestore.instance
        .collection('chats')
        .doc(_generateChatId(FirebaseAuth.instance.currentUser!.uid, widget.recipientId))
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final chatId = _generateChatId(currentUserId!, widget.recipientId);

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 5),
          AppBar(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.userProfilePicture),
                ),
                const SizedBox(width: 10),
                Text(widget.userName),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSentByMe = message['sender'] == currentUserId;

                    final messageTimestamp = DateTime.fromMillisecondsSinceEpoch(message['timestamp']);
                    final formattedTime = DateFormat('hh:mm a').format(messageTimestamp);

                    return Align(
                      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSentByMe ? Colors.blue[300] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(message['text']),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                            child: Text(
                              formattedTime,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Enter your message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final chatId = _generateChatId(currentUserId!, widget.recipientId);
    final text = _messageController.text.trim();

    if (text.isNotEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Add the message to Firestore
      FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': text,
        'sender': currentUserId,
        'timestamp': timestamp,
      });

      // Update the last message in both users' conversations in Firebase Realtime Database
      final conversationsRef = FirebaseDatabase.instance.ref(
          'user_conversations/$currentUserId/${widget.recipientId}');
      final otherUserConversationsRef = FirebaseDatabase.instance.ref(
          'user_conversations/${widget.recipientId}/$currentUserId');

      // Update the sender's conversation entry
      conversationsRef.update({
        'lastMessage': text,
        'timestamp': DateTime.now().toIso8601String(),
        'recipientName': widget.userName, // Recipient's name
        'recipientProfilePicture': widget.userProfilePicture,
        'isRead': true, // Sender has read their own message
        'senderName': widget.senderName, // Use the sender's name passed in
      });

      // Update the recipient's conversation entry (message is unread for them)
      otherUserConversationsRef.update({
        'lastMessage': text,
        'timestamp': DateTime.now().toIso8601String(),
        'recipientName': widget.senderName, // Use sender's name
        'recipientProfilePicture': 'lib/assets/images/profile/p2.png',
        'isRead': false, // Mark as unread for the recipient
      });

      _messageController.clear();

      // Scroll to bottom after sending a message
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }


  String _generateChatId(String currentUserId, String recipientId) {
    return currentUserId.hashCode <= recipientId.hashCode
        ? '$currentUserId-$recipientId'
        : '$recipientId-$currentUserId';
  }
}
