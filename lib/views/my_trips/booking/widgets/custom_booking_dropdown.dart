import 'package:flutter/material.dart';

class CustomBookingDropdown extends StatelessWidget {
  final List<String> interests;
  final String? selectedInterest;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final String hintText;

  const CustomBookingDropdown({
    super.key,
    required this.interests,
    this.selectedInterest,
    required this.onChanged,
    required this.icon,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: Row(
              children: [
                Icon(icon, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Text(hintText),
              ],
            ),
            value: selectedInterest,
            isExpanded: true,
            items: interests.map((String interest) {
              return DropdownMenuItem<String>(
                value: interest,
                child: Text(interest),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
