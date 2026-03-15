# Scheduling and Stakeholder Management System

A Flutter-based event and stakeholder management application with multi-environment support, Firebase backend, real-time sync, push notifications, and Google Maps integration.

## Features

- **User Authentication** — Email/password, Google Sign-In, Apple Sign-In, email verification, password reset
- **Event Management** — Full CRUD with status tracking, priority levels, physical/virtual locations, manager delegation
- **Stakeholder Management** — Track stakeholders, participation status, event assignments, and email invitation flow
- **Calendar View** — Interactive calendar for event visualization
- **Real-time Updates** — Live Firestore listeners for events, stakeholders, and notifications
- **Push Notifications** — Firebase Cloud Messaging (FCM) with in-app notification center and preferences
- **Permission-Based Access Control** — Granular permissions per action (not just role-based)
- **Admin Panel** — User management, role assignment, and audit log (admin/root only)
- **Audit Logging** — Full system action trail across all resources
- **Location Autocomplete** — Google Places API integration for event locations
- **Dashboard** — Statistics, upcoming events, and stakeholder overview
- **Multi-Environment** — Dev, staging, and production flavors
- **Dark Mode** — System-aware theming with Material Design 3
- **Cloud Functions Backend** — Serverless API using Firebase Cloud Functions
- **Secure Secrets Management** — Google Cloud Secret Manager for API keys

## Getting Started

### Prerequisites

- Flutter SDK 3.9.2+
- Android Studio / VS Code
- Android SDK (for Android builds)
- Firebase CLI (for deploying functions and rules)
- Google Maps API Key with Places API enabled

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Scheduling-and-Stakeholder-Management-System

# Get dependencies
flutter pub get

# Install Cloud Functions dependencies
cd functions && npm install
```

## Flutter Flavors

Three environments are configured:

| Flavor | App Name | Firebase | Mock Data | Debug Features |
|--------|----------|----------|-----------|----------------|
| dev | SSMS Dev | Disabled | Enabled | Enabled |
| staging | SSMS Staging | Enabled | Disabled | Enabled |
| prod | Scheduling & Stakeholder | Enabled | Disabled | Disabled |

### Running with Flavors

```bash
# Development (mock data, no Firebase)
flutter run --flavor dev -t lib/main_dev.dart --dart-define=GOOGLE_MAPS_API_KEY=your_key_here

# Staging (Firebase, real data)
flutter run --flavor staging -t lib/main_staging.dart --dart-define=GOOGLE_MAPS_API_KEY=your_key_here

# Production (Firebase Secrets, no key needed in command)
flutter run --flavor prod -t lib/main_prod.dart
```

### Building APKs

```bash
# Debug builds
flutter build apk --flavor dev -t lib/main_dev.dart --debug
flutter build apk --flavor staging -t lib/main_staging.dart --debug
flutter build apk --flavor prod -t lib/main_prod.dart --debug

# Release builds
flutter build apk --flavor prod -t lib/main_prod.dart --release

# App Bundle (for Play Store)
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

## Environment Configuration

Settings are managed in `lib/config/app_config.dart`:

- API base URL, Firebase project ID
- Debug features toggle, analytics, log level
- `useFirebase` and `useMockData` flags per flavor

Secrets are managed in `lib/config/env_config.dart`:

- Google Maps API key (from Firebase Secrets in production)
- `.env` file support for local development
- Cloud Functions integration for secure key retrieval

## Google Maps Setup

1. Go to Google Cloud Console → enable Places API → create an API key
2. Restrict the key to Places API

