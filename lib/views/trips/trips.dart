import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/views/my_trips/booking/booking_page.dart';
import 'package:riendzo/views/my_trips/my_trips.dart';
import 'package:riendzo/views/trips/widgets/trip_searchbar.dart';
import 'package:riendzo/widgets/Shared%20Widgets/button_with_icon.dart';

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
            Text('Discover', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text(
              'Find a trip worth joining, with the details that matter before you commit.',
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
                  : _TripList(trips: filteredTrips)
            else
              _TripStream(
                query: FirebaseFirestore.instance
                    .collection('trips')
                    .where('status', isEqualTo: 'ongoing'),
                emptyText: 'No ongoing trips available.',
                builder: (trips) => _TripList(trips: trips),
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
              builder: (trips) => _TripList(trips: trips),
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

class _TripList extends StatelessWidget {
  final List<DocumentSnapshot> trips;

  const _TripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final trip in trips)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DiscoverTripCard(trip: trip),
          ),
      ],
    );
  }
}

class DiscoverTripCard extends StatelessWidget {
  final DocumentSnapshot trip;

  const DiscoverTripCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final data = trip.data() as Map<String, dynamic>;
    final images = _tripImages(data);
    final tripName = _nonEmpty(data['tripName'], fallback: 'Unnamed trip');
    final destination = _nonEmpty(
      data['destination'],
      fallback: 'Unknown destination',
    );
    final budget = CurrencyFormatter.formatRand(data['budget']);
    final travelType = _nonEmpty(data['travelType'], fallback: 'Trip');
    final currentGroupSize = _currentGroupSize(data);
    final maxGroupSize = _maxGroupSize(data, currentGroupSize);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openTrip(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TripHeroPhoto(
                images: images,
                destination: destination,
                tripName: tripName,
                price: budget,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _CompactInfoTile(
                        icon: Icons.group_outlined,
                        label: 'Group size',
                        value: '$currentGroupSize/$maxGroupSize going',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactInfoTile(
                        icon: Icons.explore_outlined,
                        label: 'Travel type',
                        value: travelType,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTrip(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailScreen(tripId: trip.id),
      ),
    );
  }

  static String _nonEmpty(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static List<String> _tripImages(Map<String, dynamic> data) {
    final imageUrls = data['imageUrls'];
    if (imageUrls is List) {
      final urls = imageUrls
          .map((item) => item.toString())
          .where((url) => url.trim().isNotEmpty)
          .take(4)
          .toList();
      if (urls.isNotEmpty) return urls;
    }

    final imagePath = data['imagePath']?.toString() ?? '';
    return imagePath.isEmpty ? const [] : [imagePath];
  }

  static int _currentGroupSize(Map<String, dynamic> data) {
    final ownerId = data['userId']?.toString();
    final participantIds = <String>{};
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

    return participantIds.isEmpty ? 1 : participantIds.length;
  }

  static int _maxGroupSize(Map<String, dynamic> data, int currentGroupSize) {
    final rawMax = data['maxGroupSize'];
    final maxGroupSize = rawMax is num
        ? rawMax.toInt()
        : int.tryParse(rawMax?.toString() ?? '');
    return maxGroupSize == null || maxGroupSize < currentGroupSize
        ? currentGroupSize.clamp(1, 6)
        : maxGroupSize;
  }
}

class _TripHeroPhoto extends StatelessWidget {
  final List<String> images;
  final String destination;
  final String tripName;
  final String price;

  const _TripHeroPhoto({
    required this.images,
    required this.destination,
    required this.tripName,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TripImageCollage(images: images, destination: destination),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xCC000000)],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Flexible(child: _PricePill(text: price)),
                const Spacer(),
                if (images.length > 1) _PhotoCountBadge(count: images.length),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tripName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripImageCollage extends StatelessWidget {
  final List<String> images;
  final String destination;

  const _TripImageCollage({required this.images, required this.destination});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return _TripImageFallback(destination: destination);

    if (images.length == 1) {
      return _TripImage(url: images.first);
    }

    return Row(
      children: [
        Expanded(flex: 3, child: _TripImage(url: images.first)),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _TripImage(url: images[1])),
              if (images.length > 2) ...[
                const SizedBox(height: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _TripImage(url: images[2]),
                      if (images.length > 3)
                        ColoredBox(
                          color: const Color(0x99000000),
                          child: Center(
                            child: Text(
                              '+${images.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TripImageFallback extends StatelessWidget {
  final String destination;

  const _TripImageFallback({required this.destination});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDBEAFE), Color(0xFFCCFBF1)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.landscape_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripImage extends StatelessWidget {
  final String url;

  const _TripImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String text;

  const _PricePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CompactInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompactInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCountBadge extends StatelessWidget {
  final int count;

  const _PhotoCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
