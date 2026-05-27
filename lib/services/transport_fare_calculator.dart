class TransportFareCalculator {
  const TransportFareCalculator._();

  static const _rates = {
    'Standard': TransportFareRate(baseFare: 25, perKm: 12, perMinute: 1.5),
    'Comfort': TransportFareRate(baseFare: 35, perKm: 15, perMinute: 2),
    'XL': TransportFareRate(baseFare: 50, perKm: 20, perMinute: 2.5),
  };

  static TransportFareRate rateFor(String transportType) {
    return _rates[transportType] ?? _rates['Standard']!;
  }

  static double estimateFare({
    required String transportType,
    required double distanceKm,
    required int durationMinutes,
  }) {
    final rate = rateFor(transportType);
    return rate.baseFare +
        (distanceKm * rate.perKm) +
        (durationMinutes * rate.perMinute);
  }
}

class TransportRouteEstimate {
  const TransportRouteEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.estimatedFare,
  });

  final double distanceKm;
  final int durationMinutes;
  final double estimatedFare;

  TransportRouteEstimate copyWithFare({required String transportType}) {
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

class TransportFareRate {
  const TransportFareRate({
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
  });

  final double baseFare;
  final double perKm;
  final double perMinute;
}
