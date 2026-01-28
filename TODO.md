# TODO - Scheduling & Stakeholder Management System

## Authentication

- [ ] **Integrate Firebase Authentication** - Replace mock auth service with real Firebase Auth
  - File: `lib/services/auth_service.dart`
  
- [ ] **Implement Google Sign-In**
  - Add `google_sign_in` package
  - Configure OAuth credentials in Firebase Console
  - Files: `lib/screens/auth/login_screen.dart`, `register_screen.dart`

- [ ] **Implement Apple Sign-In**
  - Add `sign_in_with_apple` package
  - Configure Apple Developer account
  - Files: `lib/screens/auth/login_screen.dart`, `register_screen.dart`

- [ ] **Add email verification flow**
  - Send verification email on signup
  - Block access until email verified

## Legal Pages

- [ ] **Create Terms of Service screen**
  - Referenced in: `lib/screens/auth/register_screen.dart`

- [ ] **Create Privacy Policy screen**
  - Referenced in: `lib/screens/auth/register_screen.dart`

## Cloud Functions

- [ ] **Connect Flutter app to Cloud Functions**
  - Add `cloud_functions` package
  - Create service layer for function calls
  - Functions available:
    - User: `createUser`, `getUser`, `updateUser`, `deleteUser`
    - Events: `createEvent`, `getEvent`, `updateEvent`, `deleteEvent`
    - Stakeholders: `createStakeholder`, `getStakeholder`, `updateStakeholder`, `deleteStakeholder`
    - Relationships: `addStakeholderToEvent`, `removeStakeholderFromEvent`
    - Notifications: `sendNotification`, `getNotifications`, `markNotificationAsRead`

## UI/UX

- [ ] **Add loading states** for all async operations
- [ ] **Implement pull-to-refresh** on list screens
- [ ] **Add empty state illustrations** for lists
- [ ] **Dark mode support** - Theme is defined but needs testing

## Features

- [ ] **Push Notifications**
  - Add Firebase Cloud Messaging
  - Handle notification permissions
  - Display in-app notifications

- [ ] **Offline Support**
  - Enable Firestore offline persistence
  - Queue operations when offline

- [ ] **Profile Management**
  - Profile photo upload
  - Edit profile details

## Testing

- [ ] **Unit tests** for services
- [ ] **Widget tests** for screens
- [ ] **Integration tests** for auth flows

## Deployment

- [ ] **Configure iOS** for production
  - App Store Connect setup
  - Provisioning profiles

- [ ] **Configure Android** for production
  - Google Play Console setup
  - Signing keys

- [ ] **Set up CI/CD pipeline**
  - GitHub Actions or similar

---

## Completed

- [x] Flutter flavor setup (dev, staging, prod)
- [x] Firebase Cloud Functions deployment
- [x] Login screen UI
- [x] Sign up screen UI
- [x] Register password screen
- [x] Basic navigation/routing
