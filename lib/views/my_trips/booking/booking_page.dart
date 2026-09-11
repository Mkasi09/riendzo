import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'package:riendzo/views/my_trips/booking/widgets/custom_booking_dropdown.dart';
import 'package:riendzo/views/my_trips/booking/widgets/custom_text_field.dart';
import 'package:riendzo/views/my_trips/booking/widgets/transport_request_section.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/services/transport_fare_calculator.dart';
import 'package:riendzo/services/google_api_config.dart';
import 'package:riendzo/services/transport_route_estimator.dart';
import 'package:riendzo/services/user_notification_service.dart';
import 'package:riendzo/widgets/riendzo_sliver_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../../widgets/Shared Widgets/friendsSelection.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final TextEditingController _budgetController = TextEditingController();
  String? _selectedInterest;
  final TextEditingController _tripNameController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _maxGroupSizeController = TextEditingController(
    text: '6',
  );
  final TextEditingController _datesController = TextEditingController();
  final TextEditingController _transportPickupController =
      TextEditingController();
  final TextEditingController _transportPickupTimeController =
      TextEditingController();
  final TextEditingController _transportDropoffController =
      TextEditingController();
  final TextEditingController _transportPassengersController =
      TextEditingController(text: '1');
  final TextEditingController _transportNoteController =
      TextEditingController();
  DateTimeRange? _selectedDateRange;
  TimeOfDay? _transportPickupTime;
  final DateFormat dateFormat = DateFormat('dd MMM');

  final List<File> _selectedImages = [];
  bool _isLoading = false;
  List<Map<String, String>> _invitedFriends = [];
  bool _requestTransport = false;
  String _transportType = 'Standard';
  TransportRouteEstimate? _transportRouteEstimate;
  bool _isCalculatingRoute = false;
  String? _routeError;
  Timer? _routeDebounce;

  bool isSoloSelected = true; // Boolean to track selected option

  @override
  void initState() {
    super.initState();
    _transportPickupController.addListener(_scheduleRouteEstimate);
    _transportDropoffController.addListener(_scheduleRouteEstimate);
  }

  void _scheduleRouteEstimate() {
    if (!_requestTransport) return;
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 700), _estimateRoute);
  }

  Future<void> _estimateRoute() async {
    if (!_requestTransport) return;
    final pickup = _transportPickupController.text.trim();
    final dropoff = _transportDropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      setState(() {
        _transportRouteEstimate = null;
        _routeError = null;
      });
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
      _routeError = null;
    });

    try {
      final estimate = await TransportRouteEstimator.estimate(
        pickup: pickup,
        dropoff: dropoff,
        transportType: _transportType,
      );
      if (!mounted) return;
      setState(() {
        _transportRouteEstimate = estimate;
        _routeError = null;
      });
    } on TransportRouteException catch (error) {
      if (!mounted) return;
      setState(() {
        _transportRouteEstimate = null;
        _routeError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _transportRouteEstimate = null;
        _routeError = 'Could not calculate route.';
      });
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    final apiKey = GoogleApiConfig.placesApiKey;
    if (apiKey.isEmpty) return [];

    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final predictions = json['predictions'] as List;
      return predictions.map((p) => p['description'] as String).toList();
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  Future<void> _saveTripToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_isLoading) return;

    // Check if destination is provided
    if (_destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    // Check if trip name is provided
    if (_tripNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a trip name')));
      return;
    }

    // Check if budget is provided and is a valid number
    if (_budgetController.text.isEmpty ||
        double.tryParse(_budgetController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget')),
      );
      return;
    }

    // Check if date range is provided
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }

    final maxGroupSize = isSoloSelected
        ? 1
        : int.tryParse(_maxGroupSizeController.text);
    if (maxGroupSize == null || maxGroupSize < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group trips must allow at least 2 people.'),
        ),
      );
      return;
    }

    // Extract and format start and end dates
    final DateTime startDate = _selectedDateRange!.start;
    final DateTime endDate = _selectedDateRange!.end;
    final DateFormat dateFormat = DateFormat("dd/MM/yyyy");

    // Validate that endDate is after startDate and not today or earlier
    final DateTime now = DateTime.now();
    if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'End date must be after the start date and cannot be today',
          ),
        ),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo')),
      );
      return;
    }

    if (_requestTransport) {
      if (_transportPickupController.text.trim().isEmpty ||
          _transportDropoffController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter pickup and dropoff locations'),
          ),
        );
        return;
      }

      if (_transportPickupTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a pickup time')),
        );
        return;
      }

      final passengers = int.tryParse(_transportPassengersController.text);
      if (passengers == null || passengers < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid passenger count')),
        );
        return;
      }

      if (_transportRouteEstimate == null) {
        await _estimateRoute();
      }

      if (_transportRouteEstimate == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transport fare could not be calculated'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    List<String> imageUrls = [];
    try {
      imageUrls = await _uploadImagesToFirebaseStorage(_selectedImages);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading photos: $e')));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    CollectionReference trips = FirebaseFirestore.instance.collection('trips');
    try {
      final distanceKm = _requestTransport
          ? _transportRouteEstimate!.distanceKm
          : null;
      final durationMinutes = _requestTransport
          ? _transportRouteEstimate!.durationMinutes
          : null;
      final estimatedFare = _requestTransport
          ? _transportRouteEstimate!.estimatedFare
          : null;
      final pickupAt = _requestTransport
          ? DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
              _transportPickupTime!.hour,
              _transportPickupTime!.minute,
            )
          : null;
      final invitedUsers = _pendingInviteUsers();
      final inviteStatuses = {
        for (final friend in invitedUsers)
          if ((friend['id'] ?? '').isNotEmpty) friend['id']!: 'pending',
      };

      final tripDoc = await trips.add({
        'userId': user?.uid,
        'destination': _destinationController.text,
        'startDate': dateFormat.format(startDate),
        'endDate': dateFormat.format(endDate),
        'budget': CurrencyFormatter.formatRand(_budgetController.text),
        'interest': _selectedInterest,
        'tripName': _tripNameController.text,
        'description': _descriptionController.text,
        'imagePath': imageUrls.first,
        'imageUrls': imageUrls,
        'status': 'ongoing',
        'travelType': isSoloSelected ? 'Solo' : 'Friends', // Save travel type
        'maxGroupSize': maxGroupSize,
        'joinedUsers': [],
        'invitedFriends': invitedUsers,
        'invitedUsers': invitedUsers,
        'inviteStatuses': inviteStatuses,
        'transportRequested': _requestTransport,
        if (_requestTransport)
          'transport': {
            'status': 'requested',
            'type': _transportType,
            'pickup': _transportPickupController.text.trim(),
            'pickupCoordinates': {
              'latitude': _transportRouteEstimate!.pickupLatitude,
              'longitude': _transportRouteEstimate!.pickupLongitude,
            },
            'pickupTime': _transportPickupTimeController.text.trim(),
            'pickupAt': pickupAt == null ? null : Timestamp.fromDate(pickupAt),
            'dropoff': _transportDropoffController.text.trim(),
            'dropoffCoordinates': {
              'latitude': _transportRouteEstimate!.dropoffLatitude,
              'longitude': _transportRouteEstimate!.dropoffLongitude,
            },
            'passengers': int.parse(_transportPassengersController.text),
            'distanceKm': distanceKm,
            'durationMinutes': durationMinutes,
            'estimatedFare': estimatedFare,
            'currency': 'ZAR',
          },
      });

      await _sendTripInvites(
        tripId: tripDoc.id,
        tripName: _tripNameController.text.trim(),
        invitedUsers: invitedUsers,
      );

      if (_requestTransport) {
        await FirebaseFirestore.instance.collection('transport_requests').add({
          'tripId': tripDoc.id,
          'userId': user?.uid,
          'riderName': user?.displayName ?? user?.email ?? 'Riendzo traveler',
          'tripName': _tripNameController.text.trim(),
          'destination': _destinationController.text.trim(),
          'tripStartDate': dateFormat.format(startDate),
          'tripEndDate': dateFormat.format(endDate),
          'tripStartAt': Timestamp.fromDate(startDate),
          'tripEndAt': Timestamp.fromDate(endDate),
          'pickupTime': _transportPickupTimeController.text.trim(),
          'pickupAt': pickupAt == null ? null : Timestamp.fromDate(pickupAt),
          'pickup': _transportPickupController.text.trim(),
          'pickupCoordinates': {
            'latitude': _transportRouteEstimate!.pickupLatitude,
            'longitude': _transportRouteEstimate!.pickupLongitude,
          },
          'dropoff': _transportDropoffController.text.trim(),
          'dropoffCoordinates': {
            'latitude': _transportRouteEstimate!.dropoffLatitude,
            'longitude': _transportRouteEstimate!.dropoffLongitude,
          },
          'passengers': int.parse(_transportPassengersController.text),
          'distanceKm': distanceKm,
          'durationMinutes': durationMinutes,
          'estimatedFare': estimatedFare,
          'currency': 'ZAR',
          'transportType': _transportType,
          'note': _transportNoteController.text.trim(),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedBy': null,
          'acceptedAt': null,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving trip data: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<String>> _uploadImagesToFirebaseStorage(List<File> images) async {
    final urls = <String>[];
    for (final image in images) {
      urls.add(await _uploadImageToFirebaseStorage(image));
    }
    return urls;
  }

  Future<String> _uploadImageToFirebaseStorage(File image) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref().child(
      "trip_images/${DateTime.now().millisecondsSinceEpoch}_${image.path.hashCode}.jpg",
    );
    SettableMetadata metadata = SettableMetadata(
      cacheControl: 'max-age=60',
      contentType: 'image/jpeg',
    );

    try {
      UploadTask uploadTask = ref.putFile(image, metadata);
      TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 4 photos.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    final remainingSlots = 4 - _selectedImages.length;
    final selectedFiles = pickedFiles.take(remainingSlots).toList();
    setState(() {
      _selectedImages.addAll(selectedFiles.map((file) => File(file.path)));
    });

    if (pickedFiles.length > selectedFiles.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 4 photos.')),
      );
    }
  }

  void _removeSelectedImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  List<Map<String, String>> _pendingInviteUsers() {
    return _invitedFriends.map((friend) {
      return {
        'id': friend['id'] ?? '',
        'name': friend['name'] ?? 'Invited traveler',
        'email': friend['email'] ?? '',
        'profilePicture': friend['profilePicture'] ?? '',
        'status': 'pending',
      };
    }).toList();
  }

  Future<void> _sendTripInvites({
    required String tripId,
    required String tripName,
    required List<Map<String, String>> invitedUsers,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    for (final invitedUser in invitedUsers) {
      final invitedUserId = invitedUser['id'] ?? '';
      if (invitedUserId.isEmpty) continue;

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('invites')
          .doc(invitedUserId)
          .set({
            'userId': invitedUserId,
            'displayName': invitedUser['name'] ?? 'Invited traveler',
            'email': invitedUser['email'] ?? '',
            'photoURL': invitedUser['profilePicture'] ?? '',
            'ownerId': currentUser.uid,
            'tripId': tripId,
            'tripName': tripName,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await UserNotificationService.create(
        userId: invitedUserId,
        type: 'trip_invite',
        title: 'Trip invitation',
        message:
            '${currentUser.displayName ?? currentUser.email ?? 'Someone'} invited you to join $tripName.',
        tripId: tripId,
        actorUserId: currentUser.uid,
      );
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _tripNameController.dispose();
    _destinationController.dispose();
    _datesController.dispose();
    _descriptionController.dispose();
    _maxGroupSizeController.dispose();
    _routeDebounce?.cancel();
    _transportPickupController.dispose();
    _transportPickupTimeController.dispose();
    _transportDropoffController.dispose();
    _transportPassengersController.dispose();
    _transportNoteController.dispose();
    super.dispose();
  }

  int _currentStep = 0;
  static const _stepNames = [
    'Trip basics',
    'Travellers',
    'Transport',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          RiendzoSliverAppBar(
            title: 'Plan a trip',
            subtitle:
                'Step ${_currentStep + 1} of 4 · ${_stepNames[_currentStep]}',
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
                    0 => _basicsStep(),
                    1 => _travellersStep(),
                    2 => _transportStep(),
                    _ => _reviewStep(),
                  },
                ),
              ),
            ),
            _PlannerFooter(
              currentStep: _currentStep,
              loading: _isLoading,
              onBack: _currentStep == 0
                  ? null
                  : () => setState(() => _currentStep--),
              onContinue: _isLoading
                  ? null
                  : _currentStep == 3
                  ? _saveTripToFirebase
                  : _continueToNextStep,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _basicsStep() => [
    _StepIntro(
      icon: Icons.explore_outlined,
      title: 'Where are you going?',
      subtitle: 'Add the essentials. You can refine the details later.',
    ),
    TypeAheadField<String>(
      controller: _destinationController,
      builder: (context, controller, focusNode) => TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.place_outlined),
          labelText: 'Destination',
          hintText: 'Search a city or place',
          border: OutlineInputBorder(),
        ),
      ),
      suggestionsCallback: (pattern) =>
          pattern.trim().isEmpty ? <String>[] : getSuggestions(pattern),
      itemBuilder: (context, suggestion) => ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(suggestion),
      ),
      onSelected: (suggestion) => _destinationController.text = suggestion,
    ),
    const SizedBox(height: 14),
    GestureDetector(
      onTap: _pickDates,
      child: AbsorbPointer(
        child: CustomBookingTextField(
          controller: _datesController,
          icon: Icons.calendar_today_outlined,
          text: 'Dates',
          hintText: 'Select date range',
          keyboardType: TextInputType.datetime,
          readOnly: true,
        ),
      ),
    ),
    CustomBookingTextField(
      controller: _tripNameController,
      icon: Icons.trip_origin_outlined,
      text: 'Trip name',
      hintText: 'e.g. Cape Town summer',
      keyboardType: TextInputType.text,
      readOnly: false,
    ),
    CustomBookingTextField(
      controller: _budgetController,
      icon: Icons.payments_outlined,
      text: 'Daily budget per person',
      hintText: 'Enter your budget',
      keyboardType: TextInputType.number,
      readOnly: false,
    ),
    CustomBookingDropdown(
      interests: const [
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
      ],
      selectedInterest: _selectedInterest,
      onChanged: (value) => setState(() => _selectedInterest = value),
      icon: Icons.favorite_outline,
      hintText: 'Choose your interest',
    ),
  ];

  List<Widget> _travellersStep() => [
    const _StepIntro(
      icon: Icons.groups_2_outlined,
      title: 'Who is coming?',
      subtitle: 'Travel solo or invite friends to join your plan.',
    ),
    SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          icon: Icon(Icons.person_outline),
          label: Text('Solo'),
        ),
        ButtonSegment(
          value: false,
          icon: Icon(Icons.group_outlined),
          label: Text('With friends'),
        ),
      ],
      selected: {isSoloSelected},
      onSelectionChanged: (selection) async {
        final solo = selection.first;
        setState(() {
          isSoloSelected = solo;
          if (solo) {
            _invitedFriends = [];
            _maxGroupSizeController.text = '1';
          } else if (_maxGroupSizeController.text == '1') {
            _maxGroupSizeController.text = '6';
          }
        });
        if (!solo) await _selectFriends();
      },
    ),
    if (!isSoloSelected) ...[
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _selectFriends,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(
          _invitedFriends.isEmpty
              ? 'Choose friends'
              : '${_invitedFriends.length} friends selected',
        ),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      CustomBookingTextField(
        controller: _maxGroupSizeController,
        icon: Icons.groups_2_outlined,
        text: 'Maximum group size',
        hintText: 'Total people including you',
        keyboardType: TextInputType.number,
        readOnly: false,
      ),
    ],
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.notes_outlined),
      title: const Text('Trip description'),
      subtitle: const Text('Optional'),
      children: [
        CustomBookingTextField(
          controller: _descriptionController,
          icon: Icons.description_outlined,
          text: 'Description',
          hintText: 'What should travellers know?',
          keyboardType: TextInputType.multiline,
          readOnly: false,
        ),
      ],
    ),
    const SizedBox(height: 10),
    _TripPhotoPicker(
      images: _selectedImages,
      onAdd: _pickImage,
      onRemove: _removeSelectedImage,
    ),
  ];

  List<Widget> _transportStep() => [
    const _StepIntro(
      icon: Icons.local_taxi_outlined,
      title: 'Need a ride?',
      subtitle: 'Request a verified Riendzo partner for this trip.',
    ),
    TransportRequestSection(
      enabled: _requestTransport,
      transportType: _transportType,
      pickupController: _transportPickupController,
      pickupTimeController: _transportPickupTimeController,
      dropoffController: _transportDropoffController,
      passengersController: _transportPassengersController,
      noteController: _transportNoteController,
      routeEstimate: _transportRouteEstimate,
      isCalculatingRoute: _isCalculatingRoute,
      routeError: _routeError,
      onEnabledChanged: (value) {
        setState(() {
          _requestTransport = value;
          if (value && _transportDropoffController.text.isEmpty) {
            _transportDropoffController.text = _destinationController.text;
          }
          if (!value) {
            _transportRouteEstimate = null;
            _routeError = null;
          }
        });
        if (value) _scheduleRouteEstimate();
      },
      onTransportTypeChanged: (value) {
        setState(() {
          _transportType = value;
          _transportRouteEstimate = _transportRouteEstimate?.copyWithFare(
            transportType: value,
          );
        });
      },
      onRefreshRoute: _estimateRoute,
      onSelectPickupTime: _selectPickupTime,
    ),
    if (!_requestTransport)
      const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'You can add transport later from your trip details.',
          textAlign: TextAlign.center,
        ),
      ),
  ];

  List<Widget> _reviewStep() => [
    const _StepIntro(
      icon: Icons.fact_check_outlined,
      title: 'Ready to go?',
      subtitle: 'Review your plan before creating the trip.',
    ),
    _ReviewCard(
      title: 'Trip basics',
      icon: Icons.place_outlined,
      onEdit: () => setState(() => _currentStep = 0),
      rows: [
        ('Destination', _destinationController.text),
        ('Dates', _datesController.text),
        ('Trip name', _tripNameController.text),
        ('Interest', _selectedInterest ?? 'Not selected'),
        ('Daily budget', 'R${_budgetController.text}'),
      ],
    ),
    const SizedBox(height: 12),
    _ReviewCard(
      title: 'Travellers',
      icon: Icons.groups_2_outlined,
      onEdit: () => setState(() => _currentStep = 1),
      rows: [
        ('Travel type', isSoloSelected ? 'Solo' : 'With friends'),
        if (!isSoloSelected) ('Group size', _maxGroupSizeController.text),
        if (_invitedFriends.isNotEmpty)
          ('Invitations', '${_invitedFriends.length} pending'),
        ('Photos', '${_selectedImages.length} selected'),
      ],
    ),
    const SizedBox(height: 12),
    _ReviewCard(
      title: 'Transport',
      icon: Icons.local_taxi_outlined,
      onEdit: () => setState(() => _currentStep = 2),
      rows: _requestTransport
          ? [
              ('Vehicle', _transportType),
              ('Pickup', _transportPickupController.text),
              ('Drop-off', _transportDropoffController.text),
              ('Pickup time', _transportPickupTimeController.text),
              if (_transportRouteEstimate != null)
                (
                  'Estimated fare',
                  'R${_transportRouteEstimate!.estimatedFare.toStringAsFixed(0)}',
                ),
            ]
          : const [('Request', 'No transport needed')],
    ),
  ];

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateRange = picked;
      _datesController.text =
          '${dateFormat.format(picked.start)} - ${dateFormat.format(picked.end)}';
    });
  }

  Future<void> _selectFriends() async {
    final selected = await Navigator.push<List<Map<String, String>>>(
      context,
      MaterialPageRoute(builder: (_) => const FriendsSelectionPage()),
    );
    if (selected != null && mounted) {
      setState(() => _invitedFriends = selected);
    }
  }

  Future<void> _continueToNextStep() async {
    if (_currentStep == 0) {
      if (_destinationController.text.trim().isEmpty ||
          _tripNameController.text.trim().isEmpty ||
          _selectedDateRange == null ||
          _budgetController.text.trim().isEmpty) {
        _showStepMessage('Add a destination, dates, trip name, and budget.');
        return;
      }
    }
    if (_currentStep == 1 && !isSoloSelected) {
      final groupSize = int.tryParse(_maxGroupSizeController.text);
      if (groupSize == null || groupSize < 2) {
        _showStepMessage('Group size must be at least 2.');
        return;
      }
    }
    if (_currentStep == 1 && _selectedImages.isEmpty) {
      _showStepMessage('Add at least one trip photo.');
      return;
    }
    if (_currentStep == 2 && _requestTransport) {
      if (_transportPickupController.text.trim().isEmpty ||
          _transportDropoffController.text.trim().isEmpty ||
          _transportPickupTime == null) {
        _showStepMessage('Add pickup, drop-off, and pickup time.');
        return;
      }
      if (_transportRouteEstimate == null) await _estimateRoute();
      if (_transportRouteEstimate == null) return;
    }
    if (mounted) setState(() => _currentStep++);
  }

  void _showStepMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectPickupTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _transportPickupTime ?? TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _transportPickupTime = pickedTime;
      _transportPickupTimeController.text = pickedTime.format(context);
    });
  }
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
  final String title, subtitle;
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

class _PlannerFooter extends StatelessWidget {
  const _PlannerFooter({
    required this.currentStep,
    required this.loading,
    required this.onBack,
    required this.onContinue,
  });
  final int currentStep;
  final bool loading;
  final VoidCallback? onBack, onContinue;
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
                  : Icon(currentStep == 3 ? Icons.check : Icons.arrow_forward),
              label: Text(
                loading
                    ? 'Creating trip…'
                    : currentStep == 3
                    ? 'Create trip'
                    : 'Continue',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TripPhotoPicker extends StatelessWidget {
  final List<File> images;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _TripPhotoPicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Trip photos',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('${images.length}/4', style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Add up to 4 photos that sell the experience.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (images.isEmpty)
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 42),
                      SizedBox(height: 8),
                      Text('Upload trip photos'),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: images.length + (images.length < 4 ? 1 : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  if (index == images.length) {
                    return InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_photo_alternate_outlined),
                        ),
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(images[index], fit: BoxFit.cover),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton.filled(
                            tooltip: 'Remove photo',
                            onPressed: () => onRemove(index),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
