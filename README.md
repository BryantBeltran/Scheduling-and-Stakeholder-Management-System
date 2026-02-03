# Scheduling and Stakeholder Management System

A Flutter-based event and stakeholder management application with multi-environment support, Firebase backend, and Google Maps integration.

## Features

- User Authentication - Permission-based access control with root, admin, and member roles
- Event Management - Create, edit, and track events with status and priority
- Stakeholder Management - Track stakeholders and their participation in events
- Location Autocomplete - Google Places API integration for event locations
- Dashboard - Overview with statistics and upcoming events
- Multi-Environment - Dev, staging, and production flavors
- Cloud Functions Backend - Serverless API using Firebase Cloud Functions
- Secure Secrets Management - Google Cloud Secret Manager for API keys

## Getting Started

### Prerequisites

- Flutter SDK 3.9.2+
- Android Studio / VS Code
- Android SDK (for Android builds)
- Firebase CLI (for deploying functions)
- Google Maps API Key with Places API enabled

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

**Development Mode:**
```bash
# Run with Google Maps API key
flutter run --flavor dev -t lib/main_dev.dart --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

**Staging Mode:**
```bash
flutter run --flavor staging -t lib/main_staging.dart --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

**Production Mode:**
```bash
# Uses Firebase Secrets (no API key needed in command)
flutter run --flavor prod -t lib/main_prod.dart
```

**Default (runs prod):**
```bash
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

Secrets are managed separately in `lib/config/env_config.dart`:

- Google Maps API key (from Firebase Secrets in production)
- Environment variable support for local development
- Cloud Functions integration for secure key retrieval

## Google Maps API Setup

### 1. Get API Key

1. Go to Google Cloud Console
2. Enable Places API
3. Create credentials (API key)
4. Restrict the key to Places API

### 2. Local Development

Set the API key using --dart-define:
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

Or create a `.env` file (not committed to git):
```
GOOGLE_MAPS_API_KEY=your_actual_api_key
```

### 3. Production (Firebase Secrets)

Store the key securely in Firebase:
```bash
cd functions
firebase functions:secrets:set GOOGLE_MAPS_API_KEY
# Enter your API key when prompted
firebase deploy --only functions
```

The production app fetches the key from Cloud Functions automatically.

## Project Structure

```
lib/
├── app.dart              # Main app widget (shared by all flavors)
├── main.dart             # Default entry point (prod)
├── main_dev.dart         # Development entry point
├── main_staging.dart     # Staging entry point
├── main_prod.dart        # Production entry point
├── config/
│   ├── app_config.dart   # Environment configuration
│   └── env_config.dart   # Secrets management
├── models/
│   ├── user_model.dart
│   ├── event_model.dart
│   └── stakeholder_model.dart
├── services/
│   ├── auth_service.dart
│   ├── event_service.dart
│   ├── stakeholder_service.dart
│   ├── permission_service.dart
│   └── places_service.dart  # Google Places API integration
├── screens/
│   ├── auth/
│   ├── home/
│   ├── events/
│   ├── stakeholders/
│   └── profile/
├── widgets/
│   ├── protected_route.dart
│   └── location_autocomplete_field.dart  # Smart location input
└── theme/
    └── app_theme.dart
```

## Architecture

- Permission-based access control system (not role-based)
- Service-based architecture with separation of concerns
- Material Design 3 theming throughout
- StreamController for reactive state management
- Singleton pattern for services
- Google Places API for location autocomplete with smart positioning
- Firebase Cloud Functions for secure secrets management

## Backend

The backend uses Firebase Cloud Functions for serverless API endpoints. See [functions/README.md](functions/README.md) for detailed documentation on:

- Available API endpoints
- Local development setup
- Deployment instructions
- Function examples and usage
- Secrets management with Google Cloud Secret Manager

## Security

- API keys stored in Google Cloud Secret Manager (production)
- Environment variables for local development
- Permission-based access control throughout the app
- Firebase Authentication integration
- Secure Cloud Functions endpoints (authentication required)

## Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run Cloud Functions locally
cd functions
npm run serve
```

## Deployment

### Deploy Cloud Functions
```bash
cd functions
npm run build
firebase deploy --only functions
```

### Build Release APK
```bash
flutter build apk --flavor prod -t lib/main_prod.dart --release
```

### Build App Bundle
```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

