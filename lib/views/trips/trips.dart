import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/views/my_trips/booking/booking_page.dart';
import 'package:riendzo/views/my_trips/my_trips.dart';
import 'package:riendzo/views/trips/widgets/trip_searchbar.dart';
import 'package:riendzo/widgets/Shared%20Widgets/button_with_icon.dart';

import '../../widgets/Shared Widgets/one_image_card.dart';
import '../../widgets/screen_sections.dart';
import '../my_trips/trip_details.dart';

class TripsFeed extends StatefulWidget {
  const TripsFeed({super.key});

  @override
  State<TripsFeed> createState() => _TripsFeedState();
}

class _TripsFeedState extends State<TripsFeed> {
  DateTimeRange? selectedDateRange;
  final currentDate = DateTime.now();
  final dateFormat = DateFormat('dd/MM/yyyy');
  List<DocumentSnapshot> filteredTrips = [];
  bool hasSearched = false;
  String searchInput = '';

  void onSearch(String searchInput) {
    final query = searchInput.trim();
    setState(() => this.searchInput = query);

    if (query.isEmpty) {
      setState(() {
        filteredTrips = [];
        hasSearched = false;
      });
      return;
    }

    final searchWords = query.toLowerCase().split(RegExp(r'\s*,\s*|\s+'));

    FirebaseFirestore.instance
        .collection('trips')
        .where('status', isEqualTo: 'ongoing')
        .get()
        .then((snapshot) {
          final filtered = snapshot.docs.where((doc) {
            final data = doc.data();
            final destination = (data['destination'] as String? ?? '')
                .toLowerCase();
            return searchWords.any(destination.contains);
          }).toList();

          if (!mounted) return;
          setState(() {
            filteredTrips = filtered;
            hasSearched = true;
          });
        })
        .catchError((error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching trips: $error')),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text('Trips', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text(
              'Find a plan, join a journey, or start your own.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            SearchCard(
              selectedDateRange: selectedDateRange,
              onDateRangeSelected: (range) {
                setState(() => selectedDateRange = range);
              },
              onSearch: onSearch,
            ),
            const SizedBox(height: 16),
            ButtonWithIcon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BookingPage()),
                );
              },
              iconData: Icons.add_rounded,
              iconColor: Colors.white,
              cardColor: Theme.of(context).colorScheme.primary,
              textColor: Colors.white,
              text: "Create Your Own Trip",
              horizontalPadding: 0,
              verticalPadding: 4,
              TextSize: 15,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyTrips()),
                );
              },
              icon: const Icon(Icons.card_travel_rounded),
              label: const Text('View my trips'),
            ),
            Sections(
              sectionName: hasSearched && filteredTrips.isNotEmpty
                  ? "Results for '$searchInput'"
                  : 'Ongoing Trips',
              trailingText: '',
              veritcalMargin: 10,
            ),
            if (hasSearched)
              filteredTrips.isEmpty
                  ? _EmptyTripState(text: "No results found for '$searchInput'")
                  : _TripRail(trips: filteredTrips)
            else
              _TripStream(
                query: FirebaseFirestore.instance
                    .collection('trips')
                    .where('status', isEqualTo: 'ongoing'),
                emptyText: 'No ongoing trips available.',
                builder: (trips) => _TripRail(trips: trips),
              ),
            const SizedBox(height: 16),
            const Sections(
              sectionName: 'Past Trips',
              trailingText: '',
              veritcalMargin: 10,
            ),
            _TripStream(
              query: FirebaseFirestore.instance
                  .collection('trips')
                  .where('status', isEqualTo: 'completed'),
              emptyText: 'No past trips available.',
              builder: (trips) => _TripRail(trips: trips),
            ),
          ],
        ),
      ),
    );
  }

  void updateCompletedTrip(DocumentSnapshot trip) {
    final data = trip.data() as Map<String, dynamic>;
    final endDate = _tryParseDate(data['endDate'] as String?);
    if (endDate != null && endDate.isBefore(currentDate)) {
      FirebaseFirestore.instance.collection('trips').doc(trip.id).update({
        'status': 'completed',
      });
    }
  }

  DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return dateFormat.parse(value);
    } catch (_) {
      return null;
    }
  }
}

class _TripStream extends StatelessWidget {
  final Query query;
  final String emptyText;
  final Widget Function(List<DocumentSnapshot> trips) builder;

  const _TripStream({
    required this.query,
    required this.emptyText,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyTripState(
            text:
                'Trips are unavailable right now. Saved trips will reappear when the connection returns.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _EmptyTripState(
            text: 'Saved trips will appear here when available.',
          );
        }

        final trips = snapshot.data?.docs ?? [];
        if (trips.isEmpty) return _EmptyTripState(text: emptyText);

        return builder(trips);
      },
    );
  }
}

class _TripRail extends StatelessWidget {
  final List<DocumentSnapshot> trips;

  const _TripRail({required this.trips});

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
          final trip = trips[index];
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
              width: cardWidth,
              height: 210,
            ),
          );
        },
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
              Icons.map_outlined,
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
