import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/services/user_notification_service.dart';
import 'package:riendzo/widgets/riendzo_sliver_app_bar.dart';
import 'package:riendzo/views/my_trips/booking/widgets/custom_booking_dropdown.dart';

class EditTripScreen extends StatefulWidget {
  final String tripId;
  const EditTripScreen({super.key, required this.tripId});
  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  static const _interests = [
    'Adventure',
    'Beaches',
    'Culture',
    'Cuisine',
    'Exploration',
    'Festivals',
    'Hiking',
    'History',
    'Relaxation',
    'Safari',
    'Scenery',
    'Sports',
    'Wildlife',
    'Cruises',
    'Mountains',
    'Photography',
    'Roadtrips',
    'Shopping',
    'Spa',
    'Waterfalls',
  ];
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _destination = TextEditingController(),
      _budget = TextEditingController(),
      _capacity = TextEditingController(),
      _interest = TextEditingController(),
      _description = TextEditingController();
  final _format = DateFormat('dd/MM/yyyy');
  Map<String, dynamic>? _trip;
  DateTimeRange? _dates;
  final List<String> _existingImages = [];
  final List<File> _newImages = [];
  bool _saving = false;
  int _currentStep = 0;
  static const _stepNames = ['Trip basics', 'Travellers', 'Review'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _destination,
      _budget,
      _capacity,
      _interest,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final trip =
          (await FirebaseFirestore.instance
                  .collection('trips')
                  .doc(widget.tripId)
                  .get())
              .data();
      if (trip == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      _name.text = trip['tripName']?.toString() ?? '';
      _destination.text = trip['destination']?.toString() ?? '';
      _budget.text = (trip['budget']?.toString() ?? '').replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      _capacity.text = '${trip['maxGroupSize'] ?? 6}';
      _interest.text = trip['interest']?.toString() ?? '';
      _description.text = trip['description']?.toString() ?? '';
      final storedImages = trip['imageUrls'];
      if (storedImages is List) {
        _existingImages.addAll(
          storedImages
              .whereType<String>()
              .map((url) => url.trim())
              .where((url) => url.isNotEmpty),
        );
      }
      final coverImage = trip['imagePath']?.toString().trim() ?? '';
      if (coverImage.isNotEmpty && !_existingImages.contains(coverImage)) {
        _existingImages.insert(0, coverImage);
      }
      try {
        _dates = DateTimeRange(
          start: _format.parseStrict(trip['startDate']?.toString() ?? ''),
          end: _format.parseStrict(trip['endDate']?.toString() ?? ''),
        );
      } catch (_) {}
      if (mounted) setState(() => _trip = trip);
    } catch (_) {
      _notice('Trip details could not be loaded.');
    }
  }

