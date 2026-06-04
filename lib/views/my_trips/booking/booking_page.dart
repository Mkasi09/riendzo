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
import 'package:riendzo/views/my_trips/booking/widgets/booking_header.dart';
import 'package:riendzo/views/my_trips/booking/widgets/custom_button.dart';
import 'package:riendzo/views/my_trips/booking/widgets/custom_text_field.dart';
import 'package:riendzo/views/my_trips/booking/widgets/transport_request_section.dart';
import 'package:riendzo/services/currency_formatter.dart';
import 'package:riendzo/services/transport_fare_calculator.dart';
import 'package:riendzo/services/google_api_config.dart';
import 'package:riendzo/services/transport_route_estimator.dart';
import 'package:riendzo/services/user_notification_service.dart';
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
            'pickupTime': _transportPickupTimeController.text.trim(),
            'pickupAt': pickupAt == null ? null : Timestamp.fromDate(pickupAt),
            'dropoff': _transportDropoffController.text.trim(),
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
          'dropoff': _transportDropoffController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 15, top: 10),
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BookingHeader(
                  text: 'Trip Information',
                  color: Colors.black,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "I want to go to...",
                      style: TextStyle(color: Colors.black),
                    ),
                    TypeAheadField<String>(
                      controller: _destinationController,
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 23,
                          ),
                          decoration: const InputDecoration(
                            hintText: "Enter destination",
                            hintStyle: TextStyle(color: Colors.black),
                          ),
                        );
                      },
                      suggestionsCallback: (pattern) async {
                        if (pattern.isNotEmpty) {
                          return await getSuggestions(pattern);
                        }
                        return [];
                      },
                      itemBuilder: (context, suggestion) {
                        return ListTile(title: Text(suggestion));
                      },
                      onSelected: (suggestion) {
                        // Update the search bar with the selected suggestion
                        _destinationController.text = suggestion;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              children: [
                GestureDetector(
                  onTap: () async {
                    DateTimeRange? pickedRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now(), // Disable past dates
                      lastDate: DateTime(2030),
                      initialDateRange: DateTimeRange(
                        start: DateTime.now(),
                        end: DateTime.now().add(const Duration(days: 7)),
                      ),
                    );

                    if (pickedRange != null) {
                      _datesController.text =
                          '${dateFormat.format(pickedRange.start)} - ${dateFormat.format(pickedRange.end)}';
                      _selectedDateRange =
                          pickedRange; // Save the selected date range
                    }
                  },
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

                const SizedBox(height: 1),
                CustomBookingTextField(
                  controller: _budgetController,
                  icon: Icons.attach_money,
                  text: 'Budget per person per day',
                  hintText: 'Enter your budget',
                  keyboardType: TextInputType.number,
                  readOnly: false,
                ),
                CustomBookingDropdown(
                  interests: [
                    "Adventure",
                    "Beaches",
                    "Culture",
                    "Cuisine",
                    "Exploration",
                    "Festivals",
                    "Hiking",
                    "History",
                    "Relaxation",
                    "Safari",
                    "Scenery",
                    "Sports",
                    "Wildlife",
                    "Cruises",
                    "Mountains",
                    "Photography",
                    "Roadtrips",
                    "Shopping",
                    "Spa",
                    "Waterfalls",
                  ],
                  selectedInterest: _selectedInterest,
                  onChanged: (value) {
                    setState(() {
                      _selectedInterest = value;
                    });
                  },
                  icon: Icons.favorite_outline,
                  hintText: 'Choose your interest',
                ),
                CustomBookingTextField(
                  controller: _tripNameController,
                  icon: Icons.trip_origin_outlined,
                  text: 'Trip Name',
                  hintText: 'e.g. Summer Vacation',
                  keyboardType: TextInputType.text,
                  readOnly: false,
                ),
                CustomBookingTextField(
                  controller: _descriptionController,
                  icon: Icons.description_outlined,
                  text: 'Trip Description',
                  hintText: 'Trip Description',
                  keyboardType: TextInputType.multiline,
                  readOnly: false,
                ),
                const SizedBox(height: 5),

                _TripPhotoPicker(
                  images: _selectedImages,
                  onAdd: _pickImage,
                  onRemove: _removeSelectedImage,
                ),
                const SizedBox(height: 10),

                // Travel type section
                Container(
                  margin: const EdgeInsets.only(top: 15),
                  child: const Text('Travel with ?'),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    CustomButton(
                      horizontalPadding: 11.5,
                      cardColor: isSoloSelected
                          ? Colors.blueAccent
                          : Colors.white,
                      onPressed: () {
                        setState(() {
                          isSoloSelected = true;
                          _invitedFriends = [];
                          _maxGroupSizeController.text = '1';
                        });
                      },
                      text: "Solo",
                      textColor: isSoloSelected ? Colors.white : Colors.blue,
                      TextSize: 16.5,
                    ),
                    CustomButton(
                      horizontalPadding: 5,
                      cardColor: !isSoloSelected
                          ? Colors.blueAccent
                          : Colors.white,
                      onPressed: () async {
                        setState(() {
                          isSoloSelected = false;
                          if (_maxGroupSizeController.text == '1') {
                            _maxGroupSizeController.text = '6';
                          }
                        });
                        final selected =
                            await Navigator.push<List<Map<String, String>>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const FriendsSelectionPage(),
                              ),
                            );
                        if (selected != null && mounted) {
                          setState(() {
                            _invitedFriends = selected;
                            final currentLimit =
                                int.tryParse(_maxGroupSizeController.text) ?? 0;
                            if (currentLimit < 2) {
                              _maxGroupSizeController.text = '6';
                            }
                          });
                        }
                      },
                      text: "With Friends",
                      textColor: !isSoloSelected ? Colors.white : Colors.blue,
                      TextSize: 16.5,
                    ),
                  ],
                ),
                if (_invitedFriends.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_invitedFriends.length} pending invite${_invitedFriends.length == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (!isSoloSelected)
                  CustomBookingTextField(
                    controller: _maxGroupSizeController,
                    icon: Icons.groups_2_outlined,
                    text: 'Maximum group size',
                    hintText: 'Total people including you',
                    keyboardType: TextInputType.number,
                    readOnly: false,
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
                        _transportDropoffController.text =
                            _destinationController.text;
                      }
                      if (value) {
                        _scheduleRouteEstimate();
                      } else {
                        _transportRouteEstimate = null;
                        _routeError = null;
                      }
                    });
                  },
                  onTransportTypeChanged: (value) {
                    setState(() {
                      _transportType = value;
                      _transportRouteEstimate = _transportRouteEstimate
                          ?.copyWithFare(transportType: value);
                    });
                  },
                  onRefreshRoute: _estimateRoute,
                  onSelectPickupTime: _selectPickupTime,
                ),
                const SizedBox(height: 10),

                // Save button
                Container(
                  margin: const EdgeInsets.all(15),
                  width: double.infinity,
                  child: CustomButton(
                    horizontalPadding: 28,
                    cardColor: Colors.blueAccent,
                    onPressed: _isLoading
                        ? null
                        : _saveTripToFirebase, // Disable button if loading
                    text: _isLoading
                        ? "Saving..."
                        : "Save", // Change text while loading

                    textColor: Colors.white,
                    TextSize: 16.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
