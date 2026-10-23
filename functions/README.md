# Riendzo Payfast Functions

Deploy these functions before releasing transport payments. They create a signed, hosted Payfast checkout and accept Payfast ITN callbacks. Merchant credentials remain Firebase secrets and are never included in the Flutter app.

Set these secrets with the Firebase CLI:

```
firebase functions:secrets:set PAYFAST_MERCHANT_ID
firebase functions:secrets:set PAYFAST_MERCHANT_KEY
firebase functions:secrets:set PAYFAST_PASSPHRASE
```

Configure Payfast’s ITN notification URL as `https://us-central1-riendzo.cloudfunctions.net/payfastItn`. The deployed functions host the payment return and cancellation pages.

Then install and deploy:

```
cd functions
npm install
firebase deploy --only functions
```
