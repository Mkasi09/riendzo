// lib/models/pigeon_usr_details.dart

class PigeonUsrDetails {
  final String name;
  final String email;

  PigeonUsrDetails({required this.name, required this.email});

  factory PigeonUsrDetails.fromMap(Map<String, dynamic> map) {
    return PigeonUsrDetails(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
    );
  }
}
