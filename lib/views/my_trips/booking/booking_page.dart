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
import 'package:riendzo/services/transport_fare_calculator.dart';
import 'package:riendzo/services/transport_route_estimator.dart';
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
  final TextEditingController _datesController = TextEditingController();
  final TextEditingController _transportPickupController =
      TextEditingController();
  final TextEditingController _transportDropoffController =
      TextEditingController();
  final TextEditingController _transportPassengersController =
      TextEditingController(text: '1');
  final TextEditingController _transportNoteController =
      TextEditingController();
  DateTimeRange? _selectedDateRange;
  final DateFormat dateFormat = DateFormat('dd MMM');

  File? _selectedImage;
  String? _imageUrl;
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
    // TODO: Replace with your actual Google Places API key
    // Store this securely in environment variables or a secure configuration file
    const apiKey = String.fromEnvironment(
      'GOOGLE_PLACES_API_KEY',
      defaultValue: '',
    );
    if (apiKey.isEmpty) {
      throw Exception('Google Places API key not configured');
    }
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

    // Check if an image is selected
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
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

    String imageUrl = '';
    if (_selectedImage != null) {
      try {
        imageUrl = await _uploadImageToFirebaseStorage(_selectedImage!);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
        setState(() {
          _isLoading = false;
        });
        return;
      }
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

      final tripDoc = await trips.add({
        'userId': user?.uid,
        'destination': _destinationController.text,
        'startDate': dateFormat.format(startDate),
        'endDate': dateFormat.format(endDate),
        'budget': "\$${_budgetController.text}", // Save budget with $
        'interest': _selectedInterest,
        'tripName': _tripNameController.text,
        'description': _descriptionController.text,
        'imagePath': imageUrl,
        'status': 'ongoing',
        'travelType': isSoloSelected ? 'Solo' : 'Friends', // Save travel type
        'invitedFriends': _invitedFriends,
        'transportRequested': _requestTransport,
        if (_requestTransport)
          'transport': {
            'status': 'requested',
            'type': _transportType,
            'pickup': _transportPickupController.text.trim(),
            'dropoff': _transportDropoffController.text.trim(),
            'passengers': int.parse(_transportPassengersController.text),
            'distanceKm': distanceKm,
            'durationMinutes': durationMinutes,
            'estimatedFare': estimatedFare,
            'currency': 'ZAR',
          },
      });

      if (_requestTransport) {
        await FirebaseFirestore.instance.collection('transport_requests').add({
          'tripId': tripDoc.id,
          'userId': user?.uid,
          'riderName': user?.displayName ?? user?.email ?? 'Riendzo traveler',
          'tripName': _tripNameController.text.trim(),
          'destination': _destinationController.text.trim(),
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

  Future<String> _uploadImageToFirebaseStorage(File image) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref().child(
      "trip_images/${DateTime.now().millisecondsSinceEpoch}",
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _selectedImage = File(pickedFile.path);
      }
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _tripNameController.dispose();
    _destinationController.dispose();
    _datesController.dispose();
    _descriptionController.dispose();
    _routeDebounce?.cancel();
    _transportPickupController.dispose();
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

                // Image upload section
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : _imageUrl != null && _imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedImage == null && _imageUrl == null
                        ? const Center(child: Text('Upload a photo'))
                        : const SizedBox.shrink(),
                  ),
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
                      '${_invitedFriends.length} friend${_invitedFriends.length == 1 ? '' : 's'} invited',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                TransportRequestSection(
                  enabled: _requestTransport,
                  transportType: _transportType,
                  pickupController: _transportPickupController,
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
}
