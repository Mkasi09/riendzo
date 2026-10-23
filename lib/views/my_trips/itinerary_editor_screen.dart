import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/user_notification_service.dart';

class ItineraryEditorScreen extends StatefulWidget {
  final String tripId;
  final dynamic initialItinerary;

  const ItineraryEditorScreen({
    super.key,
    required this.tripId,
    this.initialItinerary,
  });

  @override
  State<ItineraryEditorScreen> createState() => _ItineraryEditorScreenState();
}

class _ItineraryEditorScreenState extends State<ItineraryEditorScreen> {
  final List<Map<String, dynamic>> _stops = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItinerary;
    if (initial is List) {
      _stops.addAll(
        initial.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip itinerary'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editStop(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add activity'),
      ),
      body: _stops.isEmpty
          ? const _ItineraryEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _stops.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final stop = _stops.removeAt(oldIndex);
                  _stops.insert(newIndex, stop);
                });
              },
              itemBuilder: (context, index) {
                final stop = _stops[index];
                return Card(
                  key: ValueKey('${stop['title']}-${stop['time']}-$index'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(stop['title']?.toString() ?? 'Activity'),
                    subtitle: Text(
                      [
                        stop['time']?.toString() ?? '',
                        stop['location']?.toString() ?? '',
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editStop(index: index);
                        if (value == 'delete') {
                          setState(() => _stops.removeAt(index));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _editStop(index: index),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editStop({int? index}) async {
    final existing = index == null ? null : _stops[index];
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final timeController = TextEditingController(
      text: existing?['time']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: existing?['location']?.toString() ?? '',
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Add activity' : 'Edit activity'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Activity',
                  prefixIcon: Icon(Icons.local_activity_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Day and time',
                  hintText: 'Day 1 · 09:00',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Meeting point',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(dialogContext, {
                'title': title,
                'time': timeController.text.trim(),
                'location': locationController.text.trim(),
              });
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
    titleController.dispose();
    timeController.dispose();
    locationController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _stops.add(result);
      } else {
        _stops[index] = result;
      }
    });
  }

  Future<void> _save() async {
    final tripRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId);
    final tripSnapshot = await tripRef.get();
    final trip = tripSnapshot.data();
    if (trip == null) {
      _showError('This trip is no longer available.');
      return;
    }
    final status = trip['status']?.toString().toLowerCase() ?? '';
    if (status == 'cancelled' || status == 'completed') {
      _showError('Completed and cancelled trip itineraries cannot be edited.');
      return;
    }
    final days = _stops.map(_dayNumber).toList();
    if (days.any((day) => day == null)) {
      _showError(
        'Give every activity a day number, for example Day 1 · 09:00.',
      );
      return;
    }
    final dayNumbers = days.cast<int>();
    if (dayNumbers.toSet().length != dayNumbers.length) {
      _showError('Use one itinerary entry per day. Day numbers cannot repeat.');
      return;
    }
    final tripDays = _tripDurationDays(trip);
    if (tripDays != null &&
        dayNumbers.any((day) => day < 1 || day > tripDays)) {
      _showError('Itinerary days must be between Day 1 and Day $tripDays.');
      return;
    }
    setState(() => _saving = true);
    try {
      await tripRef.update({
        'itinerary': _stops,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      for (final member
          in (trip['joinedUsers'] as List? ?? []).whereType<Map>()) {
        final memberId = member['userId']?.toString() ?? '';
        if (memberId.isNotEmpty && memberId != currentUserId) {
          await UserNotificationService.create(
            userId: memberId,
            type: 'trip_updated',
            title: 'Itinerary updated',
            message:
                'The itinerary for ${trip['tripName'] ?? 'your trip'} was updated.',
            tripId: widget.tripId,
            tripName: trip['tripName']?.toString(),
            actorUserId: currentUserId,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the itinerary.')),
      );
    }
  }

  int? _dayNumber(Map<String, dynamic> stop) {
    final match = RegExp(
      r'\bday\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(stop['time']?.toString() ?? '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int? _tripDurationDays(Map<String, dynamic> trip) {
    try {
      final start = DateFormat(
        'dd/MM/yyyy',
      ).parseStrict(trip['startDate'].toString());
      final end = DateFormat(
        'dd/MM/yyyy',
      ).parseStrict(trip['endDate'].toString());
      return end.difference(start).inDays + 1;
    } catch (_) {
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ItineraryEmptyState extends StatelessWidget {
  const _ItineraryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Build the trip plan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add activities, times, and meeting points. You can drag them into the right order.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
