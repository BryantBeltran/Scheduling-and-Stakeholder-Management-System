# Scheduling and Stakeholder Management System

A comprehensive Flutter application for managing events and stakeholders with an Android-first implementation.

## Features

### 📱 Core Functionality
- **User Authentication**: Login, registration, and password recovery
- **Event Management**: Create, view, filter, and search events
- **Stakeholder Management**: Manage stakeholders with various types and participation statuses
- **Dashboard**: Overview with statistics and upcoming events
- **User Profile**: View and manage user profile information

### 🎨 UI/UX Design
- Modern Material Design 3 UI
- Responsive layouts optimized for Android devices
- Custom theme with primary and accent colors
- Clean navigation with bottom navigation bar
- Search and filter capabilities
- Status and priority indicators with color coding

### 📊 Data Models

#### Users
- **Fields**: ID, email, display name, photo URL, role, permissions, timestamps
- **Roles**: Admin, Manager, Member, Viewer
- **Permissions**: Create/edit/delete events, assign stakeholders, manage users, view reports

#### Events
- **Fields**: ID, title, description, start/end time, location, owner, status, priority, stakeholder IDs
- **Status**: Draft, Scheduled, In Progress, Completed, Cancelled
- **Priority**: Low, Medium, High, Urgent
- **Location**: Physical or virtual with address/link support

#### Stakeholders
- **Fields**: ID, name, email, phone, organization, title, type, relationship, participation status
- **Types**: Internal, External, Client, Vendor, Partner
- **Relationship**: Organizer, Presenter, Attendee, Sponsor, Guest, Support
- **Participation**: Pending, Accepted, Declined, Tentative, No Response

## Project Structure

```
lib/
├── models/              # Data models
│   ├── user_model.dart
│   ├── event_model.dart
│   ├── stakeholder_model.dart
│   └── models.dart
├── services/            # Business logic services
│   ├── auth_service.dart
│   ├── event_service.dart
│   ├── stakeholder_service.dart
│   └── services.dart
├── screens/             # UI screens
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── forgot_password_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── events/
│   │   └── event_list_screen.dart
│   ├── stakeholders/
│   │   └── stakeholder_list_screen.dart
│   └── profile/
│       └── profile_screen.dart
├── theme/               # App theme configuration
│   └── app_theme.dart
└── main.dart           # App entry point
```

## Android Implementation

### Configuration
- **Minimum SDK**: 23 (Android 6.0)
- **Target SDK**: Latest Flutter SDK version
- **Package Name**: `com.example.scheduling_and_stakeholder_management_system`
- **App Name**: "Scheduling & Stakeholder Management"

### Permissions
- Internet access for API calls
- Network state for connectivity checks

### Build Configuration
- Kotlin support enabled
- Material Design 3 components
- Clear text traffic allowed for development

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android Studio with Android SDK
- Android device or emulator (API 23+)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd Scheduling-and-Stakeholder-Management-System
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run on Android device:
   ```bash
   flutter run
   ```

4. Build APK:
   ```bash
   flutter build apk
   ```

5. Build App Bundle (for Play Store):
   ```bash
   flutter build appbundle
   ```

## Development

### Mock Data
The application includes sample data for development:
- 3 sample events with different statuses and priorities
- 5 sample stakeholders with various types and participation statuses
- Mock authentication service (replace with Firebase Auth for production)

### User Flows

#### Authentication Flow
1. Launch app → Login screen
2. Enter credentials or register new account
3. Optional: Forgot password recovery
4. Successful login → Dashboard

#### Event Creation Flow
1. Navigate to Events tab
2. Tap "New Event" button
3. Fill event details (title, description, date/time, location)
4. Assign stakeholders
5. Save event

#### Stakeholder Assignment Flow
1. View event details
2. Tap "Assign Stakeholder"
3. Select from existing stakeholders or create new
4. Set relationship type
5. Save assignment

## Future Enhancements

### Phase 2 Features
- [ ] Firebase integration for backend
- [ ] Real-time notifications
- [ ] Calendar view for events
- [ ] Event details and editing screens
- [ ] Stakeholder details and editing screens
- [ ] Advanced filtering and sorting
- [ ] Export functionality (PDF, CSV)
- [ ] Settings and preferences
- [ ] Dark mode toggle

### Phase 3 Features
- [ ] Offline support with local database
- [ ] File attachments for events
- [ ] Comments and activity feed
- [ ] Email/SMS notifications
- [ ] Calendar synchronization
- [ ] Analytics and reporting dashboard
- [ ] Multi-language support

## Database Schema (Future Firebase/Cloud Implementation)

### Collections

**users**
```json
{
  "id": "string",
  "email": "string",
  "displayName": "string",
  "photoUrl": "string?",
  "role": "admin|manager|member|viewer",
  "permissions": ["string"],
  "createdAt": "timestamp",
  "lastLoginAt": "timestamp?",
  "isActive": "boolean"
}
```

**events**
```json
{
  "id": "string",
  "title": "string",
  "description": "string?",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "location": {
    "name": "string",
    "address": "string?",
    "latitude": "number?",
    "longitude": "number?",
    "isVirtual": "boolean",
    "virtualLink": "string?"
  },
  "ownerId": "string",
  "status": "draft|scheduled|inProgress|completed|cancelled",
  "priority": "low|medium|high|urgent",
  "stakeholderIds": ["string"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**stakeholders**
```json
{
  "id": "string",
  "name": "string",
  "email": "string",
  "phone": "string?",
  "organization": "string?",
  "title": "string?",
  "type": "internal|external|client|vendor|partner",
  "relationshipType": "organizer|presenter|attendee|sponsor|guest|support",
  "participationStatus": "pending|accepted|declined|tentative|noResponse",
  "eventIds": ["string"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Testing

### Manual Testing Checklist
- [ ] User registration and login
- [ ] Navigation between tabs
- [ ] Event list display and filtering
- [ ] Stakeholder list display and search
- [ ] Dashboard statistics
- [ ] Profile screen display
- [ ] Responsive layout on different screen sizes
- [ ] Dark mode (if implemented)

### Test Credentials (Mock Auth)
- Email: any valid email format
- Password: minimum 6 characters

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is for educational and development purposes.

## Contact
For questions or support, please open an issue in the repository.

---

**Week 2 Deliverables Completed:**
- ✅ Low-fidelity wireframes (implemented in code)
- ✅ User flows (authentication, event creation, stakeholder assignment)
- ✅ Database schema (defined in models and documented)
- ✅ ER diagram (documented in README)
- ✅ Android implementation focus
