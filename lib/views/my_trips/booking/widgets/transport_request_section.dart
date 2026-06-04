import 'package:flutter/material.dart';
import 'package:riendzo/services/transport_fare_calculator.dart';

class TransportRequestSection extends StatelessWidget {
  const TransportRequestSection({
    super.key,
    required this.enabled,
    required this.transportType,
    required this.pickupController,
    required this.pickupTimeController,
    required this.dropoffController,
    required this.passengersController,
    required this.noteController,
    required this.routeEstimate,
    required this.isCalculatingRoute,
    required this.routeError,
    required this.onEnabledChanged,
    required this.onTransportTypeChanged,
    required this.onRefreshRoute,
    required this.onSelectPickupTime,
  });

  final bool enabled;
  final String transportType;
  final TextEditingController pickupController;
  final TextEditingController pickupTimeController;
  final TextEditingController dropoffController;
  final TextEditingController passengersController;
  final TextEditingController noteController;
  final TransportRouteEstimate? routeEstimate;
  final bool isCalculatingRoute;
  final String? routeError;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onTransportTypeChanged;
  final VoidCallback onRefreshRoute;
  final VoidCallback onSelectPickupTime;

  static const transportTypes = ['Standard', 'Comfort', 'XL'];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: onEnabledChanged,
              title: const Text(
                'Request transport',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Send this trip to available Riendzo partner drivers.',
              ),
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: transportTypes
                    .map(
                      (type) => ButtonSegment<String>(
                        value: type,
                        label: Text(type),
                        icon: Icon(_iconFor(type)),
                      ),
                    )
                    .toList(),
                selected: {transportType},
                onSelectionChanged: (selection) {
                  onTransportTypeChanged(selection.first);
                },
              ),
              const SizedBox(height: 12),
              _TransportField(
                controller: pickupController,
                icon: Icons.my_location_outlined,
                label: 'Pickup location',
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onSelectPickupTime,
                child: AbsorbPointer(
                  child: _TransportField(
                    controller: pickupTimeController,
                    icon: Icons.access_time,
                    label: 'Pickup time',
                    readOnly: true,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _TransportField(
                controller: dropoffController,
                icon: Icons.place_outlined,
                label: 'Dropoff location',
              ),
              const SizedBox(height: 10),
              _TransportField(
                controller: passengersController,
                icon: Icons.group_outlined,
                label: 'Passengers',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _TransportField(
                controller: noteController,
                icon: Icons.notes_outlined,
                label: 'Driver note',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _FareEstimate(
                transportType: transportType,
                routeEstimate: routeEstimate,
                isCalculatingRoute: isCalculatingRoute,
                routeError: routeError,
                onRefreshRoute: onRefreshRoute,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String type) {
    return switch (type) {
      'Comfort' => Icons.airline_seat_recline_extra,
      'XL' => Icons.airport_shuttle_outlined,
      _ => Icons.local_taxi_outlined,
    };
  }
}

class _FareEstimate extends StatelessWidget {
  const _FareEstimate({
    required this.transportType,
    required this.routeEstimate,
    required this.isCalculatingRoute,
    required this.routeError,
    required this.onRefreshRoute,
  });

  final String transportType;
  final TransportRouteEstimate? routeEstimate;
  final bool isCalculatingRoute;
  final String? routeError;
  final VoidCallback onRefreshRoute;

  @override
  Widget build(BuildContext context) {
    final rate = TransportFareCalculator.rateFor(transportType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFF416FDF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FareTitle(
                  routeEstimate: routeEstimate,
                  isCalculatingRoute: isCalculatingRoute,
                  routeError: routeError,
                ),
                Text(
                  'R${rate.baseFare.toStringAsFixed(0)} base + R${rate.perKm.toStringAsFixed(0)}/km + R${rate.perMinute.toStringAsFixed(2)}/min',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                if (routeEstimate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${routeEstimate!.distanceKm.toStringAsFixed(1)} km - ${routeEstimate!.durationMinutes} min',
                    style: const TextStyle(
                      color: Color(0xFF416FDF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: isCalculatingRoute ? null : onRefreshRoute,
            icon: isCalculatingRoute
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _FareTitle extends StatelessWidget {
  const _FareTitle({
    required this.routeEstimate,
    required this.isCalculatingRoute,
    required this.routeError,
  });

  final TransportRouteEstimate? routeEstimate;
  final bool isCalculatingRoute;
  final String? routeError;

  @override
  Widget build(BuildContext context) {
    if (isCalculatingRoute) {
      return const Text(
        'Calculating route and fare...',
        style: TextStyle(fontWeight: FontWeight.w900),
      );
    }

    if (routeError != null) {
      return Text(
        routeError!,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w900,
        ),
      );
    }

    if (routeEstimate == null) {
      return const Text(
        'Enter pickup and dropoff',
        style: TextStyle(fontWeight: FontWeight.w900),
      );
    }

    return Text(
      'Estimated fare: R${routeEstimate!.estimatedFare.toStringAsFixed(0)}',
      style: const TextStyle(fontWeight: FontWeight.w900),
    );
  }
}

class _TransportField extends StatelessWidget {
  const _TransportField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
