import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riendzo/services/transport_fare_calculator.dart';

class TransportRouteEstimator {
  const TransportRouteEstimator._();

  static const _mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
  static const _placesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  static String get _apiKey =>
      _mapsApiKey.isNotEmpty ? _mapsApiKey : _placesApiKey;

  static Future<TransportRouteEstimate> estimate({
    required String pickup,
    required String dropoff,
    required String transportType,
  }) async {
    if (_apiKey.isEmpty) {
      throw const TransportRouteException(
        'Google Maps API key is not configured.',
      );
    }

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/distancematrix/json', {
          'origins': pickup,
          'destinations': dropoff,
          'mode': 'driving',
          'units': 'metric',
          'key': _apiKey,
        });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw TransportRouteException(
        'Could not calculate route. HTTP ${response.statusCode}.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK') {
      throw TransportRouteException(
        (body['error_message'] as String?) ?? 'Could not calculate route.',
      );
    }

    final rows = body['rows'] as List<dynamic>? ?? [];
    final elements = rows.isNotEmpty
        ? rows.first['elements'] as List<dynamic>? ?? []
        : <dynamic>[];
    if (elements.isEmpty) {
      throw const TransportRouteException('No route was found.');
    }

    final element = elements.first as Map<String, dynamic>;
    final elementStatus = element['status'] as String?;
    if (elementStatus != 'OK') {
      throw const TransportRouteException('No driving route was found.');
    }

    final distanceMeters = (element['distance']['value'] as num).toDouble();
    final durationSeconds = (element['duration']['value'] as num).toInt();
    final distanceKm = distanceMeters / 1000;
    final durationMinutes = (durationSeconds / 60).ceil();

    return TransportRouteEstimate(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      estimatedFare: TransportFareCalculator.estimateFare(
        transportType: transportType,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      ),
    );
  }
}

class TransportRouteException implements Exception {
  const TransportRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}
