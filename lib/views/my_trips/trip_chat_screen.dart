import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/services/user_notification_service.dart';

class TripChatScreen extends StatefulWidget {
  final String tripId;
  final String tripName;

  const TripChatScreen({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send(Map<String, dynamic> trip) async {
    final user = FirebaseAuth.instance.currentUser;
    final message = _messageController.text.trim();
    if (user == null || message.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      await FirebaseFirestore.instance
          .collection('trip_chats')
          .doc(widget.tripId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'senderName': user.displayName ?? user.email ?? 'Traveler',
            'text': message,
            'createdAt': FieldValue.serverTimestamp(),
          });
      final members = _memberIds(trip)..remove(user.uid);
      for (final memberId in members) {
        await UserNotificationService.create(
          userId: memberId,
          type: 'trip_message',
          title: 'New message in ${widget.tripName}',
          message: '${user.displayName ?? 'A traveler'}: $message',
          tripId: widget.tripId,
          tripName: widget.tripName,
          actorUserId: user.uid,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Set<String> _memberIds(Map<String, dynamic> trip) {
    final ids = <String>{};
    final owner = trip['userId']?.toString() ?? '';
    if (owner.isNotEmpty) ids.add(owner);
    for (final member
        in (trip['joinedUsers'] as List? ?? []).whereType<Map>()) {
      final id = member['userId']?.toString() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tripName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Trip chat', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .snapshots(),
        builder: (context, tripSnapshot) {
          if (!tripSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trip = tripSnapshot.data?.data();
          if (trip == null) {
            return const Center(
              child: Text('This trip is no longer available.'),
            );
          }
          final permitted = user != null && _memberIds(trip).contains(user.uid);
          if (!permitted) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Trip chat is available once your place has been confirmed.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: _Messages(
                  tripId: widget.tripId,
                  currentUserId: user.uid,
                ),
              ),
              SafeArea(
                top: false,
                child: _Composer(
                  controller: _messageController,
                  sending: _sending,
                  onSend: () => _send(trip),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  final String tripId;
  final String currentUserId;
  const _Messages({required this.tripId, required this.currentUserId});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('trip_chats')
          .doc(tripId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(
            child: Text('Start the conversation with your trip group.'),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data();
            final mine = data['senderId']?.toString() == currentUserId;
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 290),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine)
                      Text(
                        data['senderName']?.toString() ?? 'Traveler',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    if (!mine) const SizedBox(height: 3),
                    Text(
                      data['text']?.toString() ?? '',
                      style: TextStyle(
                        color: mine
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Message your trip group',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: sending ? null : onSend,
          tooltip: 'Send message',
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
        ),
      ],
    ),
  );
}
