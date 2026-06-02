# Hermes iOS — installed ✓

The **iOS App** tab is now visible in your Hermes dashboard sidebar.

Open it to see your connection details and session token — everything you need to configure the iPhone app.

## Build the app

```bash
# Prerequisites: Flutter SDK + Xcode + an Apple Developer account
cd ~/.hermes/plugins/hermes-ios

flutter pub get
flutter run          # simulator
flutter run --release  # device
```

## Connect

1. Enter your Hermes **host**, **port**, and the **session token** shown in the iOS App tab.  
2. Tap **Connect** — credentials are saved for future launches.

The app auto-reconnects on startup. To reset, tap ⋯ → Disconnect.
