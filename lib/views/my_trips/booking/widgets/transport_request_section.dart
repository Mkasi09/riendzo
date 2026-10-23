import 'package:flutter/material.dart';
import 'package:riendzo/services/transport_fare_calculator.dart';

class TransportRequestSection extends StatelessWidget {
  const TransportRequestSection({
    super.key,
    required this.enabled,
    required this.transportType,
    required this.returnTrip,
    required this.pickupController,
    required this.pickupTimeController,
    required this.returnDateController,
    required this.returnTimeController,
    required this.returnPickupController,
    required this.dropoffController,
    required this.passengersController,
    required this.noteController,
    required this.routeEstimate,
    required this.isCalculatingRoute,
    required this.routeError,
    required this.returnRouteEstimate,
    required this.isCalculatingReturnRoute,
    required this.returnRouteError,
    required this.onEnabledChanged,
    required this.onTransportTypeChanged,
    required this.onReturnTripChanged,
    required this.onRefreshRoute,
    required this.onSelectPickupTime,
    required this.onSelectReturnDate,
    required this.onSelectReturnTime,
  });

  final bool enabled;
  final String transportType;
  final bool returnTrip;
  final TextEditingController pickupController;
  final TextEditingController pickupTimeController;
  final TextEditingController returnDateController;
  final TextEditingController returnTimeController;
  final TextEditingController returnPickupController;
  final TextEditingController dropoffController;
  final TextEditingController passengersController;
  final TextEditingController noteController;
  final TransportRouteEstimate? routeEstimate;
  final bool isCalculatingRoute;
  final String? routeError;
  final TransportRouteEstimate? returnRouteEstimate;
  final bool isCalculatingReturnRoute;
  final String? returnRouteError;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onTransportTypeChanged;
  final ValueChanged<bool> onReturnTripChanged;
  final VoidCallback onRefreshRoute;
  final VoidCallback onSelectPickupTime;
  final VoidCallback onSelectReturnDate;
  final VoidCallback onSelectReturnTime;

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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.arrow_forward_rounded),
                    label: Text('Pickup only'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.sync_alt_rounded),
                    label: Text('Return transport'),
                  ),
                ],
                selected: {returnTrip},
                onSelectionChanged: (selection) =>
                    onReturnTripChanged(selection.first),
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
              if (returnTrip) ...[
                const SizedBox(height: 10),
                _TransportField(
                  controller: returnPickupController,
                  icon: Icons.location_on_outlined,
                  label: 'Return pickup location',
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    'Suggested from your drop-off. You can change it; the driver will confirm it with you.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onSelectReturnDate,
                  child: AbsorbPointer(
                    child: _TransportField(
                      controller: returnDateController,
                      icon: Icons.calendar_today_outlined,
                      label: 'Return date',
                      readOnly: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onSelectReturnTime,
                  child: AbsorbPointer(
                    child: _TransportField(
                      controller: returnTimeController,
                      icon: Icons.access_time,
                      label: 'Return pickup time',
                      readOnly: true,
                    ),
                  ),
                ),
              ],
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
                returnTrip: returnTrip,
                routeEstimate: routeEstimate,
                isCalculatingRoute: isCalculatingRoute,
                routeError: routeError,
                returnRouteEstimate: returnRouteEstimate,
                isCalculatingReturnRoute: isCalculatingReturnRoute,
                returnRouteError: returnRouteError,
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
    required this.returnTrip,
    required this.routeEstimate,
    required this.isCalculatingRoute,
    required this.routeError,
    required this.returnRouteEstimate,
    required this.isCalculatingReturnRoute,
    required this.returnRouteError,
    required this.onRefreshRoute,
  });

  final String transportType;
  final bool returnTrip;
  final TransportRouteEstimate? routeEstimate;
  final bool isCalculatingRoute;
  final String? routeError;
  final TransportRouteEstimate? returnRouteEstimate;
  final bool isCalculatingReturnRoute;
  final String? returnRouteError;
  final VoidCallback onRefreshRoute;

  @override
  Widget build(BuildContext context) {
    final amount = routeEstimate == null
        ? null
        : routeEstimate!.estimatedFare +
              (returnTrip ? (returnRouteEstimate?.estimatedFare ?? 0) : 0);

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
                if (isCalculatingRoute)
                  const Text(
                    'Getting your amount...',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  )
                else if (routeError != null)
                  Text(
                    routeError!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else if (amount == null)
                  const Text(
                    'Enter pickup and dropoff',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  )
                else ...[
                  Text(
                    'Outbound estimate: R${routeEstimate!.estimatedFare.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (returnTrip)
                    if (isCalculatingReturnRoute)
                      const Text('Calculating return estimate…')
                    else if (returnRouteError != null)
                      Text(
                        returnRouteError!,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      )
                    else if (returnRouteEstimate != null)
                      Text(
                        'Return estimate: R${returnRouteEstimate!.estimatedFare.toStringAsFixed(0)}',
                      ),
                  if (!returnTrip || returnRouteEstimate != null)
                    Text(
                      'Total estimate: R${amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  const Text(
                    'Final fare may vary after the pickup is confirmed.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
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