**Local development:**
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
# or create a .env file (not committed):
# GOOGLE_MAPS_API_KEY=your_actual_api_key
```

**Production (Firebase Secrets):**
```bash
cd functions
firebase functions:secrets:set GOOGLE_MAPS_API_KEY
firebase deploy --only functions
```

## Project Structure

```
lib/
├── main.dart / main_dev.dart / main_staging.dart / main_prod.dart
├── app.dart                         # App widget, routing, auth wrapper
├── config/
│   ├── app_config.dart              # Flavor configuration
│   ├── env_config.dart              # Secrets management
│   └── flavor_config.dart
├── models/
│   ├── user_model.dart              # UserModel, UserRole, Permission
│   ├── event_model.dart             # EventModel, EventStatus, EventPriority, EventLocation
│   ├── stakeholder_model.dart       # StakeholderModel, EventStakeholder, participation enums
│   ├── notification_model.dart      # Notification, NotificationType
│   ├── audit_log_model.dart         # AuditLogModel
│   └── models.dart                  # Re-exports
├── services/
│   ├── auth_service.dart            # Firebase Auth (email/Google/Apple)
│   ├── event_service.dart           # Event CRUD, Firestore real-time sync
│   ├── stakeholder_service.dart     # Stakeholder CRUD, broadcast stream
│   ├── permission_service.dart      # Permission checking (canCreateEvent, etc.)
│   ├── notification_service.dart    # In-app notifications, unread count
│   ├── push_notification_service.dart # FCM token registration and handling
│   ├── user_service.dart            # User profile management
│   ├── settings_service.dart        # Theme mode and user preferences
│   ├── places_service.dart          # Google Places API
│   ├── invite_service.dart          # Invite tokens and email invitations
│   ├── storage_service.dart         # Firebase Storage
│   ├── mock_data_service.dart       # Dev/test mock data
│   ├── auth_validators.dart
│   ├── event_validators.dart
│   └── services.dart               # Re-exports
├── screens/
│   ├── auth/                        # Login, Register, Onboarding, ForgotPassword, EmailVerification
│   ├── home/                        # HomeScreen (dashboard + bottom nav)
│   ├── events/                      # EventList, EventDetails, EventCreate, EventEdit, Calendar
│   ├── stakeholders/                # StakeholderList, Details, Create, Edit, Dashboard
│   ├── profile/                     # Profile, ProfileEdit, Settings, Notifications, NotificationPreferences
│   ├── admin/                       # UserManagement, RoleAssignment, AuditLog
│   └── dev/                         # DevScreenNavigator (debug builds only)
├── widgets/
│   ├── protected_route.dart         # Permission gates for admin routes
│   └── location_autocomplete_field.dart
└── theme/
    └── app_theme.dart               # Light/dark Material 3 themes, status/priority/role colors

functions/
└── src/
    ├── index.ts                     # Exports all Cloud Functions
    ├── users.ts                     # User CRUD + role management
    ├── events.ts                    # Event CRUD + notifications
    ├── stakeholders.ts              # Stakeholder CRUD + invitations
    ├── notifications.ts             # FCM, in-app, email, scheduled reminders
    ├── config.ts                    # App config / API key retrieval
    ├── audit.ts                     # Audit log retrieval
    └── shared.ts                    # Helpers: hasPermission, email senders, writeAuditLog

