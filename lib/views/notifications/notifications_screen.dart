import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/user_notification_service.dart';
import 'package:riendzo/views/my_trips/trip_details.dart';
import 'package:riendzo/views/profile/user_profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: user == null
          ? const _NotificationMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              message: 'Log in to see trip requests and updates.',
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_notifications')
                  .doc(user.uid)
                  .collection('items')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const _NotificationMessage(
                    icon: Icons.notifications_off_outlined,
                    title: 'Notifications unavailable',
                    message: 'Please check your connection and try again.',
                  );
                }

                final notifications = snapshot.data?.docs ?? [];
                if (notifications.isEmpty) {
                  return const _NotificationMessage(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message:
                        'Trip invites, requests, approvals, and declines will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _NotificationCard(
                      userId: user.uid,
                      notification: notifications[index],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String userId;
  final QueryDocumentSnapshot notification;

  const _NotificationCard({required this.userId, required this.notification});

  @override
  Widget build(BuildContext context) {
    final data = notification.data() as Map<String, dynamic>;
    final title = data['title']?.toString() ?? 'Notification';
    final message = data['message']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final tripId = data['tripId']?.toString() ?? '';
    final actorUserId = data['actorUserId']?.toString() ?? '';
    final inviteStatus = data['inviteStatus']?.toString() ?? '';
    final read = data['read'] == true;
    final createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;

    return Material(
      color: read
          ? Colors.white
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: tripId.isEmpty ? () => _markRead() : () => _openTrip(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _iconForType(type),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat(
                              'MMM d, h:mm a',
                            ).format(createdAt.toDate()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (!read)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (type == 'trip_invite' &&
                      tripId.isNotEmpty &&
                      inviteStatus.isEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _respondToInvite(context, accepted: false),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _respondToInvite(context, accepted: true),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Accept'),
                      ),
                    ),
                  ] else ...[
                    if (actorUserId.isNotEmpty && type == 'join_request') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openProfile(context, actorUserId),
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Profile'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (tripId.isNotEmpty)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openTrip(context),
                          icon: const Icon(Icons.route_outlined),
                          label: const Text('Trip'),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _markRead,
                          icon: const Icon(Icons.done_rounded),
                          label: const Text('Mark read'),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'trip_invite' => Icons.mail_outline_rounded,
      'invite_accepted' => Icons.mark_email_read_outlined,
      'invite_declined' => Icons.cancel_outlined,
      'join_request' => Icons.person_add_alt_1_outlined,
      'join_approved' => Icons.check_circle_outline_rounded,
      'join_declined' => Icons.cancel_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }

  Future<void> _markRead() {
    return UserNotificationService.markRead(
      userId: userId,
      notificationId: notification.id,
    );
  }

  Future<void> _openTrip(BuildContext context) async {
    await _markRead();
    if (!context.mounted) return;

    final data = notification.data() as Map<String, dynamic>;
    final tripId = data['tripId']?.toString() ?? '';
    if (tripId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TripDetailScreen(tripId: tripId)),
    );
  }

  Future<void> _openProfile(BuildContext context, String actorUserId) async {
    await _markRead();
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: actorUserId),
      ),
    );
  }

  Future<void> _respondToInvite(
    BuildContext context, {
    required bool accepted,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = notification.data() as Map<String, dynamic>;
    final tripId = data['tripId']?.toString() ?? '';
    if (tripId.isEmpty) return;

    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
    final inviteRef = tripRef.collection('invites').doc(user.uid);

    try {
      var ownerId = data['actorUserId']?.toString() ?? '';
      var tripName = 'this trip';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final tripSnapshot = await transaction.get(tripRef);
        if (!tripSnapshot.exists) return;

        final tripData = tripSnapshot.data() as Map<String, dynamic>;
        ownerId = tripData['userId']?.toString() ?? ownerId;
        tripName = tripData['tripName']?.toString() ?? tripName;

        if (accepted) {
          final participantIds = _participantIds(tripData);
          final currentGroupSize = participantIds.isEmpty
              ? 1
              : participantIds.length;
          final maxGroupSize = _maxGroupSize(tripData, currentGroupSize);

          if (!participantIds.contains(user.uid) &&
              currentGroupSize >= maxGroupSize) {
            throw const _TripFullException();
          }

          transaction.update(tripRef, {
            'joinedUsers': FieldValue.arrayUnion([
              {
                'userId': user.uid,
                'displayName':
                    user.displayName ?? user.email ?? 'Riendzo traveler',
                'email': user.email ?? '',
                'photoURL': user.photoURL ?? '',
                'joinedAt': Timestamp.now(),
                'source': 'invite',
              },
            ]),
            'inviteStatuses.${user.uid}': 'accepted',
          });
        } else {
          transaction.update(tripRef, {
            'inviteStatuses.${user.uid}': 'declined',
          });
        }

        transaction.set(inviteRef, {
          'userId': user.uid,
          'status': accepted ? 'accepted' : 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
          'respondedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await notification.reference.update({
        'read': true,
        'inviteStatus': accepted ? 'accepted' : 'declined',
      });

      await UserNotificationService.create(
        userId: ownerId,
        type: accepted ? 'invite_accepted' : 'invite_declined',
        title: accepted ? 'Trip invite accepted' : 'Trip invite declined',
        message:
            '${user.displayName ?? user.email ?? 'Someone'} ${accepted ? 'accepted' : 'declined'} your invite to $tripName.',
        tripId: tripId,
        actorUserId: user.uid,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted ? 'Trip invite accepted.' : 'Trip invite declined.',
          ),
        ),
      );
    } on _TripFullException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trip is already full.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this invite.')),
      );
    }
  }

  Set<String> _participantIds(Map<String, dynamic> data) {
    final participantIds = <String>{};
    final ownerId = data['userId']?.toString();
    if (ownerId != null && ownerId.isNotEmpty) participantIds.add(ownerId);

    final joinedUsers = data['joinedUsers'];
    if (joinedUsers is List) {
      for (final joinedUser in joinedUsers) {
        final id = joinedUser is Map
            ? (joinedUser['userId'] ?? joinedUser['id'])?.toString()
            : null;
        if (id != null && id.isNotEmpty) participantIds.add(id);
      }
    }

    return participantIds;
  }

  int _maxGroupSize(Map<String, dynamic> data, int currentGroupSize) {
    final rawMax = data['maxGroupSize'];
    final maxGroupSize = rawMax is num
        ? rawMax.toInt()
        : int.tryParse(rawMax?.toString() ?? '');
    if (maxGroupSize == null || maxGroupSize < currentGroupSize) {
      return currentGroupSize < 6 ? 6 : currentGroupSize;
    }
    return maxGroupSize;
  }
}

class _TripFullException implements Exception {
  const _TripFullException();
}

class _NotificationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
