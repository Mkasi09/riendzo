import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/Shared Widgets/home_avatars_row.dart';
import '../../widgets/Shared Widgets/one_image_card.dart';
import '../my_trips/booking/booking_page.dart';
import '../my_trips/trip_details.dart';
import '../trips/trips.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('trips').snapshots(),
          builder: (context, snapshot) {
            final trips = snapshot.data?.docs ?? [];

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        "Where do you\nWant to travel?",
                        style: Theme.of(
                          context,
                        ).textTheme.displayMedium?.copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 20),
                      _SearchButton(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TripsFeed(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Categories',
                        actionText: 'Create trip',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookingPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CategoryList(trips: trips),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Recommended trips',
                        actionText: 'View more',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TripsFeed(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TripRail(
                        trips: trips,
                        emptyText:
                            'No saved trips yet. You can still create a trip offline.',
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Top Stories',
                        actionText: '',
                        onAction: null,
                      ),
                      const SizedBox(height: 12),
                      const Stories1(
                        radius: 35,
                        margin: .01,
                        statusUpdate: Color(0xFF6366F1),
                        horizontalPadding: 6,
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Popular trips',
                        actionText: 'View more',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TripsFeed(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TripRail(
                        trips: _popularTrips(trips),
                        emptyText:
                            'Popular trips will appear when data is available.',
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _popularTrips(List<QueryDocumentSnapshot> trips) {
    final sorted = [...trips];
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aLikes = aData['likeCount'] is int ? aData['likeCount'] as int : 0;
      final bLikes = bData['likeCount'] is int ? bData['likeCount'] as int : 0;
      return bLikes.compareTo(aLikes);
    });
    return sorted.take(6).toList();
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search destinations...',
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionText.isNotEmpty)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionText,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<QueryDocumentSnapshot> trips;

  const _CategoryList({required this.trips});

  @override
  Widget build(BuildContext context) {
    final categories =
        trips
            .map((trip) => (trip.data() as Map<String, dynamic>)['interest'])
            .whereType<String>()
            .where((interest) => interest.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (categories.isEmpty) {
      return const _EmptyState(text: 'Trip interests will appear here.');
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Chip(
            label: Text(categories[index], overflow: TextOverflow.ellipsis),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}

class _TripRail extends StatelessWidget {
  final List<QueryDocumentSnapshot> trips;
  final String emptyText;

  const _TripRail({required this.trips, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return _EmptyState(text: emptyText);
    }

    final cardWidth = MediaQuery.sizeOf(context).width.clamp(280.0, 420.0);

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final trip = trips[index];
          final data = trip.data() as Map<String, dynamic>;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailScreen(tripId: trip.id),
              ),
            ),
            child: OneImageCard(
              location: data['destination'] as String? ?? 'Unknown destination',
              imageLink: data['imagePath'] as String? ?? '',
              width: cardWidth * 0.72,
              height: 210,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
