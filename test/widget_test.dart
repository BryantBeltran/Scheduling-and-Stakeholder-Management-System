// ==============================================================================
// WIDGET TEST FILE
// ==============================================================================
// Basic Flutter widget tests for the scheduling app.
// Reference: https://docs.flutter.dev/testing
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:scheduling_and_stakeholder_management_system/config/app_config.dart';
import 'package:scheduling_and_stakeholder_management_system/app.dart';

void main() {
  setUp(() {
    // Initialize app config before tests
    if (!AppConfig.isInitialized) {
      AppConfig.initialize(AppFlavor.dev);
    }
  });

  testWidgets('App launches and shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SchedulingApp());

    // Allow streams to settle
    await tester.pump();
    
    // Verify that the login screen is displayed
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
