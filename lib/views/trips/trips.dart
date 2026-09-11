import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:riendzo/widgets/riendzo_sliver_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/views/my_trips/booking/booking_page.dart';
import 'package:riendzo/views/my_trips/my_trips.dart';
import 'package:riendzo/views/trips/widgets/trip_searchbar.dart';

import '../../widgets/screen_sections.dart';
import '../my_trips/trip_details.dart';

enum _DiscoverTab { recommended, nearby, upcoming, past }

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
  bool onlyAvailable = false;
  _DiscoverTab selectedTab = _DiscoverTab.recommended;

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
        .get()
        .then((snapshot) {
          final matching = snapshot.docs.where((doc) {
            final data = doc.data();
            final destination = (data['destination'] as String? ?? '')
                .toLowerCase();
            return searchWords.any(destination.contains);
          }).toList();
          final filtered = _applyTabFilters(matching);

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
    final isPast = selectedTab == _DiscoverTab.past;
    final tabTitle = switch (selectedTab) {
      _DiscoverTab.recommended => 'Recommended for you',
      _DiscoverTab.nearby => 'Trips near you',
      _DiscoverTab.upcoming => 'Upcoming departures',
      _DiscoverTab.past => 'Past adventures',
    };

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          RiendzoSliverAppBar(
            title: 'Discover trips',
            subtitle: 'Find people, places, and experiences',
            actions: [
              IconButton(
                tooltip: 'My trips',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyTrips()),
                ),
                icon: const Icon(Icons.card_travel_rounded),
              ),
              IconButton(
                tooltip: 'Create trip',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingPage()),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _DiscoverControlsDelegate(
              child: _DiscoverControls(
                selectedTab: selectedTab,
                searchInput: searchInput,
                selectedDateRange: selectedDateRange,
                onlyAvailable: onlyAvailable,
                onSearchTap: _openSearchFilters,
                onAvailabilityChanged: (value) {
                  setState(() {
                    onlyAvailable = value;
                    hasSearched = false;
                  });
                },
                onTabChanged: (tab) {
                  setState(() {
                    selectedTab = tab;
                    hasSearched = false;
                    filteredTrips = [];
                  });
                },
              ),
            ),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            _DiscoverIntro(
              title: tabTitle,
              isPast: isPast,
              onCreateTrip: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingPage()),
              ),
            ),
            Sections(
              sectionName: hasSearched && filteredTrips.isNotEmpty
                  ? "Results for '$searchInput'"
                  : tabTitle,
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
                    .where(
                      'status',
                      isEqualTo: isPast ? 'completed' : 'ongoing',
                    ),
                emptyText: isPast
                    ? 'No past trips yet.'
                    : 'No trips match these filters yet.',
                builder: (trips) => _TripList(
                  trips: _applyTabFilters(trips),
                  emptyText: 'No trips match these filters yet.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SearchCard(
          selectedDateRange: selectedDateRange,
          onDateRangeSelected: (range) {
            setState(() {
              selectedDateRange = range;
              hasSearched = false;
            });
          },
          onSearch: (value) {
            Navigator.pop(sheetContext);
            onSearch(value);
          },
        ),
      ),
    );
  }

  List<DocumentSnapshot> _applyTabFilters(List<DocumentSnapshot> source) {
    final trips = source.where((trip) {
      final data = trip.data() as Map<String, dynamic>;
      final status = data['status']?.toString();
      if (selectedTab == _DiscoverTab.past) {
        if (status != 'completed') return false;
      } else if (status != 'ongoing') {
        return false;
      }

      final current = DiscoverTripCard.currentGroupSize(data);
      final maximum = DiscoverTripCard.maxGroupSize(data, current);
      if (onlyAvailable && current >= maximum) return false;

      if (selectedDateRange != null) {
        final start = _tryParseDate(data['startDate']?.toString());
        final end = _tryParseDate(data['endDate']?.toString()) ?? start;
        if (start != null && end != null) {
          if (end.isBefore(selectedDateRange!.start) ||
              start.isAfter(selectedDateRange!.end)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    int compareDate(DocumentSnapshot a, DocumentSnapshot b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = _tryParseDate(aData['startDate']?.toString());
      final bDate = _tryParseDate(bData['startDate']?.toString());
      return (aDate ?? DateTime(2100)).compareTo(bDate ?? DateTime(2100));
    }

    switch (selectedTab) {
      case _DiscoverTab.recommended:
        trips.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCurrent = DiscoverTripCard.currentGroupSize(aData);
          final bCurrent = DiscoverTripCard.currentGroupSize(bData);
          final aSpots =
              DiscoverTripCard.maxGroupSize(aData, aCurrent) - aCurrent;
          final bSpots =
              DiscoverTripCard.maxGroupSize(bData, bCurrent) - bCurrent;
          return bSpots.compareTo(aSpots);
        });
      case _DiscoverTab.nearby:
        trips.sort((a, b) {
          final aName =
              (a.data() as Map<String, dynamic>)['destination']
                  ?.toString()
                  .toLowerCase() ??
              '';
          final bName =
              (b.data() as Map<String, dynamic>)['destination']
                  ?.toString()
                  .toLowerCase() ??
              '';
          return aName.compareTo(bName);
        });
      case _DiscoverTab.upcoming:
        trips.sort(compareDate);
      case _DiscoverTab.past:
        trips.sort((a, b) => compareDate(b, a));
    }
    return trips;
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

class _DiscoverControlsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _DiscoverControlsDelegate({required this.child});

  @override
  double get minExtent => 142;

  @override
  double get maxExtent => 142;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: overlapsContent ? 3 : 0,
      shadowColor: Colors.black26,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _DiscoverControlsDelegate oldDelegate) => true;
}

class _DiscoverControls extends StatelessWidget {
  final _DiscoverTab selectedTab;
  final String searchInput;
  final DateTimeRange? selectedDateRange;
  final bool onlyAvailable;
  final VoidCallback onSearchTap;
  final ValueChanged<bool> onAvailabilityChanged;
  final ValueChanged<_DiscoverTab> onTabChanged;

  const _DiscoverControls({
    required this.selectedTab,
    required this.searchInput,
    required this.selectedDateRange,
    required this.onlyAvailable,
    required this.onSearchTap,
    required this.onAvailabilityChanged,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');
    final hasFilters = searchInput.isNotEmpty || selectedDateRange != null;
    final summary = searchInput.isNotEmpty
        ? searchInput
        : selectedDateRange != null
        ? '${dateFormat.format(selectedDateRange!.start)} – ${dateFormat.format(selectedDateRange!.end)}'
        : 'Where would you like to go?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSearchTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(
                          hasFilters
                              ? Icons.tune_rounded
                              : Icons.search_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: onlyAvailable,
                showCheckmark: false,
                avatar: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('Open'),
                onSelected: onAvailabilityChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _tabChip('Recommended', _DiscoverTab.recommended),
                _tabChip('Nearby', _DiscoverTab.nearby),
                _tabChip('Upcoming', _DiscoverTab.upcoming),
                _tabChip('Past', _DiscoverTab.past),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, _DiscoverTab tab) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selectedTab == tab,
        onSelected: (_) => onTabChanged(tab),
      ),
    );
  }
}

