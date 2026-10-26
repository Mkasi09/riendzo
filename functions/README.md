# Riendzo Payfast Functions

Deploy these functions before releasing transport payments. They create a signed, hosted Payfast checkout and accept Payfast ITN callbacks. Merchant credentials remain Firebase secrets and are never included in the Flutter app.

Set these secrets with the Firebase CLI:

```
firebase functions:secrets:set PAYFAST_MERCHANT_ID
firebase functions:secrets:set PAYFAST_MERCHANT_KEY
firebase functions:secrets:set PAYFAST_PASSPHRASE
```

Configure Payfast’s ITN notification URL as `https://us-central1-riendzo.cloudfunctions.net/payfastItn`. The deployed functions host the payment return and cancellation pages.

Checkout and ITN validation use Payfast Sandbox. Use matching Sandbox merchant credentials. ITN notifications are verified by forwarding Payfast’s original request body to the Sandbox validation endpoint before updating a transport payment.

The HTTPS checkout endpoint is `createPayfastCheckoutHttp`. The legacy callable endpoint is disabled to prevent older app builds from opening a non-Sandbox checkout; install a build configured to use the HTTPS endpoint.

Then install and deploy:

```
cd functions
npm install
firebase deploy --only functions
```
