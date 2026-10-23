import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/services/trip_booking_service.dart';
import 'package:riendzo/services/user_notification_service.dart';

class TripBookingScreen extends StatefulWidget {
  final String tripId;

  const TripBookingScreen({super.key, required this.tripId});

  @override
  State<TripBookingScreen> createState() => _TripBookingScreenState();
}

class _TripBookingScreenState extends State<TripBookingScreen> {
  bool _cancelling = false;

  Future<void> _cancel(Map<String, dynamic> trip) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel your place?'),
        content: const Text(
          'This removes you from the trip and releases your place for another traveler.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my place'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel place'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _cancelling = true);
    try {
      await TripBookingService.cancelBooking(
        tripId: widget.tripId,
        userId: user.uid,
      );
      final ownerId = trip['userId']?.toString() ?? '';
      if (ownerId.isNotEmpty && ownerId != user.uid) {
        await UserNotificationService.create(
          userId: ownerId,
          type: 'booking_cancelled',
          title: 'Trip place cancelled',
          message:
              '${user.displayName ?? user.email ?? 'A traveler'} cancelled their place on ${trip['tripName'] ?? 'your trip'}.',
          tripId: widget.tripId,
          actorUserId: user.uid,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your place could not be cancelled.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view a booking.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip booking')),
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
          final joined = (trip['joinedUsers'] as List? ?? [])
              .whereType<Map>()
              .any((person) => person['userId']?.toString() == user.uid);
          if (!joined) {
            return const Center(
              child: Text('You do not have a confirmed place on this trip.'),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: TripBookingService.bookingRef(
              tripId: widget.tripId,
              userId: user.uid,
            ).snapshots(),
            builder: (context, bookingSnapshot) {
              final booking =
                  bookingSnapshot.data?.data() ?? const <String, dynamic>{};
              final status = booking['status']?.toString() ?? 'confirmed';
              final tripCode = widget.tripId.length > 8
                  ? widget.tripId.substring(0, 8)
                  : widget.tripId;
              final userCode = user.uid.length > 6
                  ? user.uid.substring(0, 6)
                  : user.uid;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _BookingHero(
                    title: trip['tripName']?.toString() ?? 'Trip',
                    destination: trip['destination']?.toString() ?? '',
                    status: status,
                  ),
                  const SizedBox(height: 16),
                  _BookingInfoRow(
                    label: 'Dates',
                    value:
                        '${trip['startDate'] ?? 'TBC'} - ${trip['endDate'] ?? 'TBC'}',
                  ),
                  _BookingInfoRow(
                    label: 'Trip budget',
                    value: CurrencyFormatter.formatRand(trip['budget']),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Arrange payment with the trip host. Your place is confirmed; no payment has been taken in Riendzo.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking receipt',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SelectableText('RZ-$tripCode-$userCode'),
                          const SizedBox(height: 4),
                          const Text('Seat confirmed through Riendzo.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : () => _cancel(trip),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(
                      _cancelling ? 'Cancelling...' : 'Cancel my place',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BookingHero extends StatelessWidget {
  final String title;
  final String destination;
  final String status;
  const _BookingHero({
    required this.title,
    required this.destination,
    required this.status,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BookingInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _BookingInfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
  );
}
