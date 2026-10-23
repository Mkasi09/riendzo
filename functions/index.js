const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');
const { HttpsError, onCall, onRequest } = require('firebase-functions/v2/https');
const {
  createPayFastSignature,
  formatZarAmount,
} = require('./payfast_utils');

initializeApp();

const db = getFirestore();
const merchantId = defineSecret('PAYFAST_MERCHANT_ID');
const merchantKey = defineSecret('PAYFAST_MERCHANT_KEY');
const passphrase = defineSecret('PAYFAST_PASSPHRASE');
const region = 'us-central1';
const sandboxProcessUrl = 'https://sandbox.payfast.co.za/eng/process';
const sandboxValidateUrl = 'https://sandbox.payfast.co.za/eng/query/validate';

function functionUrl(name, projectId) {
  return `https://${region}-${projectId}.cloudfunctions.net/${name}`;
}

function sameAmount(received, expected) {
  const amount = Number(received);
  return Number.isFinite(amount) && amount.toFixed(2) === expected;
}

exports.createPayfastTransportPayment = onCall(
  { region, secrets: [merchantId, merchantKey, passphrase] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to pay the transport fee.');
    }

    const tripId = request.data?.tripId;
    if (typeof tripId !== 'string' || tripId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'A trip ID is required.');
    }

    const tripRef = db.collection('trips').doc(tripId);
    const candidatePaymentRef = db.collection('payfastPayments').doc();
    let paymentId;
    let amount;
    let tripName;

    await db.runTransaction(async (transaction) => {
      const tripSnapshot = await transaction.get(tripRef);
      if (!tripSnapshot.exists) {
        throw new HttpsError('not-found', 'This trip could not be found.');
      }

      const trip = tripSnapshot.data();
      if (trip.userId !== request.auth.uid) {
        throw new HttpsError(
          'permission-denied',
          'Only the trip organizer can pay its transport fee.',
        );
      }

      const transport = trip.transport;
      if (!transport || trip.transportRequested !== true) {
        throw new HttpsError(
          'failed-precondition',
          'This trip does not have a transport request.',
        );
      }
      if (transport.status === 'completed' || transport.status === 'cancelled') {
        throw new HttpsError(
          'failed-precondition',
          'This transport request is no longer active.',
        );
      }
      if ((transport.currency || 'ZAR') !== 'ZAR') {
        throw new HttpsError(
          'failed-precondition',
          'Only South African rand transport fees are supported.',
        );
      }

      try {
        amount = formatZarAmount(transport.estimatedFare);
      } catch (error) {
        throw new HttpsError(
          'failed-precondition',
          'This transport request has no valid estimated fee.',
        );
      }

      if (transport.paymentStatus === 'paid') {
        throw new HttpsError(
          'already-exists',
          'This transport fee has already been paid.',
        );
      }

      if (transport.paymentStatus === 'pending' && transport.paymentId) {
        const existingPaymentRef = db
          .collection('payfastPayments')
          .doc(transport.paymentId);
        const existingPayment = await transaction.get(existingPaymentRef);
        if (
          existingPayment.exists &&
          existingPayment.data().status === 'pending'
        ) {
          if (existingPayment.data().amount !== amount) {
            throw new HttpsError(
              'failed-precondition',
              'The transport fee changed while a payment is pending. Complete or cancel the existing PayFast checkout before trying again.',
            );
          }
          paymentId = existingPayment.id;
        }
      }

      if (!paymentId) {
        paymentId = candidatePaymentRef.id;
        transaction.create(candidatePaymentRef, {
          tripId,
          organizerId: request.auth.uid,
          amount,
          currency: 'ZAR',
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.update(tripRef, {
          'transport.paymentId': paymentId,
          'transport.paymentAmount': amount,
          'transport.paymentCurrency': 'ZAR',
          'transport.paymentStatus': 'pending',
          'transport.paymentUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      tripName = String(trip.tripName || trip.destination || 'Trip').slice(0, 80);
    });

    const projectId = process.env.GCLOUD_PROJECT;
    if (!projectId) {
      throw new HttpsError(
        'failed-precondition',
        'The Firebase project is not configured for PayFast.',
      );
    }

    const baseUrl = functionUrl('', projectId).replace(/\/$/, '');
    const params = {
      merchant_id: merchantId.value(),
      merchant_key: merchantKey.value(),
      return_url: `${baseUrl}/payfastReturn?result=success`,
      cancel_url: `${baseUrl}/payfastReturn?result=cancelled`,
      notify_url: functionUrl('payfastItn', projectId),
      m_payment_id: paymentId,
      amount,
      item_name: `Transport fee - ${tripName}`,
      custom_str1: paymentId,
      custom_str2: tripId,
    };
    if (request.auth.token.email) {
      params.email_address = request.auth.token.email;
    }
    params.signature = createPayFastSignature(params, passphrase.value());

    const checkoutUrl = new URL(sandboxProcessUrl);
    for (const [key, value] of Object.entries(params)) {
      checkoutUrl.searchParams.set(key, value);
    }
    return { checkoutUrl: checkoutUrl.toString() };
  },
);

exports.payfastItn = onRequest(
  { region, secrets: [merchantId, passphrase] },
  async (request, response) => {
    if (request.method !== 'POST') {
      response.status(405).send('Method not allowed');
      return;
    }

    const rawBody = request.rawBody?.toString('utf8') || '';
    const params = Object.fromEntries(new URLSearchParams(rawBody).entries());
    const configuredMerchantId = merchantId.value();
    const configuredPassphrase = passphrase.value();
    if (
      params.merchant_id !== configuredMerchantId ||
      !params.signature ||
      params.signature !== createPayFastSignature(params, configuredPassphrase)
    ) {
      response.status(400).send('Invalid payment notification');
      return;
    }

    try {
      const validationResponse = await fetch(sandboxValidateUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: rawBody,
        signal: AbortSignal.timeout(10000),
      });
      if (
        !validationResponse.ok ||
        (await validationResponse.text()).trim() !== 'VALID'
      ) {
        response.status(400).send('Payment notification could not be validated');
        return;
      }

      const paymentId = params.custom_str1;
      const tripId = params.custom_str2;
      if (!paymentId || !tripId || params.m_payment_id !== paymentId) {
        response.status(400).send('Invalid payment reference');
        return;
      }

      const paymentRef = db.collection('payfastPayments').doc(paymentId);
      const tripRef = db.collection('trips').doc(tripId);
      await db.runTransaction(async (transaction) => {
        const paymentSnapshot = await transaction.get(paymentRef);
        const tripSnapshot = await transaction.get(tripRef);
        if (!paymentSnapshot.exists || !tripSnapshot.exists) {
          throw new Error('The payment or trip record does not exist.');
        }

        const payment = paymentSnapshot.data();
        const trip = tripSnapshot.data();
        const transport = trip.transport || {};
        if (
          payment.tripId !== tripId ||
          payment.organizerId !== trip.userId ||
          payment.amount !== formatZarAmount(params.amount_gross) ||
          !sameAmount(params.amount_gross, payment.amount)
        ) {
          throw new Error('The payment details do not match the trip.');
        }
        if (payment.status === 'complete') return;
        if (transport.paymentId !== paymentId) {
          throw new Error('This payment is no longer current for the trip.');
        }

        if (params.payment_status === 'COMPLETE') {
          transaction.update(paymentRef, {
            status: 'complete',
            pfPaymentId: params.pf_payment_id || null,
            completedAt: FieldValue.serverTimestamp(),
          });
          transaction.update(tripRef, {
            'transport.paymentStatus': 'paid',
            'transport.paymentPaidAt': FieldValue.serverTimestamp(),
            'transport.paymentReference': params.pf_payment_id || paymentId,
          });
        } else if (params.payment_status === 'FAILED') {
          transaction.update(paymentRef, {
            status: 'failed',
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.update(tripRef, {
            'transport.paymentStatus': 'failed',
            'transport.paymentUpdatedAt': FieldValue.serverTimestamp(),
          });
        } else if (params.payment_status !== 'PENDING') {
          throw new Error('Unsupported PayFast payment status.');
        }
      });

      response.status(200).send('OK');
    } catch (error) {
      console.error('PayFast ITN processing failed', error);
      response.status(500).send('Payment notification processing failed');
    }
  },
);

exports.payfastReturn = onRequest({ region }, (request, response) => {
  const message =
    request.query.result === 'cancelled'
      ? 'The PayFast checkout was cancelled. You can return to Riendzo and try again.'
      : 'PayFast received your checkout. Return to Riendzo; the transport fee will show as paid after secure confirmation.';
  response.set('Cache-Control', 'no-store');
  response.status(200).type('html').send(
    `<!doctype html>
<html lang="en">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Riendzo PayFast</title>
  <body style="font:16px system-ui,sans-serif;max-width:34rem;margin:12vh auto;padding:0 1rem;color:#182033">
    <h1>Riendzo transport payment</h1>
    <p>${message}</p>
    <p>You can close this page and return to the Riendzo app.</p>
  </body>
</html>`,
  );
});
