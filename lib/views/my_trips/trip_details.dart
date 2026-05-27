import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/Shared Widgets/comments_popup.dart';
import '../../widgets/Shared Widgets/navigate_to_edit_trip.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool isLiked = false;
  int likeCount = 0;
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    _getLikeStatus();
    _refreshCommentCount();
  }

  Future<void> _getLikeStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final tripRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('likes');

    final tripLikeDoc = await tripRef.doc(currentUser.uid).get();
    final likesSnapshot = await tripRef.get();

    if (!mounted) return;
    setState(() {
      isLiked = tripLikeDoc.exists && (tripLikeDoc['liked'] ?? false);
      likeCount = likesSnapshot.size;
    });
  }

  Future<void> _refreshCommentCount() async {
    final totalCommentCount = await _getTotalCommentCountWithReplies(
      widget.tripId,
    );
    if (!mounted) return;
    setState(() => commentCount = totalCommentCount);
  }

  Future<int> _getTotalCommentCountWithReplies(String tripId) async {
    var totalCommentCount = 0;

    final commentsSnapshot = await FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('comments')
        .get();

    for (final commentDoc in commentsSnapshot.docs) {
      totalCommentCount += 1;
      final repliesSnapshot = await commentDoc.reference
          .collection('replies')
          .get();
      totalCommentCount += repliesSnapshot.size;
    }

    return totalCommentCount;
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final previousLiked = isLiked;
    final previousCount = likeCount;

    setState(() {
      isLiked = !isLiked;
      likeCount = (likeCount + (isLiked ? 1 : -1)).clamp(0, 1 << 31);
    });

    final tripLikeRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('likes')
        .doc(currentUser.uid);

    try {
      await tripLikeRef.set({'liked': isLiked, 'userId': currentUser.uid});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLiked = previousLiked;
        likeCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update like status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _TripMessage(text: 'Error loading trip details.');
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const _TripMessage(text: 'Trip not found.');
          }

          final trip = snapshot.data!;
          final data = trip.data() as Map<String, dynamic>;
          final isOwner = data['userId'] == currentUser?.uid;
          final imageUrl = data['imagePath'] as String? ?? '';
          final destination =
              data['destination'] as String? ?? 'Unknown destination';
          final startDate = _formatDate(data['startDate'] as String?);
          final endDate = _formatDate(data['endDate'] as String?);
          final budget = (data['budget'] as String?)?.trim().isNotEmpty == true
              ? data['budget'] as String
              : 'No budget specified';
          final tripName =
              (data['tripName'] as String?)?.trim().isNotEmpty == true
              ? data['tripName'] as String
              : 'Unnamed trip';
          final description =
              (data['description'] as String?)?.trim().isNotEmpty == true
              ? data['description'] as String
              : 'No description available';
          final interest =
              (data['interest'] as String?)?.trim().isNotEmpty == true
              ? data['interest'] as String
              : 'No interest specified';
          final tripType = (data['travelType'] as String?) ?? 'Trip';
          final transport = data['transport'] is Map<String, dynamic>
              ? data['transport'] as Map<String, dynamic>
              : null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 330,
                pinned: true,
                stretch: true,
                title: Text(
                  tripName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (result) {
                        if (result == 'Edit') {
                          _navigateToEditTrip(context, widget.tripId);
                        } else if (result == 'Delete') {
                          _confirmDeleteTrip();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'Edit', child: Text('Edit Trip')),
                        PopupMenuItem(
                          value: 'Delete',
                          child: Text('Delete Trip'),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: _HeroImage(
                    imageUrl: imageUrl,
                    title: tripName,
                    subtitle: destination,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _DateRangeCard(startDate: startDate, endDate: endDate),
                    const SizedBox(height: 14),
                    _TripOverviewCard(
                      tripName: tripName,
                      description: description,
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 460;
                        final tiles = [
                          _InfoTile(
                            icon: Icons.place_outlined,
                            label: 'Destination',
                            value: destination,
                          ),
                          _InfoTile(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Budget',
                            value: budget,
                          ),
                          _InfoTile(
                            icon: Icons.favorite_border,
                            label: 'Interest',
                            value: interest,
                          ),
                          _InfoTile(
                            icon: Icons.group_outlined,
                            label: 'Trip Type',
                            value: tripType,
                          ),
                        ];

                        if (compact) {
                          return Column(
                            children: [
                              for (final tile in tiles)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: tile,
                                ),
                            ],
                          );
                        }

                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.35,
                          children: tiles,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _EngagementCard(
                      isLiked: isLiked,
                      likeCount: likeCount,
                      commentCount: commentCount,
                      onLike: _toggleLike,
                      onComments: () => _showCommentsPopup(context),
                    ),
                    if (transport != null) ...[
                      const SizedBox(height: 14),
                      _TransportStatusCard(transport: transport),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Not set';
    try {
      final parsedDate = DateFormat('dd/MM/yyyy').parse(date);
      return DateFormat('MMM d, y').format(parsedDate);
    } catch (_) {
      return date;
    }
  }

  void _navigateToEditTrip(BuildContext context, String tripId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTripScreen(tripId: tripId)),
    );
  }

  void _showCommentsPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CommentsPopup(contentId: widget.tripId, contentType: 'trip'),
          ),
        );
      },
    ).whenComplete(_refreshCommentCount);
  }

  Future<void> _confirmDeleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip'),
        content: const Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTrip();
    }
  }

  Future<void> _deleteTrip() async {
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .delete();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error deleting trip.')));
    }
  }
}

