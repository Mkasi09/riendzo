import 'package:cloud_firestore/cloud_firestore.dart';

class TripBookingService {
  const TripBookingService._();

  static DocumentReference<Map<String, dynamic>> bookingRef({
    required String tripId,
    required String userId,
  }) => FirebaseFirestore.instance
      .collection('trip_bookings')
      .doc('${tripId}_$userId');

  static Future<void> ensureConfirmedBooking({
    required String tripId,
    required String userId,
    required Map<String, dynamic> trip,
  }) {
    return bookingRef(tripId: tripId, userId: userId).set({
      'tripId': tripId,
      'userId': userId,
      'tripName': trip['tripName']?.toString() ?? 'Trip',
      'destination': trip['destination']?.toString() ?? '',
      'startDate': trip['startDate']?.toString() ?? '',
      'endDate': trip['endDate']?.toString() ?? '',
      'price': trip['budget']?.toString() ?? '',
      'currency': 'ZAR',
      'status': 'confirmed',
      'paymentStatus': 'arrange_with_host',
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> cancelBooking({
    required String tripId,
    required String userId,
  }) async {
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
    final booking = bookingRef(tripId: tripId, userId: userId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final tripSnapshot = await transaction.get(tripRef);
      if (!tripSnapshot.exists) return;
      final data = tripSnapshot.data()!;
      final joinedUsers = List<Map<String, dynamic>>.from(
        (data['joinedUsers'] as List? ?? []).whereType<Map>(),
      );
      transaction.update(tripRef, {
        'joinedUsers': joinedUsers
            .where((person) => person['userId']?.toString() != userId)
            .toList(),
      });
      transaction.set(booking, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
