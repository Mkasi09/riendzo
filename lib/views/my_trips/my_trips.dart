import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/views/my_trips/trip_details.dart';

import '../../widgets/Shared Widgets/button_with_icon.dart';
import '../../widgets/Shared Widgets/one_image_card.dart';
import '../../widgets/screen_sections.dart';
import 'booking/booking_page.dart';

class MyTrips extends StatelessWidget {
  const MyTrips({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You are not logged in. Please log in to see your trips.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text('My Trips', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text(
              'Plan, edit, and revisit your travel plans.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            ButtonWithIcon(
              iconData: Icons.add_rounded,
              iconColor: Colors.white,
              cardColor: Theme.of(context).colorScheme.primary,
              textColor: Colors.white,
              text: "Create Trip",
              horizontalPadding: 0,
              verticalPadding: 4,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BookingPage()),
                );
              },
              TextSize: 15,
            ),
            const SizedBox(height: 18),
            const Sections(
              sectionName: 'Your Ongoing Trips',
              trailingText: '',
              veritcalMargin: 10,
            ),
            _TripStream(
              query: FirebaseFirestore.instance
                  .collection('trips')
                  .where('userId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'ongoing'),
              emptyText: 'No ongoing trips yet. Start one above.',
              horizontal: true,
            ),
            const SizedBox(height: 18),
            const Sections(
              sectionName: 'Past Trips',
              trailingText: '',
              veritcalMargin: 10,
            ),
            _TripStream(
              query: FirebaseFirestore.instance
                  .collection('trips')
                  .where('userId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'completed'),
              emptyText: 'Completed trips will appear here.',
              horizontal: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripStream extends StatelessWidget {
  final Query query;
  final String emptyText;
  final bool horizontal;

  const _TripStream({
    required this.query,
    required this.emptyText,
    required this.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyTripState(
            text:
                'Your trips are unavailable right now. Saved trips will reappear when the connection returns.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _EmptyTripState(
            text: 'Your saved trips will appear here when available.',
          );
        }

        final trips = snapshot.data?.docs ?? [];
        _updateCompletedTrips(trips);

        if (trips.isEmpty) return _EmptyTripState(text: emptyText);

        return horizontal
            ? _HorizontalTripList(trips: trips)
            : _VerticalTripList(trips: trips);
      },
    );
  }

  void _updateCompletedTrips(List<QueryDocumentSnapshot> trips) {
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy');

    for (final trip in trips) {
      final data = trip.data() as Map<String, dynamic>;
      final endDate = _tryParseDate(dateFormat, data['endDate'] as String?);
      if (endDate != null && endDate.isBefore(now)) {
        FirebaseFirestore.instance.collection('trips').doc(trip.id).update({
          'status': 'completed',
        });
      }
    }
  }

  DateTime? _tryParseDate(DateFormat dateFormat, String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return dateFormat.parse(value);
    } catch (_) {
      return null;
    }
  }
}

class _HorizontalTripList extends StatelessWidget {
  final List<QueryDocumentSnapshot> trips;

  const _HorizontalTripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width * 0.72).clamp(240.0, 330.0);

    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return _TripCardLink(
            trip: trips[index],
            width: cardWidth,
            height: 210,
          );
        },
      ),
    );
  }
}

class _VerticalTripList extends StatelessWidget {
  final List<QueryDocumentSnapshot> trips;

  const _VerticalTripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final trip in trips)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TripCardLink(
              trip: trip,
              width: double.infinity,
              height: 210,
            ),
          ),
      ],
    );
  }
}

class _TripCardLink extends StatelessWidget {
  final QueryDocumentSnapshot trip;
  final double width;
  final double height;

  const _TripCardLink({
    required this.trip,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final data = trip.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailScreen(tripId: trip.id),
          ),
        );
      },
      child: OneImageCard(
        location: data['destination'] as String? ?? 'Unknown destination',
        imageLink: data['imagePath'] as String? ?? '',
        width: width,
        height: height,
      ),
    );
  }
}

class _EmptyTripState extends StatelessWidget {
  final String text;

  const _EmptyTripState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Icon(
              Icons.card_travel_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
