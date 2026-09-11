import 'package:flutter_test/flutter_test.dart';
import 'package:riendzo/services/transport_fare_calculator.dart';

void main() {
  test('changing vehicle type preserves navigation coordinates', () {
    const estimate = TransportRouteEstimate(
      distanceKm: 12,
      durationMinutes: 20,
      estimatedFare: 199,
      pickupLatitude: -26.1452,
      pickupLongitude: 28.0449,
      dropoffLatitude: -26.2381,
      dropoffLongitude: 27.9088,
    );

    final comfort = estimate.copyWithFare(transportType: 'Comfort');

    expect(comfort.pickupLatitude, estimate.pickupLatitude);
    expect(comfort.pickupLongitude, estimate.pickupLongitude);
    expect(comfort.dropoffLatitude, estimate.dropoffLatitude);
    expect(comfort.dropoffLongitude, estimate.dropoffLongitude);
    expect(comfort.estimatedFare, greaterThan(estimate.estimatedFare));
  });
}
