# PayFast sandbox

Riendzo's organizer-only transport checkout uses PayFast's sandbox. The amount
comes from the trip's estimated transport fare and is verified by the Cloud
Function ITN handler before the trip is marked paid. Travelers are not charged.

Set the credentials from a PayFast sandbox merchant account as Firebase
secrets; do not put them in Flutter configuration or commit them:

```powershell
firebase functions:secrets:set PAYFAST_MERCHANT_ID
firebase functions:secrets:set PAYFAST_MERCHANT_KEY
firebase functions:secrets:set PAYFAST_PASSPHRASE
firebase deploy --only functions
```

The functions use `us-central1` and the Firebase project selected by
`.firebaserc`. Checkout and ITN validation are pinned to
`sandbox.payfast.co.za`; they do not use the live PayFast endpoints.

Run the pure helper tests with `npm test` from this directory.
