# Firebase / FCM setup for NEX Wallet

## Why you didn't enter Android package name

When you choose **Flutter** in Firebase Console, you **don't** register Android manually in the browser.

Instead, **FlutterFire CLI** reads your app from the project and registers:

| Field | Value (from this repo) |
|-------|------------------------|
| Android package | `com.nexwallet.nex_wallet` |
| Project | `nex-wallet-c56eb` |

It then creates:

- `lib/firebase_options.dart`
- `android/app/google-services.json`

## One-time setup (run on your PC)

Open PowerShell in `mobile/` and run:

```powershell
.\tool\setup_firebase.ps1
```

Or manually:

```powershell
dart pub global activate flutterfire_cli
firebase login
cd mobile
flutterfire configure --project=nex-wallet-c56eb --platforms=android --yes
flutter pub get
```

## Manual alternative (if CLI fails)

1. Firebase Console → **Project settings** → **Add app** → **Android**
2. Package name: `com.nexwallet.nex_wallet`
3. Download `google-services.json` → `mobile/android/app/google-services.json`
4. Still run `flutterfire configure` to generate `firebase_options.dart`

## What's already wired in the app

- `firebase_core` + `firebase_messaging` + local notifications
- `PushService` — permission, FCM token, foreground/background handlers
- Token sent to API: `POST /api/device-token` (after login)
- In-app popup polling every 4s while app is open

## Backend note

Your Futre API must accept `POST /api/device-token` and send FCM when deposits/withdrawals complete. Until that exists, you'll get in-app popups while the app is open, but not system push when the app is closed.

## Test push

After setup, copy the FCM token from debug console log (`PushService: FCM token ...`) and send a test message from Firebase Console → **Messaging**.
