const crypto = require('crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { HttpsError, onCall, onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

initializeApp();
const db = getFirestore();

const merchantId = defineSecret('PAYFAST_MERCHANT_ID');
const merchantKey = defineSecret('PAYFAST_MERCHANT_KEY');
const passphrase = defineSecret('PAYFAST_PASSPHRASE');
const functionBaseUrl = 'https://us-central1-riendzo.cloudfunctions.net';
const payfastBaseUrl = 'https://sandbox.payfast.co.za';

const methodCodes = {
  card: 'cc',
  apple_pay: 'ap',
  google_pay: 'gp',
  instant_eft: 'ef',
  capitec_pay: 'cp',
};

function parameterString(data, phrase) {
  const values = Object.entries(data)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}=${encodeURIComponent(String(value).trim()).replace(/%20/g, '+')}`);
  if (phrase) values.push(`passphrase=${encodeURIComponent(phrase.trim()).replace(/%20/g, '+')}`);
  return values.join('&');
}

function signature(data, phrase) {
  return crypto.createHash('md5').update(parameterString(data, phrase)).digest('hex');
}

function htmlCheckout(fields) {
  const inputs = Object.entries(fields)
    .map(([key, value]) => `<input type="hidden" name="${key}" value="${String(value).replace(/&/g, '&amp;').replace(/"/g, '&quot;')}">`)
    .join('');
  return `<!doctype html><html><body><form id="payfast" method="post" action="${payfastBaseUrl}/eng/process">${inputs}</form><script>document.getElementById('payfast').submit()</script></body></html>`;
}

exports.createPayfastCheckout = onCall({ region: 'us-central1' }, async () => {
  throw new HttpsError(
    'failed-precondition',
    'Please update Riendzo to use Sandbox checkout.',
  );
});

exports.createPayfastCheckoutHttp = onRequest(
  {
    region: 'us-central1',
    cors: true,
    secrets: [merchantId, merchantKey, passphrase],
  },
  async (request, response) => {
    try {
      const auth = request.get('authorization') || '';
      if (!auth.startsWith('Bearer ')) {
        response.status(401).json({ error: 'Sign in before paying.' });
        return;
      }
      const decoded = await getAuth().verifyIdToken(auth.substring(7));
      const requestId = String(request.body?.transportRequestId || '');
      const preferredMethod = String(request.body?.preferredMethod || 'card');
      const paymentMethod = methodCodes[preferredMethod];
      if (!requestId || !paymentMethod) {
        response.status(400).json({ error: 'Invalid payment request.' });
        return;
      }
      const transportRef = db.collection('transport_requests').doc(requestId);
      const transport = await transportRef.get();
      const data = transport.data();
      if (!transport.exists || data.userId !== decoded.uid) {
        response.status(404).json({ error: 'Transport request was not found.' });
        return;
      }
      if (!['awaiting_payment', 'payment_failed', 'checkout_started'].includes(data.paymentStatus)) {
        response.status(409).json({ error: 'This transport request has already been paid.' });
        return;
      }
      const amount = Number(data.totalEstimatedFare ?? data.estimatedFare ?? 0);
      if (!Number.isFinite(amount) || amount <= 0) {
        response.status(400).json({ error: 'A valid transport estimate is required.' });
        return;
      }
      const checkoutRef = db.collection('payfast_checkout_sessions').doc();
      const payload = {
        merchant_id: merchantId.value(),
        merchant_key: merchantKey.value(),
        return_url: `${functionBaseUrl}/payfastPaymentReturn`,
        cancel_url: `${functionBaseUrl}/payfastPaymentCancel`,
        notify_url: `${functionBaseUrl}/payfastItn`,
        name_first: decoded.name || data.riderName || 'Riendzo traveler',
        email_address: decoded.email || '',
        m_payment_id: requestId,
        amount: amount.toFixed(2),
        item_name: `Riendzo transport · ${data.tripName || requestId}`,
        item_description: 'Transport estimate. Final receipt is available after the trip.',
        payment_method: paymentMethod,
        custom_str1: data.tripId || '',
        custom_str2: requestId,
      };
      payload.signature = signature(payload, passphrase.value());
      await checkoutRef.set({
        transportRequestId: requestId,
        uid: decoded.uid,
        payload,
        expiresAt: Timestamp.fromMillis(Date.now() + 15 * 60 * 1000),
        createdAt: FieldValue.serverTimestamp(),
      });
      await transportRef.update({
        paymentStatus: 'checkout_started',
        paymentMethodPreference: preferredMethod,
        payfastCheckoutSessionId: checkoutRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      });
      response.json({ checkoutUrl: `${request.protocol}://${request.get('host')}/payfastCheckout?session=${checkoutRef.id}` });
    } catch (error) {
      console.error('createPayfastCheckout failed', error);
      response.status(500).json({ error: 'Could not start payment.' });
    }
  },
);