firestore.rules                      # Per-collection, per-operation security rules
firestore.indexes.json               # Composite indexes for queries
```

## Architecture

- **Service singletons** — All services use `_internal()` constructors; accessed via `ServiceName.instance`
- **Permission-based access control** — `PermissionService` checks specific permissions (e.g., `canCreateEvent`) rather than roles; Cloud Functions mirror this with `hasPermission(uid, PERMISSIONS.xxx)`
- **Reactive state** — `StreamController` (broadcast) for events, stakeholders, and notifications; screens subscribe and rebuild on data changes
- **Route guards** — `AuthWrapper` handles auth state transitions; `ProtectedRoute` gates admin screens by `manageUsers` permission
- **Material Design 3** — Full light/dark theming with semantic colors for status, priority, and user roles
- **Offline support** — Firestore offline persistence enabled

## Screens Overview

### Authentication
| Screen | Description |
|--------|-------------|
| Login | Email/password, Google Sign-In, Apple Sign-In |
| Register | New account with optional invite token |
| Onboarding | Profile setup after signup |
| Email Verification | Verify email before accessing the app |
| Forgot Password | Password reset via email |

### Events
| Screen | Description |
|--------|-------------|
| Event List | Filter chips by status, sort dialog, search, swipe-to-delete (permission-gated) |
| Event Details | Full event view with edit/delete (permission-gated) |
| Event Create | Create event with title, dates, location (physical/virtual), priority, stakeholder picker |
| Event Edit | Edit existing event |
| Calendar | Table calendar view of all events |

### Stakeholders
| Screen | Description |
|--------|-------------|
| Stakeholder List | All stakeholders with search |
| Stakeholder Details | Profile, participation status, linked events |
| Stakeholder Create / Edit | Manage stakeholder information |
| Stakeholder Dashboard | Stakeholder statistics and overview |

### Admin (admin/root only)
| Screen | Description |
|--------|-------------|
| User Management | View all users, assign roles and permissions |
| Role Assignment | Dialog for updating user role |
| Audit Log | Full audit trail of system actions |

## Cloud Functions

All functions are `onCall` unless noted otherwise.

### User Management
`createUser`, `getUser`, `getAllUsers`, `updateUser`, `updateUserRole`, `setUserActiveStatus`, `deleteUser`
Triggers: `onUserCreated` (sets default permissions), `onUserDeleted` (cleanup)

### Event Management
`createEvent`, `getEvent`, `getAllEvents`, `updateEvent`, `deleteEvent`, `notifyEventUpdate`
Trigger: `onEventCreated` (sends welcome notification)

### Stakeholder Management
`createStakeholder`, `getStakeholder`, `updateStakeholder`, `deleteStakeholder`, `inviteStakeholder`, `validateInviteToken`, `linkUserToStakeholder`, `resendInvite`, `addStakeholderToEvent`, `removeStakeholderFromEvent`

### Notifications
`sendNotification`, `getNotifications`, `markNotificationAsRead`, `saveFcmToken`, `removeFcmToken`, `sendTestNotification`
Scheduled: `sendEventReminders`, `sendStakeholderEmailReminders`, `cleanupExpiredInvites`, `autoTransitionEventStatus`

### Config & Auth
`getAppConfig`, `onOnboardingComplete` (sets initial permissions), `requestPasswordReset`

### Admin
`getAuditLogs` (admin/root only)

## Firestore Security Rules

| Collection | Read | Create | Update | Delete |
|-----------|------|--------|--------|--------|
| users | Authenticated | Self only | Self (role/perms locked); managers can update others | Forbidden |
| events | Authenticated | Authenticated (owner = caller) | Owner / manager / admin | Owner / manager / admin |
| stakeholders | `viewStakeholder` perm | `createStakeholder` perm | `editStakeholder` perm | `deleteStakeholder` perm |
| eventStakeholders | `viewStakeholder` perm | `editStakeholder` perm | `editStakeholder` perm | `editStakeholder` perm |
| notifications | Own only | Cloud Functions only | Self (mark read) | Forbidden |
| invites | Authenticated | Forbidden | Forbidden | Forbidden |
| auditLogs | Admin / root only | Forbidden | Forbidden | Forbidden |

## Permission System

Permissions are stored on the user document and checked both client-side (`PermissionService`) and server-side (Cloud Functions `hasPermission()`). Key permissions:

`createEvent`, `editEvent`, `deleteEvent`, `viewStakeholder`, `createStakeholder`, `editStakeholder`, `deleteStakeholder`, `manageUsers`, `viewAuditLog`

Roles (`root`, `admin`, `manager`, `member`, `viewer`) determine the default permission set assigned during onboarding, but individual permissions can be overridden per user.

## Deep Linking

Invite links are handled via `app_links`:
- `https://managemateapp.me/invite?token=<token>`
- `managemateapp://invite?token=<token>`

Unauthenticated users are routed to `/register` with the token pre-filled. Authenticated users skip the invite flow.

## Security

- API keys stored in Google Cloud Secret Manager (production)
- `.env` / `--dart-define` for local development
- Permission-based access control on client and server
- Firebase Authentication required for all Cloud Function calls
- Firestore rules enforce per-document, per-operation permissions

## Deployment

### Deploy Everything
```bash
# Deploy Firestore rules and indexes
firebase deploy --only firestore

# Deploy Cloud Functions
cd functions
npm run build
firebase deploy --only functions

# Deploy all
firebase deploy
```

### Build Release APK
```bash
flutter build apk --flavor prod -t lib/main_prod.dart --release
```

### Build App Bundle
```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

## Testing

```bash
# Flutter tests
flutter test
flutter test --coverage

# Cloud Functions local emulator
cd functions
npm run serve
```
