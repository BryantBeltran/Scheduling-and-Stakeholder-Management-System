# Scheduling and Stakeholder Management System

A Flutter-based event and stakeholder management application with multi-environment support.

## Features

- **User Authentication** - Role-based access control with admin, manager, and viewer roles
- **Event Management** - Create, edit, and track events with status and priority
- **Stakeholder Management** - Track stakeholders and their participation in events
- **Dashboard** - Overview with statistics and upcoming events
- **Multi-Environment** - Dev, staging, and production flavors

## Getting Started

### Prerequisites

- Flutter SDK 3.9.2+
- Android Studio / VS Code
- Android SDK (for Android builds)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Scheduling-and-Stakeholder-Management-System

# Get dependencies
flutter pub get
```

## Flutter Flavors

This project uses Flutter Flavors for environment management. Three environments are configured:

| Flavor | App Name | Bundle ID Suffix | Use Case |
|--------|----------|------------------|----------|
| dev | SSMS Dev | .dev.debug | Local development |
| staging | SSMS Staging | .staging | QA testing |
| prod | Scheduling & Stakeholder | (none) | Production |

### Running with Flavors

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Staging
flutter run --flavor staging -t lib/main_staging.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart

# Default (runs prod)
flutter run
```

### Building APKs

```bash
# Debug builds
flutter build apk --flavor dev -t lib/main_dev.dart --debug
flutter build apk --flavor staging -t lib/main_staging.dart --debug
flutter build apk --flavor prod -t lib/main_prod.dart --debug

# Release builds
flutter build apk --flavor dev -t lib/main_dev.dart --release
flutter build apk --flavor staging -t lib/main_staging.dart --release
flutter build apk --flavor prod -t lib/main_prod.dart --release

# App Bundle (for Play Store)
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

### Environment Configuration

Environment-specific settings are managed in `lib/config/app_config.dart`:

- API base URL
- Debug features toggle
- Analytics enabled/disabled
- Log level
- Firebase project ID

## Project Structure

```
lib/
├── app.dart              # Main app widget (shared by all flavors)
├── main.dart             # Default entry point (prod)
├── main_dev.dart         # Development entry point
├── main_staging.dart     # Staging entry point
├── main_prod.dart        # Production entry point
├── config/
│   └── app_config.dart   # Environment configuration
├── models/
│   ├── user_model.dart
│   ├── event_model.dart
│   └── stakeholder_model.dart
├── services/
│   ├── auth_service.dart
│   ├── event_service.dart
│   └── stakeholder_service.dart
├── screens/
│   ├── auth/
│   ├── home/
│   ├── events/
│   └── stakeholders/
└── theme/
    └── app_theme.dart
```

## Architecture

- **Service-based architecture** with separation of concerns
- **Material Design 3** theming throughout
- **StreamController** for reactive state (Provider/Riverpod ready)
- **Singleton pattern** for services

## Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## License

MIT License