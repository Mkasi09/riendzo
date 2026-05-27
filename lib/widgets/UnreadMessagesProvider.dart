import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UnreadMessagesProvider with ChangeNotifier {
  int _unreadMessagesCount = 0;
  int get unreadMessagesCount => _unreadMessagesCount;

  void fetchUnreadMessagesCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final conversationsRef = FirebaseDatabase.instance.ref('user_conversations/$userId');
      conversationsRef.onValue.listen((event) {
        int unreadCount = 0;
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          data.forEach((key, value) {
            var conversationData = value as Map<dynamic, dynamic>;
            if (conversationData['isRead'] == false) {
              unreadCount++;
            }
          });
        }

        _unreadMessagesCount = unreadCount;
        notifyListeners(); // Notify the UI to rebuild with new data
      });
    }
  }
}
