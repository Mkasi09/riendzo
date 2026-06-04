import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:riendzo/services/google_api_config.dart';

class SearchCard extends StatefulWidget {
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeSelected;
  final ValueChanged<String> onSearch;

  const SearchCard({
    super.key,
    required this.selectedDateRange,
    required this.onDateRangeSelected,
    required this.onSearch,
  });

  @override
  State<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<SearchCard> {
  final TextEditingController _destinationController = TextEditingController();
  String _selectedTripType = 'Solo';

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
    }
    return [];
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search for trips',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TypeAheadField<String>(
              controller: _destinationController,
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.place_outlined),
                    hintText: 'Enter a destination',
                  ),
                  onSubmitted: widget.onSearch,
                );
              },
              suggestionsCallback: (pattern) async {
                if (pattern.trim().isEmpty) return [];
                return getSuggestions(pattern);
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSelected: (suggestion) {
                _destinationController.text = suggestion;
                widget.onSearch(suggestion);
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final fields = [
                  _DateField(
                    label: 'Dates',
                    value: widget.selectedDateRange != null
                        ? '${dateFormat.format(widget.selectedDateRange!.start)} - ${dateFormat.format(widget.selectedDateRange!.end)}'
                        : 'Select dates',
                    onTap: _pickDateRange,
                  ),
                  _TripTypeField(
                    value: _selectedTripType,
                    onChanged: (value) {
                      setState(() => _selectedTripType = value ?? 'Solo');
                    },
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 12),
                      fields[1],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onSearch(_destinationController.text),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDateRange:
          widget.selectedDateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
    );

    if (pickedRange != null) {
      widget.onDateRangeSelected(pickedRange);
    }
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _TripTypeField extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _TripTypeField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Trip type',
        prefixIcon: Icon(Icons.group_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 'Solo', child: Text('Solo')),
        DropdownMenuItem(value: 'Group', child: Text('Group')),
      ],
      onChanged: onChanged,
    );
  }
}
