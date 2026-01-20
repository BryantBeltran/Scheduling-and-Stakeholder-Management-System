# Cloud Functions Backend

Firebase Cloud Functions for the Scheduling and Stakeholder Management System.

## Overview

This backend provides serverless functions for user management, event management, stakeholder management, and notifications using Firebase Cloud Functions v2.

## Prerequisites

- Node.js 24
- npm
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase project with Blaze (pay-as-you-go) plan

## Setup

### Install Dependencies

```bash
cd functions
npm install
```

### Firebase Configuration

Ensure you are logged into Firebase:

```bash
firebase login
```

Set your Firebase project:

```bash
firebase use stakeholder-management-367ba
```

## Development

### Build TypeScript

```bash
npm run build
```

### Watch Mode

```bash
npm run build:watch
```

### Run Functions Locally

```bash
npm run serve
```

This starts the Firebase emulators for local testing.

### Run Functions Shell

```bash
npm run shell
```

Interactive shell for testing functions locally.

## Deployment

### Deploy All Functions

```bash
firebase deploy --only functions
```

### Deploy Specific Function

```bash
firebase deploy --only functions:createUser
```

## Available Functions

### User Management

- **createUser** - Create a new user with authentication and Firestore profile
- **getUser** - Retrieve user profile by UID
- **updateUser** - Update user display name
- **deleteUser** - Delete user from authentication and Firestore

### Event Management

- **createEvent** - Create a new event
- **getEvent** - Retrieve event by ID
- **updateEvent** - Update event details
- **deleteEvent** - Delete an event

### Stakeholder Management

- **createStakeholder** - Create a new stakeholder
- **getStakeholder** - Retrieve stakeholder by ID
- **updateStakeholder** - Update stakeholder details
- **deleteStakeholder** - Delete a stakeholder

### Event-Stakeholder Relationships

- **addStakeholderToEvent** - Associate a stakeholder with an event
- **removeStakeholderFromEvent** - Remove stakeholder from an event

### Notifications

- **sendNotification** - Create a new notification for a user
- **getNotifications** - Retrieve all notifications for a user
- **markNotificationAsRead** - Mark a notification as read

## Function Call Examples

### From Flutter/Dart

```dart
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instance;

// Create a user
final result = await functions.httpsCallable('createUser').call({
  'email': 'user@example.com',
  'password': 'password123',
  'displayName': 'John Doe',
});

print('User UID: ${result.data['uid']}');
```

### From JavaScript/Web

```javascript
import { getFunctions, httpsCallable } from 'firebase/functions';

const functions = getFunctions();
const createUser = httpsCallable(functions, 'createUser');

const result = await createUser({
  email: 'user@example.com',
  password: 'password123',
  displayName: 'John Doe'
});

console.log('User UID:', result.data.uid);
```

## Project Structure

```
functions/
├── src/
│   └── index.ts          # All Cloud Functions
├── lib/                  # Compiled JavaScript (auto-generated)
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
└── .eslintrc.js          # ESLint configuration
```

## TypeScript Configuration

Key compiler options in `tsconfig.json`:

- **target**: ES2017
- **module**: CommonJS
- **strict**: true
- **esModuleInterop**: true
- **skipLibCheck**: true (skip type checking in node_modules)

## Linting

```bash
npm run lint
```

Fix linting issues automatically:

```bash
npm run lint -- --fix
```

## Logs

View function logs:

```bash
npm run logs
```

Or view in Firebase Console:
https://console.firebase.google.com/project/stakeholder-management-367ba/functions/logs

## Error Handling

All functions use structured error handling with Firebase HttpsError:

- `invalid-argument` - Invalid function parameters
- `not-found` - Resource not found
- `internal` - Server error

## Security

- Functions use Firebase Admin SDK for elevated privileges
- Client requests should be authenticated
- Implement custom authentication checks as needed for production

## Cost Management

Global function configuration in `src/index.ts`:

```typescript
setGlobalOptions({maxInstances: 10});
```

This limits concurrent function instances to control costs.

## Troubleshooting

### Build Errors

If you encounter TypeScript errors, ensure you have the correct version:

```bash
npm install typescript@4.9.5 --save-dev
```

### Deployment Errors

**Billing not enabled:**
- Upgrade to Blaze plan: https://console.firebase.google.com/project/stakeholder-management-367ba/usage/details

**API not enabled:**
- Firebase will attempt to enable required APIs automatically
- If manual action needed, visit: https://console.cloud.google.com/apis

### Node Version Mismatch

Ensure you're using Node.js 24 as specified in `package.json`:

```bash
node --version
```

Use nvm to switch versions if needed:

```bash
nvm install 24
nvm use 24
```

## Additional Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Cloud Functions Pricing](https://firebase.google.com/pricing)
