import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riendzo/services/google_api_config.dart';
import 'package:riendzo/services/transport_fare_calculator.dart';

class TransportRouteEstimator {
  const TransportRouteEstimator._();

  static Future<TransportRouteEstimate> estimate({
    required String pickup,
    required String dropoff,
    required String transportType,
  }) async {
    final apiKey = GoogleApiConfig.mapsApiKey;
    if (apiKey.isEmpty) {
      throw const TransportRouteException(
        'Google Maps API key is not configured.',
      );
    }

    final uri = Uri.https(
      'routes.googleapis.com',
      '/directions/v2:computeRoutes',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters',
      },
      body: jsonEncode({
        'origin': {'address': pickup},
        'destination': {'address': dropoff},
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
        'languageCode': 'en',
        'units': 'METRIC',
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw TransportRouteException(
        _errorMessageFromRoutesApi(body, response.statusCode),
      );
    }

    final routes = body['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw const TransportRouteException('No route was found.');
    }

    final route = routes.first as Map<String, dynamic>;
    final distanceMeters = (route['distanceMeters'] as num?)?.toDouble();
    final durationSeconds = _parseDurationSeconds(route['duration'] as String?);
    if (distanceMeters == null || durationSeconds == null) {
      throw const TransportRouteException('Route estimate was incomplete.');
    }
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

  static int? _parseDurationSeconds(String? duration) {
    if (duration == null || !duration.endsWith('s')) return null;
    return double.tryParse(duration.substring(0, duration.length - 1))?.ceil();
  }

  static String _errorMessageFromRoutesApi(
    Map<String, dynamic> body,
    int statusCode,
  ) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Could not calculate route. HTTP $statusCode.';
  }
}

class TransportRouteException implements Exception {
  const TransportRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}