  Future<void> _chooseDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
      initialDateRange: _dates,
    );
    if (picked != null && mounted) setState(() => _dates = picked);
  }

  Future<void> _choosePhotos() async {
    final slots = 4 - _existingImages.length - _newImages.length;
    if (slots <= 0) {
      _notice('You can upload up to 4 trip photos. Remove a photo first.');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (picked.isEmpty || !mounted) return;
    final selected = picked.take(slots).map((image) => File(image.path));
    setState(() => _newImages.addAll(selected));
    if (picked.length > slots) {
      _notice('You can upload up to 4 trip photos.');
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _removeNewPhoto(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final trip = _trip;
    if (user == null || trip == null || _saving) return;
    if (trip['userId']?.toString() != user.uid) {
      _notice('Only the trip host can edit this trip.');
      return;
    }
    final status = trip['status']?.toString().toLowerCase() ?? '';
    if (status == 'completed' || status == 'cancelled') {
      _notice('Completed and cancelled trips cannot be edited.');
      return;
    }
    if (!(_form.currentState?.validate() ?? false) || _dates == null) {
      _notice('Complete all fields and choose trip dates.');
      return;
    }
    final members = (trip['joinedUsers'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final capacity = int.parse(_capacity.text);
    if (capacity < members.length + 1 || capacity > 50) {
      _notice('Group size must be between ${members.length + 1} and 50.');
      return;
    }
    final start = _format.format(_dates!.start),
        end = _format.format(_dates!.end),
        budget = double.parse(_budget.text);
    final impactsMembers =
        members.isNotEmpty &&
        (start != trip['startDate'] ||
            end != trip['endDate'] ||
            CurrencyFormatter.formatRand(budget) !=
                CurrencyFormatter.formatRand(trip['budget']) ||
            capacity != (trip['maxGroupSize'] as num?)?.toInt());
    if (impactsMembers && !await _confirm(members.length)) return;
    setState(() => _saving = true);
    try {
      final uploadedImages = <String>[];
      for (final image in _newImages) {
        final ref = FirebaseStorage.instance.ref().child(
          'trip_images/${DateTime.now().millisecondsSinceEpoch}_${image.path.hashCode}.jpg',
        );
        await ref.putFile(
          image,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'max-age=60',
          ),
        );
        uploadedImages.add(await ref.getDownloadURL());
      }
      final imageUrls = [..._existingImages, ...uploadedImages];
      final imageUrl = imageUrls.isEmpty ? '' : imageUrls.first;
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .update({
            'tripName': _name.text.trim(),
            'destination': _destination.text.trim(),
            'startDate': start,
            'endDate': end,
            'date':
                '${DateFormat('d MMM').format(_dates!.start)} - ${DateFormat('d MMM').format(_dates!.end)}',
            'budget': CurrencyFormatter.formatRand(budget),
            'maxGroupSize': capacity,
            'interest': _interest.text.trim(),
            'description': _description.text.trim(),
            'imagePath': imageUrl,
            'imageUrls': imageUrls,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (impactsMembers)
        for (final member in members) {
          final id = member['userId']?.toString() ?? '';
          if (id.isNotEmpty && id != user.uid)
            await UserNotificationService.create(
              userId: id,
              type: 'trip_updated',
              title: 'Trip details updated',
              message:
                  '${_name.text.trim()} has updated details. Review the trip before it starts.',
              tripId: widget.tripId,
              tripName: _name.text.trim(),
              actorUserId: user.uid,
            );
        }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _notice('Changes could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notify confirmed travelers?'),
        content: Text(
          'These changes affect ${count} confirmed traveler${count == 1 ? '' : 's'}. They will be notified to review the trip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save and notify'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Form(
        key: _form,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            RiendzoSliverAppBar(
              title: 'Edit trip',
              subtitle:
                  'Step ${_currentStep + 1} of 3 · ${_stepNames[_currentStep]}',
              automaticallyImplyLeading: true,
            ),
          ],
          body: Column(
            children: [
              _StepProgress(currentStep: _currentStep, labels: _stepNames),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: ListView(
                    key: ValueKey(_currentStep),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: switch (_currentStep) {
                      0 => _basicsStep(context),
                      1 => _travellersStep(context),
                      _ => _reviewStep(context),
                    },
                  ),
                ),
              ),
              _PlannerFooter(
                currentStep: _currentStep,
                loading: _saving,
                onBack: _currentStep == 0
                    ? null
                    : () => setState(() => _currentStep--),
                onContinue: _saving
                    ? null
                    : _currentStep == 2
                    ? _save
                    : _continue,
                finalLabel: 'Save changes',
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _basicsStep(BuildContext context) => [
    _StepIntro(
      icon: Icons.explore_outlined,
      title: 'Where are you going?',
      subtitle: 'Update the essentials for your trip.',
    ),
    _input(_destination, 'Destination', Icons.place_outlined),
    _DateInput(dates: _dates, onTap: _chooseDates),
    _input(_name, 'Trip name', Icons.trip_origin_outlined, maxLength: 80),
    _input(
      _budget,
      'Daily budget per person',
      Icons.payments_outlined,
      prefix: 'R ',
      type: const TextInputType.numberWithOptions(decimal: true),
    ),
    CustomBookingDropdown(
      interests: _interests,
      selectedInterest: _interests.contains(_interest.text)
          ? _interest.text
          : null,
      onChanged: (value) => setState(() => _interest.text = value ?? ''),
      icon: Icons.favorite_outline,
      hintText: 'Choose your interest',
    ),
  ];

  List<Widget> _travellersStep(BuildContext context) {
    final members = (_trip?['joinedUsers'] as List? ?? [])
        .whereType<Map>()
        .length;
    final theme = Theme.of(context);
    return [
      _StepIntro(
        icon: Icons.groups_2_outlined,
        title: 'Who is coming?',
        subtitle: 'Manage group size and the trip details travelers see.',
      ),
      _input(
        _capacity,
        'Maximum group size',
        Icons.group_outlined,
        type: TextInputType.number,
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          'At least ${members + 1} people are required to include everyone already confirmed.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      _input(
        _description,
        'Description',
        Icons.subject_outlined,
        lines: 5,
        maxLength: 1000,
      ),
      const SizedBox(height: 8),
      Text('Trip photos', style: theme.textTheme.titleLarge),
      const SizedBox(height: 10),
      Text(
        'Choose up to 4 photos. The first photo is used as the cover.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < _existingImages.length; i++)
            _PhotoTile(
              image: CachedNetworkImageProvider(_existingImages[i]),
              label: i == 0 ? 'Cover photo' : null,
              onRemove: () => _removeExistingPhoto(i),
            ),
          for (var i = 0; i < _newImages.length; i++)
            _PhotoTile(
              image: FileImage(_newImages[i]),
              label: _existingImages.isEmpty && i == 0 ? 'Cover photo' : null,
              onRemove: () => _removeNewPhoto(i),
            ),
          if (_existingImages.length + _newImages.length < 4)
            _AddPhotoTile(onTap: _choosePhotos),
        ],
      ),
    ];
  }

  List<Widget> _reviewStep(BuildContext context) => [
    const _StepIntro(
      icon: Icons.fact_check_outlined,
      title: 'Review your changes',
      subtitle: 'Check the trip details before saving.',
    ),
    _ReviewCard(
      title: 'Trip basics',
      icon: Icons.place_outlined,
      onEdit: () => setState(() => _currentStep = 0),
      rows: [
        ('Destination', _destination.text),
        (
          'Dates',
          _dates == null
              ? 'Choose dates'
              : '${DateFormat('d MMM yyyy').format(_dates!.start)} - ${DateFormat('d MMM yyyy').format(_dates!.end)}',
        ),
        ('Trip name', _name.text),
        ('Interest', _interest.text.isEmpty ? 'Not selected' : _interest.text),
        ('Daily budget', 'R${_budget.text}'),
      ],
    ),
    const SizedBox(height: 12),
    _ReviewCard(
      title: 'Travellers and details',
      icon: Icons.groups_2_outlined,
      onEdit: () => setState(() => _currentStep = 1),
      rows: [
        ('Group size', _capacity.text),
        (
          'Confirmed travelers',
          '${(_trip?['joinedUsers'] as List? ?? []).whereType<Map>().length}',
        ),
        (
          'Cover photo',
          '${_existingImages.length + _newImages.length} selected',
        ),
        (
          'Description',
          _description.text.isEmpty ? 'No description' : _description.text,
        ),
      ],
    ),
  ];

  void _continue() {
    if (_currentStep == 0) {
      if (!(_form.currentState?.validate() ?? false) || _dates == null) {
        _notice('Complete the trip basics and choose trip dates.');
        return;
      }
    } else if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _currentStep++);
  }

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? prefix,
    int lines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: lines,
      maxLength: maxLength,
      style: const TextStyle(color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefix,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return '${label} is required.';
        if (label == 'Trip budget' &&
            (double.tryParse(text) == null || double.parse(text) < 0))
          return 'Enter a valid Rand amount.';
        if (label == 'Maximum group size' && int.tryParse(text) == null)
          return 'Enter a whole number.';
        return null;
      },
    ),
  );
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep, required this.labels});
  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Row(
          children: List.generate(labels.length * 2 - 1, (index) {
            if (index.isOdd) {
              return Expanded(
                child: Container(
                  height: 3,
                  color: index ~/ 2 < currentStep ? color : Colors.black12,
                ),
              );
            }
            final step = index ~/ 2;
            final active = step <= currentStep;
            return Semantics(
              label: labels[step],
              child: CircleAvatar(
                radius: 14,
                backgroundColor: active ? color : Colors.black12,
                child: Text(
                  '${step + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.rows,
    required this.onEdit,
  });
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const Divider(),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.image, required this.onRemove, this.label});

  final ImageProvider image;
  final VoidCallback onRemove;
  final String? label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    height: 112,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image(image: image, fit: BoxFit.cover),
        ),
        if (label != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.black54,
              child: Text(
                label!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Remove photo',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              onPressed: onRemove,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    height: 112,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 30),
            SizedBox(height: 6),
            Text('Add photos'),
          ],
        ),
      ),
    ),
  );
}

class _PlannerFooter extends StatelessWidget {
  const _PlannerFooter({
    required this.currentStep,
    required this.loading,
    required this.onBack,
    required this.onContinue,
    required this.finalLabel,
  });
  final int currentStep;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String finalLabel;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 10,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(minimumSize: const Size(92, 54)),
              child: const Text('Back'),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(currentStep == 2 ? Icons.check : Icons.arrow_forward),
              label: Text(
                loading
                    ? 'Saving changes…'
                    : currentStep == 2
                    ? finalLabel
                    : 'Continue',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DateInput extends StatelessWidget {
  final DateTimeRange? dates;
  final VoidCallback onTap;
  const _DateInput({required this.dates, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final text = dates == null
        ? 'Choose dates'
        : '${DateFormat('d MMM yyyy').format(dates!.start)} - ${DateFormat('d MMM yyyy').format(dates!.end)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Trip dates',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(text, style: const TextStyle(color: Color(0xFF0F172A))),
        ),
      ),
    );
  }
}
