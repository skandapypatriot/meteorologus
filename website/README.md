# Website — Meteorologus Dashboard

A dependency-free single-page dashboard hosted on **Firebase Hosting**. It handles user accounts (Firebase Auth email/password), one-tap device claiming via QR code, and live monitoring of every claimed weather node — temperature, humidity, pressure, a temperature sparkline and forecast badges.

---

## Table of Contents

- [Features](#features)
- [Project Setup (Firebase)](#project-setup-firebase)
- [Add Your Firebase Config](#add-your-firebase-config)
- [Deploy](#deploy)
- [Security Rules](#security-rules)
- [User Guide](#user-guide)
  - [Registering an Account](#registering-an-account)
  - [Logging In](#logging-in)
  - [Claiming a Device](#claiming-a-device)
  - [Reading the Dashboard](#reading-the-dashboard)
- [Troubleshooting](#troubleshooting)

---

## Features

- 🔐 **Email/password auth** — sign-in and registration toggle within one form, session persists across reloads.
- 📷 **QR claiming** — unclaimed nodes display a QR linking to `https://<host>/<DEVICE_MAC>`; opening it pre-selects the device.
- 📊 **Live cards per device** — latest temp/humidity/pressure, sparkline of recent temperatures, Now/D1/D2/D3 forecast badges.
- 🪶 **No build step** — plain HTML/CSS/JS with the Firebase compat CDN SDK; edit and deploy.

## Project Setup (Firebase)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com/).
2. **Authentication → Sign-in method → enable *Email/Password***.
3. **Realtime Database → Create database** (note the URL).
4. **Project settings → Your apps → Web app** → copy the `firebaseConfig` object.
5. Install the CLI once: `npm install -g firebase-tools`.

## Add Your Firebase Config

The page loads `config.js` before anything else — create it inside `public/`:

```js
// public/config.js
const FIREBASE_CONFIG = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  databaseURL: "https://YOUR_PROJECT-default-rtdb.firebaseio.com",
  projectId: "YOUR_PROJECT",
  storageBucket: "YOUR_PROJECT.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
};
```

> `config.js` is intentionally not committed — each deployment supplies its own.

## Deploy

```powershell
cd website
firebase login
firebase use --add          # pick your project, alias it "default"
firebase deploy             # hosting + database rules together
firebase deploy --only hosting      # site only
firebase deploy --only database     # rules only
```

Your dashboard is served at `https://<project-id>.web.app` (a custom domain can be added in the console).

## Security Rules

Defined in [`database.rules.json`](database.rules.json):

| Path | Read | Write | Why |
| :--- | :--- | :--- | :--- |
| `/claimed_devices/<id>` | Public | Signed-in users | The device itself fetches its claim token over plain HTTPS |
| `/devices/<id>` | Public | Only if claimed | Sensor data is non-sensitive; writes require a completed claim |
| `/users/<uid>` | Owner only | Owner only | Each account sees only its own device list |

Claim tokens are random UUIDs minted client-side at claim time — knowing a MAC alone doesn't grant write access to anything beyond what rules already allow.

## User Guide

### Registering an Account

1. Open `https://<your-project>.web.app`.
2. Under **Sign in**, click **Create a new account** — the card switches to registration mode (*Create account*).
3. Enter your **email** and a **password** (minimum 6 characters).
4. Click **Create account**.
5. You're signed in immediately (no email verification); your empty device list appears.

### Logging In

1. Open `https://<your-project>.web.app`.
2. If the form is in registration mode, click **I already have an account** to switch back to **Sign in**.
3. Enter your **email** and **password**.
4. Click **Sign in** — your devices load automatically and stay signed in across visits.
5. Use **Sign out** (top-right) to end the session.

### Claiming a Device

One-time pairing between a physical node and your account:

1. Power the node near the Wi-Fi configured in its firmware. Unpaired nodes show **NOT PAIRED YET** and rotate between instructions and a QR code.
2. Scan the QR with your phone — it opens `https://<host>/<DEVICE_MAC>` with the device pre-selected. *(Manual entry works too: type the URL shown on screen.)*
3. Sign in or register if you haven't already.
4. Click **Claim device**. You'll see *"Done! The device will claim itself when it connects."*
5. Within ~30 seconds the node polls the cloud, stores its key, and starts syncing — the page flips to **Device claimed!**

### Reading the Dashboard

Each claimed device gets a card showing:

- **Device ID (MAC)** and a green *Updated <timestamp>* line
- Live **Temp / Humidity / Pressure** stats
- A **sparkline** of recent temperature readings
- Forecast badges: **Now · Day 1 · Day 2 · Day 3** mapped to labels like Sunny, Clear, Cloud, Light Rain, Rain
- **Refresh** re-reads the database on demand; nodes sync whenever they wake, so data updates roughly hourly

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| Blank page / `FIREBASE_CONFIG is not defined` | `public/config.js` missing or malformed — see [config section](#add-your-firebase-config) |
| `auth/operation-not-allowed` | Email/Password provider not enabled in Firebase Authentication |
| `auth/email-already-in-use` | That email is registered — switch to Sign in mode |
| `auth/weak-password` | Passwords must be ≥ 6 characters |
| Claim button does nothing | Ensure the URL contains a valid 12-hex-char MAC (open the link via QR) |
| "This device is already claimed" | Node is paired to another account; erase NVS on the device to re-pair |
| Dashboard shows no data | Device may be asleep — press its wake button or wait for the next timer wake |
| Permission denied reading devices | Redeploy rules: `firebase deploy --only database` |
