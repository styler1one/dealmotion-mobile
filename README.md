# DealMotion Mobile

Flutter mobile app for DealMotion - AI-powered sales enablement on the go.

## Features

- 🎙️ Meeting recording with background support
- 🔍 Company research on-the-go
- 📋 Meeting preparation
- 📊 Dashboard with live stats
- 👥 Prospect management
- 📝 Quick notes

## Tech Stack

- **Framework**: Flutter 3.16+
- **State Management**: Riverpod 2.x
- **Navigation**: GoRouter
- **Backend**: Supabase + FastAPI
- **Audio**: flutter_sound
- **Storage**: Hive (offline cache)

## Project Structure

```
dealmotion-mobile/
├── lib/
│   ├── core/           # Config, theme, routing
│   ├── features/       # Feature modules
│   │   ├── auth/
│   │   ├── home/
│   │   ├── meetings/
│   │   ├── recording/
│   │   ├── research/
│   │   ├── preparation/
│   │   ├── followup/
│   │   └── prospects/
│   └── shared/         # Shared widgets, services
├── android/
├── ios/
└── assets/
```

## Development

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

## Environment Setup

1. Copy `lib/core/config/app_config.example.dart` to `app_config.dart`
2. Fill in your Supabase URL and anon key
3. Configure Firebase for push notifications

## Links

- **API**: https://api.dealmotion.ai
- **Web App**: https://dealmotion.ai
