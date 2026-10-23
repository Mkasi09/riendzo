import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

enum PayfastPaymentMethod { card, applePay, googlePay, instantEft, capitecPay }

extension PayfastPaymentMethodLabel on PayfastPaymentMethod {
  String get value => switch (this) {
    PayfastPaymentMethod.card => 'card',
    PayfastPaymentMethod.applePay => 'apple_pay',
    PayfastPaymentMethod.googlePay => 'google_pay',
    PayfastPaymentMethod.instantEft => 'instant_eft',
    PayfastPaymentMethod.capitecPay => 'capitec_pay',
  };

  String get label => switch (this) {
    PayfastPaymentMethod.card => 'Card',
    PayfastPaymentMethod.applePay => 'Apple Pay',
    PayfastPaymentMethod.googlePay => 'Google Pay',
    PayfastPaymentMethod.instantEft => 'Instant EFT',
    PayfastPaymentMethod.capitecPay => 'Capitec Pay',
  };
}

class PayfastPaymentService {
  PayfastPaymentService({http.Client? client})
    : _client = client ?? http.Client();

  static const _checkoutEndpoint = String.fromEnvironment(
    'PAYFAST_CHECKOUT_ENDPOINT',
    defaultValue:
        'https://us-central1-riendzo.cloudfunctions.net/createPayfastCheckout',
  );

  final http.Client _client;

  Future<void> deferTransportPayment({
    required String transportRequestId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before requesting transport.');
    final firestore = FirebaseFirestore.instance;
    final requestRef = firestore
        .collection('transport_requests')
        .doc(transportRequestId);
    await firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestRef);
      final data = request.data();
      if (!request.exists || data == null || data['userId'] != user.uid) {
        throw StateError('Transport request was not found.');
      }
      final paymentStatus = data['paymentStatus']?.toString();
      if (![
        'awaiting_payment',
        'payment_failed',
        'checkout_started',
      ].contains(paymentStatus)) {
        return;
      }
      transaction.update(requestRef, {
        'status': 'pending',
        'paymentStatus': 'pay_on_completion',
        'paymentFallbackAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final tripId = data['tripId']?.toString() ?? '';
      if (tripId.isNotEmpty) {
        transaction.update(firestore.collection('trips').doc(tripId), {
          'transport.status': 'requested',
          'transport.paymentStatus': 'pay_on_completion',
          'transport.paymentFallbackAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> startTransportPayment({
    required String transportRequestId,
    required PayfastPaymentMethod preferredMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before making a payment.');
    final token = await user.getIdToken();
    final response = await _client.post(
      Uri.parse(_checkoutEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'transportRequestId': transportRequestId,
        'preferredMethod': preferredMethod.value,
      }),
    );
    final body = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(body['error']?.toString() ?? 'Could not start payment.');
    }
    final checkoutUrl = body['checkoutUrl']?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw StateError('Payfast did not return a checkout link.');
    }
    final opened = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('Could not open the Payfast checkout.');
  }
}