exports.payfastCheckout = onRequest({ region: 'us-central1' }, async (request, response) => {
  const sessionId = String(request.query.session || '');
  const session = await db.collection('payfast_checkout_sessions').doc(sessionId).get();
  const data = session.data();
  if (!session.exists || !data || data.expiresAt.toMillis() < Date.now()) {
    response.status(410).send('This checkout link has expired. Return to Riendzo and try again.');
    return;
  }
  response.set('Content-Type', 'text/html; charset=utf-8').send(htmlCheckout(data.payload));
});

exports.payfastPaymentReturn = onRequest({ region: 'us-central1' }, (request, response) => {
  response
    .set('Content-Type', 'text/html; charset=utf-8')
    .send('<!doctype html><title>Payment received</title><h1>Payment received</h1><p>Return to Riendzo. We are confirming your payment.</p>');
});

exports.payfastPaymentCancel = onRequest({ region: 'us-central1' }, (request, response) => {
  response
    .set('Content-Type', 'text/html; charset=utf-8')
    .send('<!doctype html><title>Payment cancelled</title><h1>Payment cancelled</h1><p>No payment was completed. Return to Riendzo to try again.</p>');
});

exports.payfastItn = onRequest(
  { region: 'us-central1', secrets: [merchantId] },
  async (request, response) => {
    try {
      if (request.method !== 'POST' || !Buffer.isBuffer(request.rawBody)) {
        response.status(400).send('Invalid payment notification');
        return;
      }

      const validation = await fetch(`${payfastBaseUrl}/eng/query/validate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: request.rawBody,
        signal: AbortSignal.timeout(10000),
      });
      if (!validation.ok) {
        console.error('Payfast ITN validation request failed', validation.status);
        response.status(502).send('Could not validate payment notification');
        return;
      }
      if ((await validation.text()).trim() !== 'VALID') {
        response.status(400).send('Invalid payment notification');
        return;
      }

      const payload = request.body || {};
      const requestId = String(payload.m_payment_id || '');
      if (!requestId) {
        response.status(400).send('Missing payment reference');
        return;
      }
      if (String(payload.merchant_id || '') !== merchantId.value()) {
        response.status(400).send('Incorrect merchant');
        return;
      }

      const transportRef = db.collection('transport_requests').doc(requestId);
      const outcome = await db.runTransaction(async (transaction) => {
        const transport = await transaction.get(transportRef);
        if (!transport.exists) return 'unknown';
        const data = transport.data() || {};
        const expectedAmount = Number(
          data.totalEstimatedFare ?? data.estimatedFare ?? 0,
        ).toFixed(2);
        if (Number(payload.amount_gross || 0).toFixed(2) !== expectedAmount) {
          return 'incorrect_amount';
        }

        const tripId = data.tripId;
        const tripRef = tripId ? db.collection('trips').doc(tripId) : null;
        const trip = tripRef ? await transaction.get(tripRef) : null;
        const paid = payload.payment_status === 'COMPLETE';
        if (data.paymentStatus === 'paid' && !paid) return 'already_paid';

        const paymentStatus = paid ? 'paid' : 'payment_failed';
        const paymentId = String(payload.pf_payment_id || '');
        const paymentMethod = String(payload.payment_method || '');
        const paymentAmount = Number(payload.amount_gross || 0);
        const updates = {
          paymentStatus,
          paymentId,
          paymentMethod,
          paymentAmount,
          paymentUpdatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (paid) updates.status = 'pending';
        transaction.update(transportRef, updates);

        if (tripRef && trip && trip.exists) {
          transaction.update(tripRef, {
            'transport.paymentStatus': paymentStatus,
            'transport.paymentId': paymentId,
            'transport.paymentMethod': paymentMethod,
            'transport.paymentAmount': paymentAmount,
            'transport.status': paid ? 'requested' : 'awaiting_payment',
          });
        }
        return null;
      });
      if (outcome === 'unknown') {
        response.status(404).send('Unknown payment');
        return;
      }
      if (outcome === 'incorrect_amount') {
        response.status(400).send('Incorrect amount');
        return;
      }
      response.status(200).send('OK');
    } catch (error) {
      console.error('payfastItn failed', error);
      response.status(500).send('Unable to process payment notification');
    }
  },
);