class _DiscoverIntro extends StatelessWidget {
  final String title;
  final bool isPast;
  final VoidCallback onCreateTrip;

  const _DiscoverIntro({
    required this.title,
    required this.isPast,
    required this.onCreateTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  isPast
                      ? 'Look back at trips completed by the community.'
                      : 'Compare dates, group size and open spots before joining.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (!isPast) ...[
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: onCreateTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripSkeletonList extends StatelessWidget {
  const _TripSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          height: 300,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
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
          return const _TripSkeletonList();
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
  final String emptyText;

  const _TripList({
    required this.trips,
    this.emptyText = 'No trips available.',
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) return _EmptyTripState(text: emptyText);
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

class DiscoverTripCard extends StatefulWidget {
  final DocumentSnapshot trip;

  const DiscoverTripCard({super.key, required this.trip});

  @override
  State<DiscoverTripCard> createState() => _DiscoverTripCardState();

  static int currentGroupSize(Map<String, dynamic> data) {
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

  static int maxGroupSize(Map<String, dynamic> data, int currentGroupSize) {
    final rawMax = data['maxGroupSize'];
    final maxGroupSize = rawMax is num
        ? rawMax.toInt()
        : int.tryParse(rawMax?.toString() ?? '');
    return maxGroupSize == null || maxGroupSize < currentGroupSize
        ? currentGroupSize.clamp(1, 6)
        : maxGroupSize;
  }
}

class _DiscoverTripCardState extends State<DiscoverTripCard> {
  bool isSaved = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.trip.data() as Map<String, dynamic>;
    final images = _tripImages(data);
    final tripName = _nonEmpty(data['tripName'], fallback: 'Unnamed trip');
    final destination = _nonEmpty(
      data['destination'],
      fallback: 'Unknown destination',
    );
    final budget = CurrencyFormatter.formatRand(data['budget']);
    final travelType = _nonEmpty(data['travelType'], fallback: 'Trip');
    final currentGroupSize = DiscoverTripCard.currentGroupSize(data);
    final maxGroupSize = DiscoverTripCard.maxGroupSize(data, currentGroupSize);
    final availableSpots = (maxGroupSize - currentGroupSize).clamp(0, 99);
    final dateLabel = _dateLabel(data);

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
                availableSpots: availableSpots,
                isSaved: isSaved,
                onSave: () => setState(() => isSaved = !isSaved),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
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
        builder: (context) => TripDetailScreen(tripId: widget.trip.id),
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

  String _dateLabel(Map<String, dynamic> data) {
    final start = data['startDate']?.toString().trim() ?? '';
    final end = data['endDate']?.toString().trim() ?? '';
    if (start.isEmpty && end.isEmpty) return 'Dates shared by the host';
    if (end.isEmpty || end == start) return start;
    return '$start – $end';
  }
}

class _TripHeroPhoto extends StatelessWidget {
  final List<String> images;
  final String destination;
  final String tripName;
  final String price;
  final int availableSpots;
  final bool isSaved;
  final VoidCallback onSave;

  const _TripHeroPhoto({
    required this.images,
    required this.destination,
    required this.tripName,
    required this.price,
    required this.availableSpots,
    required this.isSaved,
    required this.onSave,
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
                const SizedBox(width: 8),
                _AvailabilityPill(availableSpots: availableSpots),
                const Spacer(),
                if (images.length > 1) _PhotoCountBadge(count: images.length),
                const SizedBox(width: 8),
                _SaveTripButton(isSaved: isSaved, onPressed: onSave),
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

class _AvailabilityPill extends StatelessWidget {
  final int availableSpots;

  const _AvailabilityPill({required this.availableSpots});

  @override
  Widget build(BuildContext context) {
    final available = availableSpots > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: available ? const Color(0xFFE6F8EF) : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Text(
          available ? '$availableSpots open' : 'Full',
          style: TextStyle(
            color: available
                ? const Color(0xFF087443)
                : const Color(0xFFA32020),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SaveTripButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onPressed;

  const _SaveTripButton({required this.isSaved, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: isSaved ? 'Remove saved trip' : 'Save trip',
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(
          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: Colors.white,
        ),
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
