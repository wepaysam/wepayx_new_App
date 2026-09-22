# NEX Wallet — Flutter Mobile App

Flutter frontend for the NEX wallet. It talks to **your backend API only** — no direct `nex-wallet` dependency on the device.

The original web UI lives in `../frontend/public/`. This app mirrors the same flows: auth, balances, receive, send, swap, markets, and activity.

## Requirements

- Flutter 3.x (Dart 3.11+)
- A backend that exposes the wallet REST API (see below)

## Quick start

```powershell
cd mobile
flutter pub get
flutter run
```

Set your API URL on the login screen or in **Profile → API connection**.

Build with a fixed API URL:

```powershell
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

## Project layout

```text
mobile/
├── lib/
│   ├── config/api_config.dart      # Base URL + optional Bearer token
│   ├── services/
│   │   ├── api_client.dart         # Dio HTTP client (cookies + Bearer)
│   │   └── wallet_api.dart         # All wallet endpoints
│   ├── models/                     # JSON models
│   ├── providers/wallet_provider.dart
│   └── screens/                    # UI screens
└── pubspec.yaml
```

## Backend API contract

Your API should implement the same endpoints the web app uses. Minimum set for the Flutter app:

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/health` | No | Health check |
| POST | `/api/signup` | No | Create account |
| POST | `/api/login` | No | Login |
| POST | `/api/logout` | Yes | Logout |
| GET | `/api/me` | Optional | Current session |
| GET | `/api/wallet` | Yes | Wallet + balances + activity |
| GET | `/api/crypto-prices` | No | Live prices |
| GET | `/api/fees` | Optional | Fee structure |
| POST | `/api/deposit-address` | Yes | Deposit address + QR data |
| POST | `/api/withdrawal-request` | Yes | Send / withdraw |
| POST | `/api/swap-estimate` | Yes | Swap quote |
| POST | `/api/swap-exchange` | Yes | Create swap |
| GET | `/api/popup-notifications` | Yes | Deposit/withdraw alerts |
| POST | `/api/notifications/popup` | API key | Telegram popup; blocked users need `force=true` |

### Auth

The web server uses **HttpOnly session cookies** (`futre_session`). The Flutter client persists cookies automatically.

If your API uses **JWT**, set a Bearer token in Profile → **Bearer token (optional)**.

### Example responses

**Login / signup**

```json
{
  "user": { "id": 1, "email": "user@example.com", "name": "Alex" },
  "wallet": {
    "addresses": { "ERC20": "0x...", "TRC20": "T..." },
    "balances": [{ "asset": "USDT", "network": "TRC20", "balance": "100" }],
    "activity": [],
    "pendingWithdrawal": null
  },
  "events": []
}
```

**Deposit address**

```json
{
  "asset": "USDT",
  "network": "TRC20",
  "depositAddress": "T..."
}
```

**Withdrawal**

```json
{
  "id": 12,
  "status": "processing",
  "asset": "USDT",
  "network": "TRC20",
  "amount": "50",
  "fee": 3,
  "netAmount": 47
}
```

## Local development notes

| Platform | localhost URL |
|----------|----------------|
| Windows / iOS simulator | `http://127.0.0.1:19120` |
| Android emulator | `http://10.0.2.2:19120` |
| Physical device | Your machine's LAN IP, e.g. `http://192.168.1.10:19120` |

For Android cleartext HTTP, ensure your backend or Android network config allows it in debug builds.

## What changed vs the old web stack

| Before | Now |
|--------|-----|
| HTML/React in `frontend/public/` | Flutter in `mobile/` |
| Node server imports `../nex-wallet` | Mobile calls **your API** over HTTP |
| Server serves UI + API | UI-only client; backend is separate |

The `frontend/` folder is kept as reference for API shapes and UI behavior.
