# Meteorologus mobile app

Flutter companion app for the Meteorologus IoT weather system: Firebase email/password auth, QR/MAC device claiming, live dashboard with forecast slides, and device unpairing — sharing the same Realtime Database, security rules and claim flow as the web dashboard ([`website/`](../website/README.md)).

## Features

- **Sign in / register** — Firebase Auth email + password.
- **Claim a node** — scan the node's QR code or type its 12-hex MAC (`ClaimDialog`); mints the pairing token the device picks up on its next connection.
- **Live dashboard** — current conditions, 3-day forecast slides, per-device selection for multi-node accounts.
- **Unpair a device** — header `link_off` button opens a confirmation for the selected device, then `ClaimService.unclaimDevice()` deletes the node's history (`devices/<MAC>`), revokes the claim token (`claimed_devices/<MAC>`) and removes it from your owned list, in that order (required by the security rules). The node notices the revoked claim on its next wake, erases its stored credentials itself, and returns to QR pairing mode.

## Run

```powershell
flutter pub get
flutter run
```

Firebase config is expected in `lib/config/firebase_options.dart`; the Realtime Database URL comes from `firebase_options.dart` (`databaseURL`).

Firebase Realtime DB schema and rules that this app writes to live in [`website/database.rules.json`](../website/database.rules.json).
