import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/services/user_notification_service.dart';
import 'package:riendzo/views/profile/user_profile_screen.dart';

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
  int selectedImageIndex = 0;

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

  Future<void> _requestToJoinTrip({
    required String tripName,
    required String ownerId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('joinRequests')
          .doc(currentUser.uid)
          .set({
            'userId': currentUser.uid,
            'displayName':
                currentUser.displayName ??
                currentUser.email ??
                'Riendzo traveler',
            'email': currentUser.email ?? '',
            'photoURL': currentUser.photoURL ?? '',
            'ownerId': ownerId,
            'tripId': widget.tripId,
            'tripName': tripName,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await UserNotificationService.create(
        userId: ownerId,
        type: 'join_request',
        title: 'New trip join request',
        message:
            '${currentUser.displayName ?? currentUser.email ?? 'Someone'} wants to join $tripName.',
        tripId: widget.tripId,
        actorUserId: currentUser.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent to the trip owner.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send join request.')),
      );
    }
  }

  Future<void> _approveJoinRequest(DocumentSnapshot request) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final tripRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId);
    final requestRef = request.reference;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final tripSnapshot = await transaction.get(tripRef);
        final requestSnapshot = await transaction.get(requestRef);
        if (!tripSnapshot.exists || !requestSnapshot.exists) return;

        final tripData = tripSnapshot.data() as Map<String, dynamic>;
        final requestData = requestSnapshot.data() as Map<String, dynamic>;
        final userId = requestData['userId']?.toString() ?? request.id;
        final participantIds = _participantIds(tripData);
        final currentGroupSize = _currentGroupSize(tripData);
        final maxGroupSize = _maxGroupSize(tripData, currentGroupSize);

        if (!participantIds.contains(userId) &&
            currentGroupSize >= maxGroupSize) {
          throw const _TripFullException();
        }

        final joinedUser = {
          'userId': userId,
          'displayName':
              requestData['displayName']?.toString() ?? 'Riendzo traveler',
          'email': requestData['email']?.toString() ?? '',
          'photoURL': requestData['photoURL']?.toString() ?? '',
          'joinedAt': Timestamp.now(),
        };

        transaction.update(tripRef, {
          'joinedUsers': FieldValue.arrayUnion([joinedUser]),
        });
        transaction.update(requestRef, {
          'status': 'approved',
          'reviewedBy': currentUser.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final requestData = request.data() as Map<String, dynamic>;
      await UserNotificationService.create(
        userId: requestData['userId']?.toString() ?? request.id,
        type: 'join_approved',
        title: 'Trip request approved',
        message: 'You were approved to join this trip.',
        tripId: widget.tripId,
        actorUserId: currentUser.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Traveler approved.')));
    } on _TripFullException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trip is already full.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not approve this request.')),
      );
    }
  }

  Future<void> _declineJoinRequest(DocumentSnapshot request) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await request.reference.update({
        'status': 'declined',
        'reviewedBy': currentUser.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final requestData = request.data() as Map<String, dynamic>;
      await UserNotificationService.create(
        userId: requestData['userId']?.toString() ?? request.id,
        type: 'join_declined',
        title: 'Trip request declined',
        message: 'Your request to join this trip was declined.',
        tripId: widget.tripId,
        actorUserId: currentUser.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request declined.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not decline this request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _TripMessage(text: 'Trip details are unavailable.');
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _TripDetailSkeleton();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const _TripMessage(text: 'Trip not found.');
          }

          final trip = snapshot.data!;
          final data = trip.data() as Map<String, dynamic>;
          final isOwner = data['userId'] == currentUser?.uid;
          final images = _tripImages(data);
          final tripName = _nonEmpty(data['tripName'], 'Unnamed trip');
          final destination = _nonEmpty(
            data['destination'],
            'Unknown destination',
          );
          final startDate = _formatDate(data['startDate'] as String?);
          final endDate = _formatDate(data['endDate'] as String?);
          final rawStartDate = _nonEmpty(data['startDate'], 'Not set');
          final rawEndDate = _nonEmpty(data['endDate'], 'Not set');
          final budget = CurrencyFormatter.formatRand(data['budget']);
          final description = _nonEmpty(
            data['description'],
            'No description has been added yet.',
          );
          final interest = _nonEmpty(data['interest'], 'Travel');
          final tripType = _nonEmpty(data['travelType'], 'Trip');
          final status = _nonEmpty(data['status'], 'planned');
          final currentGroupSize = _currentGroupSize(data);
          final maxGroupSize = _maxGroupSize(data, currentGroupSize);
          final participantIds = _participantIds(data);
          final currentUserId = currentUser?.uid;
          final currentUserIsParticipant =
              currentUserId != null && participantIds.contains(currentUserId);
          final currentUserInviteStatus = currentUserId == null
              ? ''
              : _inviteStatusFor(data, currentUserId);
          final isFull = currentGroupSize >= maxGroupSize;
          final transport = data['transport'] is Map<String, dynamic>
              ? data['transport'] as Map<String, dynamic>
              : null;

          if (selectedImageIndex >= images.length && images.isNotEmpty) {
            selectedImageIndex = images.length - 1;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ImmersiveTripHeader(
                  images: images,
                  selectedIndex: selectedImageIndex,
                  tripName: tripName,
                  destination: destination,
                  status: status,
                  isOwner: isOwner,
                  onBack: () => Navigator.pop(context),
                  onEdit: () => _navigateToEditTrip(context, widget.tripId),
                  onDelete: _confirmDeleteTrip,
                  onSelectPhoto: (index) =>
                      setState(() => selectedImageIndex = index),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _EngagementPanel(
                      isLiked: isLiked,
                      likeCount: likeCount,
                      commentCount: commentCount,
                      onLike: _toggleLike,
                      onComments: () => _showCommentsPopup(context),
                    ),
                    const SizedBox(height: 16),
                    _TripStoryCard(
                      title: tripName,
                      destination: destination,
                      description: description,
                    ),
                    const SizedBox(height: 16),
                    _DateJourneyCard(
                      startDate: startDate,
                      endDate: endDate,
                      rawStartDate: rawStartDate,
                      rawEndDate: rawEndDate,
                    ),
                    const SizedBox(height: 16),
                    _TripFactsBox(
                      items: [
                        _HighlightData(
                          icon: Icons.payments_outlined,
                          label: 'Price',
                          value: budget,
                        ),
                        _HighlightData(
                          icon: Icons.group_outlined,
                          label: 'Group size',
                          value: '$currentGroupSize/$maxGroupSize going',
                        ),
                        _HighlightData(
                          icon: Icons.explore_outlined,
                          label: 'Travel type',
                          value: tripType,
                        ),
                        _HighlightData(
                          icon: Icons.interests_outlined,
                          label: 'Interest',
                          value: interest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TripPeoplePanel(tripData: data),
                    if (currentUser != null) ...[
                      const SizedBox(height: 16),
                      if (isOwner)
                        _OwnerJoinRequestsPanel(
                          tripId: widget.tripId,
                          currentGroupSize: currentGroupSize,
                          maxGroupSize: maxGroupSize,
                          onApprove: _approveJoinRequest,
                          onDecline: _declineJoinRequest,
                        )
                      else
                        _JoinTripRequestPanel(
                          tripId: widget.tripId,
                          isFull: isFull,
                          isParticipant: currentUserIsParticipant,
                          inviteStatus: currentUserInviteStatus,
                          onRequestJoin: () => _requestToJoinTrip(
                            tripName: tripName,
                            ownerId: data['userId']?.toString() ?? '',
                          ),
                        ),
                    ],
                    if (transport != null) ...[
                      const SizedBox(height: 16),
                      _TransportCard(transport: transport),
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

  static String _nonEmpty(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static Set<String> _participantIds(Map<String, dynamic> data) {
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

  static int _currentGroupSize(Map<String, dynamic> data) {
    final participantIds = _participantIds(data);
    return participantIds.isEmpty ? 1 : participantIds.length;
  }

  static int _maxGroupSize(Map<String, dynamic> data, int currentGroupSize) {
    final rawMax = data['maxGroupSize'];
    final maxGroupSize = rawMax is num
        ? rawMax.toInt()
        : int.tryParse(rawMax?.toString() ?? '');
    if (maxGroupSize == null || maxGroupSize < currentGroupSize) {
      return currentGroupSize < 6 ? 6 : currentGroupSize;
    }
    return maxGroupSize;
  }

  static String _inviteStatusFor(Map<String, dynamic> data, String userId) {
    final inviteStatuses = data['inviteStatuses'];
    if (inviteStatuses is Map) {
      final status = inviteStatuses[userId]?.toString() ?? '';
      if (status.isNotEmpty) return status;
    }

    final invitedUsers = data['invitedUsers'] is List
        ? data['invitedUsers'] as List
        : data['invitedFriends'] is List
        ? data['invitedFriends'] as List
        : const [];
    for (final invitedUser in invitedUsers) {
      if (invitedUser is! Map) continue;
      if (invitedUser['id']?.toString() == userId) {
        return invitedUser['status']?.toString() ?? 'pending';
      }
    }

    return '';
  }

  static List<String> _tripImages(Map<String, dynamic> data) {
    final imageUrls = data['imageUrls'];
    if (imageUrls is List) {
      final urls = imageUrls
          .map((item) => item.toString().trim())
          .where((url) => url.isNotEmpty)
          .take(4)
          .toList();
      if (urls.isNotEmpty) return urls;
    }

    final imagePath = data['imagePath']?.toString().trim() ?? '';
    return imagePath.isEmpty ? const [] : [imagePath];
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
          heightFactor: 0.86,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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

class _TripFullException implements Exception {
  const _TripFullException();
}

class _ImmersiveTripHeader extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;
  final String tripName;
  final String destination;
  final String status;
  final bool isOwner;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onSelectPhoto;

  const _ImmersiveTripHeader({
    required this.images,
    required this.selectedIndex,
    required this.tripName,
    required this.destination,
    required this.status,
    required this.isOwner,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onSelectPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 560,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeaderPhotoMosaic(images: images, selectedIndex: selectedIndex),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x10000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 122,
            child: _HeaderTextBlock(
              images: images,
              selectedIndex: selectedIndex,
              tripName: tripName,
              destination: destination,
              status: status,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _PhotoPreviewStrip(
              images: images,
              selectedIndex: selectedIndex,
              onSelectPhoto: onSelectPhoto,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                    const Spacer(),
                    if (isOwner)
                      _GlassMenuButton(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPhotoMosaic extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;

  const _HeaderPhotoMosaic({required this.images, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const _HeroFallback();

    final index = selectedIndex.clamp(0, images.length - 1).toInt();
    return _MosaicImage(url: images[index]);
  }
}

class _HeaderTextBlock extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;
  final String tripName;
  final String destination;
  final String status;

  const _HeaderTextBlock({
    required this.images,
    required this.selectedIndex,
    required this.tripName,
    required this.destination,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroBadge(text: status, icon: Icons.auto_awesome_outlined),
            _HeroBadge(
              text: images.isEmpty
                  ? '0 photos'
                  : '${selectedIndex + 1}/${images.length} photos',
              icon: Icons.photo_library_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          tripName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 16)],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.place_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoPreviewStrip extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;
  final ValueChanged<int> onSelectPhoto;

  const _PhotoPreviewStrip({
    required this.images,
    required this.selectedIndex,
    required this.onSelectPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final slots = images.isEmpty ? <String>[] : images.take(4).toList();

    return SizedBox(
      height: 82,
      child: Row(
        children: [
          for (var index = 0; index < 4; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: index == selectedIndex
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.white.withValues(alpha: 0.38),
                      width: index == selectedIndex ? 2 : 1,
                    ),
                  ),
                  child: index < slots.length
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _MosaicImage(
                              url: slots[index],
                              onTap: () => onSelectPhoto(index),
                            ),
                            if (index == 3 && images.length > 4)
                              ColoredBox(
                                color: Colors.black.withValues(alpha: 0.48),
                                child: Center(
                                  child: Text(
                                    '+${images.length - 4}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : const _EmptyPhotoSlot(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14)),
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _MosaicImage extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;

  const _MosaicImage({required this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => const _HeroFallback(),
          errorWidget: (context, url, error) => const _HeroFallback(),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlassMenuButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlassMenuButton({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(999),
      child: PopupMenuButton<String>(
        tooltip: 'Trip options',
        color: Colors.white,
        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (value) {
          if (value == 'Edit') onEdit();
          if (value == 'Delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'Edit', child: Text('Edit Trip')),
          PopupMenuItem(value: 'Delete', child: Text('Delete Trip')),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _HeroBadge({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementPanel extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComments;

  const _EngagementPanel({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: '$likeCount likes',
            active: isLiked,
            onTap: onLike,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: '$commentCount comments',
            active: false,
            onTap: onComments,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFFE11D48)
        : Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripStoryCard extends StatelessWidget {
  final String title;
  final String destination;
  final String description;

  const _TripStoryCard({
    required this.title,
    required this.destination,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRIP STORY',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Row(
              children: [
                Icon(
                  Icons.near_me_outlined,
                  size: 17,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateJourneyCard extends StatelessWidget {
  final String startDate;
  final String endDate;
  final String rawStartDate;
  final String rawEndDate;

  const _DateJourneyCard({
    required this.startDate,
    required this.endDate,
    required this.rawStartDate,
    required this.rawEndDate,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Journey dates',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DateStop(
                  label: 'Start',
                  date: startDate,
                  rawDate: rawStartDate,
                  icon: Icons.flag_outlined,
                ),
              ),
              Container(
                width: 42,
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _DateStop(
                  label: 'End',
                  date: endDate,
                  rawDate: rawEndDate,
                  icon: Icons.emoji_events_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateStop extends StatelessWidget {
  final String label;
  final String date;
  final String rawDate;
  final IconData icon;

  const _DateStop({
    required this.label,
    required this.date,
    required this.rawDate,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 3),
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          rawDate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TripFactsBox extends StatelessWidget {
  final List<_HighlightData> items;

  const _TripFactsBox({required this.items});

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Trip details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _FactRow(item: items[index]),
                  if (index != items.length - 1)
                    const Divider(color: Color(0xFFE2E8F0)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final _HighlightData item;

  const _FactRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.icon,
              color: Theme.of(context).colorScheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              item.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightData {
  final IconData icon;
  final String label;
  final String value;

  const _HighlightData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _TripPeoplePanel extends StatelessWidget {
  final Map<String, dynamic> tripData;

  const _TripPeoplePanel({required this.tripData});

  @override
  Widget build(BuildContext context) {
    final people = _peopleFromTrip(tripData);

    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _JoinIcon(icon: Icons.diversity_3_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Trip people & invites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${people.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final person in people) ...[
            _TripPersonRow(person: person),
            if (person != people.last) const Divider(color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }

  List<_TripPerson> _peopleFromTrip(Map<String, dynamic> data) {
    final people = <_TripPerson>[];
    final seenUserIds = <String>{};

    void addPerson(_TripPerson person) {
      if (person.userId.isNotEmpty && seenUserIds.contains(person.userId)) {
        return;
      }
      if (person.userId.isNotEmpty) seenUserIds.add(person.userId);
      people.add(person);
    }

    final ownerId = data['userId']?.toString() ?? '';
    addPerson(
      _TripPerson(
        userId: ownerId,
        displayName: 'Trip owner',
        email: '',
        photoURL: '',
        role: 'Owner',
        loadProfile: true,
      ),
    );

    final joinedUsers = data['joinedUsers'];
    if (joinedUsers is List) {
      for (final joinedUser in joinedUsers) {
        if (joinedUser is! Map) continue;
        addPerson(
          _TripPerson(
            userId:
                (joinedUser['userId'] ?? joinedUser['id'])?.toString() ?? '',
            displayName:
                joinedUser['displayName']?.toString() ?? 'Joined traveler',
            email: joinedUser['email']?.toString() ?? '',
            photoURL: joinedUser['photoURL']?.toString() ?? '',
            role: 'Joined',
          ),
        );
      }
    }

    final inviteStatuses = data['inviteStatuses'] is Map
        ? Map<String, dynamic>.from(data['inviteStatuses'] as Map)
        : <String, dynamic>{};
    final invitedUsers = data['invitedUsers'] is List
        ? data['invitedUsers'] as List
        : data['invitedFriends'] is List
        ? data['invitedFriends'] as List
        : const [];
    for (final friend in invitedUsers) {
      if (friend is! Map) continue;
      final userId = friend['id']?.toString() ?? '';
      if (userId.isNotEmpty && seenUserIds.contains(userId)) continue;
      final status =
          inviteStatuses[userId]?.toString() ??
          friend['status']?.toString() ??
          'pending';
      if (status == 'declined') continue;
      addPerson(
        _TripPerson(
          userId: userId,
          displayName: friend['name']?.toString() ?? 'Invited traveler',
          email: friend['email']?.toString() ?? '',
          photoURL: friend['profilePicture']?.toString() ?? '',
          role: status == 'accepted' ? 'Joined' : 'Pending invite',
        ),
      );
    }

    return people;
  }
}

class _TripPersonRow extends StatelessWidget {
  final _TripPerson person;

  const _TripPersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    if (person.loadProfile && person.userId.isNotEmpty) {
      return FutureBuilder<_TripPerson>(
        future: _loadUserProfile(person),
        builder: (context, snapshot) {
          return _TripPersonTile(person: snapshot.data ?? person);
        },
      );
    }

    return _TripPersonTile(person: person);
  }

  Future<_TripPerson> _loadUserProfile(_TripPerson fallback) async {
    final snapshot = await rtdb.FirebaseDatabase.instance
        .ref('users/${fallback.userId}')
        .get();
    if (!snapshot.exists) return fallback;

    return _TripPerson(
      userId: fallback.userId,
      displayName:
          snapshot.child('name').value?.toString() ?? fallback.displayName,
      email: snapshot.child('email').value?.toString() ?? fallback.email,
      photoURL:
          snapshot.child('profilePicture').value?.toString() ??
          fallback.photoURL,
      role: fallback.role,
    );
  }
}

class _TripPersonTile extends StatelessWidget {
  final _TripPerson person;

  const _TripPersonTile({required this.person});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: person.userId.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: person.userId),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: person.photoURL.isNotEmpty
                  ? CachedNetworkImageProvider(person.photoURL)
                  : null,
              child: person.photoURL.isEmpty
                  ? const Icon(Icons.person_outline_rounded)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (person.email.isNotEmpty)
                    Text(
                      person.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(person.role),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripPerson {
  final String userId;
  final String displayName;
  final String email;
  final String photoURL;
  final String role;
  final bool loadProfile;

  const _TripPerson({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.role,
    this.loadProfile = false,
  });
}

class _JoinTripRequestPanel extends StatelessWidget {
  final String tripId;
  final bool isFull;
  final bool isParticipant;
  final String inviteStatus;
  final Future<void> Function() onRequestJoin;

  const _JoinTripRequestPanel({
    required this.tripId,
    required this.isFull,
    required this.isParticipant,
    required this.inviteStatus,
    required this.onRequestJoin,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    if (isParticipant) {
      return const _JoinStatusPanel(
        icon: Icons.verified_user_outlined,
        title: "You're on this trip",
        message: 'You already have a place in this group.',
      );
    }

    if (inviteStatus == 'pending') {
      return const _JoinStatusPanel(
        icon: Icons.mail_outline_rounded,
        title: 'Invite waiting',
        message: 'Open Notifications to accept or decline this trip invite.',
      );
    }

    if (isFull) {
      return const _JoinStatusPanel(
        icon: Icons.lock_outline_rounded,
        title: 'Trip is full',
        message: 'There are no open places left on this trip.',
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('joinRequests')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final status = data?['status']?.toString() ?? '';

        if (status == 'pending') {
          return const _JoinStatusPanel(
            icon: Icons.hourglass_top_rounded,
            title: 'Request pending',
            message: 'The trip owner will approve or decline your request.',
          );
        }

        if (status == 'approved') {
          return const _JoinStatusPanel(
            icon: Icons.check_circle_outline_rounded,
            title: "You're going",
            message: 'The trip owner approved your request.',
          );
        }

        final declined = status == 'declined';
        return _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _JoinIcon(
                    icon: declined
                        ? Icons.refresh_rounded
                        : Icons.person_add_alt_1_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      declined ? 'Request again' : 'Join this trip',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                declined
                    ? 'Your previous request was declined, but you can send a new request.'
                    : 'Ask the owner for a place before the group becomes full.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRequestJoin,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(declined ? 'Request again' : 'Request to join'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerJoinRequestsPanel extends StatelessWidget {
  final String tripId;
  final int currentGroupSize;
  final int maxGroupSize;
  final Future<void> Function(DocumentSnapshot request) onApprove;
  final Future<void> Function(DocumentSnapshot request) onDecline;

  const _OwnerJoinRequestsPanel({
    required this.tripId,
    required this.currentGroupSize,
    required this.maxGroupSize,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final openSeats = (maxGroupSize - currentGroupSize).clamp(0, maxGroupSize);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('joinRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs ?? [];

        return _SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _JoinIcon(icon: Icons.group_add_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Join requests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$openSeats open',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                Text(
                  'Pending requests from other travelers will appear here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final request in requests) ...[
                  _JoinRequestRow(
                    request: request,
                    canApprove: openSeats > 0,
                    onApprove: () => onApprove(request),
                    onDecline: () => onDecline(request),
                  ),
                  if (request != requests.last)
                    const Divider(color: Color(0xFFE2E8F0)),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _JoinRequestRow extends StatelessWidget {
  final DocumentSnapshot request;
  final bool canApprove;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _JoinRequestRow({
    required this.request,
    required this.canApprove,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final data = request.data() as Map<String, dynamic>;
    final userId = data['userId']?.toString() ?? request.id;
    final name = data['displayName']?.toString() ?? 'Riendzo traveler';
    final email = data['email']?.toString() ?? '';
    final photoURL = data['photoURL']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: photoURL.isNotEmpty
                    ? CachedNetworkImageProvider(photoURL)
                    : null,
                child: photoURL.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(userId: userId),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canApprove ? onApprove : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onDecline,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Decline request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinStatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _JoinStatusPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Row(
        children: [
          _JoinIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinIcon extends StatelessWidget {
  final IconData icon;

  const _JoinIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _TransportCard extends StatelessWidget {
  final Map<String, dynamic> transport;

  const _TransportCard({required this.transport});

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

    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_taxi_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transport $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      driverName.isEmpty
                          ? '$type request sent to partner drivers'
                          : 'Driver: $driverName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RouteLine(label: 'Pickup', value: pickup, active: true),
          _RouteLine(label: 'Dropoff', value: dropoff, active: false),
          if (fare != null ||
              distanceKm != null ||
              durationMinutes != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (fare != null)
                  _MiniChip(
                    icon: Icons.payments_outlined,
                    text: 'R${fare.toStringAsFixed(0)} estimate',
                  ),
                if (distanceKm != null)
                  _MiniChip(
                    icon: Icons.route_outlined,
                    text: '${distanceKm.toStringAsFixed(1)} km',
                  ),
                if (durationMinutes != null)
                  _MiniChip(
                    icon: Icons.schedule_outlined,
                    text: '$durationMinutes min',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _RouteLine({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 1.5, height: 34, color: const Color(0xFFE2E8F0)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

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
        child: Icon(
          Icons.landscape_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 78,
        ),
      ),
    );
  }
}

class _TripDetailSkeleton extends StatelessWidget {
  const _TripDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 560,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _HeroFallback(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x44020617),
                        Color(0x11020617),
                        Color(0xCC020617),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _SurfacePanel(
                child: SizedBox(
                  height: 86,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TripMessage extends StatelessWidget {
  final String text;

  const _TripMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
