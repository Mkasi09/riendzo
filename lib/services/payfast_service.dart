import 'package:cloud_functions/cloud_functions.dart';

class PayFastService {
  const PayFastService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  static Future<Uri> createTransportCheckout({required String tripId}) async {
    final result = await _functions
        .httpsCallable('createPayfastTransportPayment')
        .call<Map<String, dynamic>>({'tripId': tripId});
    final checkoutUrl = result.data['checkoutUrl'];
    final uri = checkoutUrl is String ? Uri.tryParse(checkoutUrl) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'sandbox.payfast.co.za' ||
        uri.path != '/eng/process') {
      throw StateError('PayFast returned an invalid sandbox checkout URL.');
    }
    return uri;
  }
}