class _TransportStatusCard extends StatelessWidget {
  const _TransportStatusCard({required this.transport});

  final Map<String, dynamic> transport;

  @override
  Widget build(BuildContext context) {
    final status = (transport['status'] ?? 'requested').toString();
    final type = (transport['type'] ?? 'Standard').toString();
    final pickup = (transport['pickup'] ?? 'Not set').toString();
    final dropoff = (transport['dropoff'] ?? 'Not set').toString();
    final driverName = (transport['driverName'] ?? '').toString();
    final fare = (transport['estimatedFare'] as num?)?.toDouble();
    final distanceKm = (transport['distanceKm'] as num?)?.toDouble();
    final durationMinutes = (transport['durationMinutes'] as num?)?.toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.local_taxi_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transport $status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        driverName.isEmpty
                            ? '$type request sent to partner drivers'
                            : 'Driver: $driverName',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TransportRouteLine(label: 'Pickup', value: pickup),
            const SizedBox(height: 8),
            _TransportRouteLine(label: 'Dropoff', value: dropoff),
            if (fare != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    label: Text('R${fare.toStringAsFixed(0)} estimate'),
                  ),
                  if (distanceKm != null)
                    Chip(
                      avatar: const Icon(Icons.route_outlined, size: 18),
                      label: Text('${distanceKm.toStringAsFixed(1)} km'),
                    ),
                  if (durationMinutes != null)
                    Chip(
                      avatar: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text('$durationMinutes min'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransportRouteLine extends StatelessWidget {
  const _TransportRouteLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;

  const _HeroImage({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const _HeroFallback(),
          )
        else
          const _HeroFallback(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x11000000), Color(0xCC000000)],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.landscape_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 72,
      ),
    );
  }
}

class _DateRangeCard extends StatelessWidget {
  final String startDate;
  final String endDate;

  const _DateRangeCard({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _DateChip(label: 'Start', date: startDate),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: _DateChip(label: 'End', date: endDate),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String date;

  const _DateChip({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _TripOverviewCard extends StatelessWidget {
  final String tripName;
  final String description;

  const _TripOverviewCard({required this.tripName, required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tripName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
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

class _EngagementCard extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComments;

  const _EngagementCard({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    final likeColor = isLiked
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(
              avatar: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: likeColor,
                size: 18,
              ),
              label: Text('$likeCount likes'),
              onPressed: onLike,
            ),
            ActionChip(
              avatar: const Icon(Icons.comment_outlined, size: 18),
              label: Text('$commentCount comments'),
              onPressed: onComments,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripMessage extends StatelessWidget {
  final String text;

  const _TripMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
