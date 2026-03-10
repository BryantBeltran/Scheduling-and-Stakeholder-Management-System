import 'package:flutter_test/flutter_test.dart';
import 'package:scheduling_and_stakeholder_management_system/models/user_model.dart';

void main() {
  group('UserModel', () {
    UserModel createUser({
      UserRole role = UserRole.member,
      List<Permission>? permissions,
    }) {
      return UserModel(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        role: role,
        permissions: permissions ?? UserModel.getDefaultPermissions(role),
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('getDefaultPermissions returns correct permissions for admin', () {
      final perms = UserModel.getDefaultPermissions(UserRole.admin);
      expect(perms, contains(Permission.createEvent));
      expect(perms, contains(Permission.manageUsers));
      expect(perms, contains(Permission.admin));
      expect(perms, isNot(contains(Permission.root)));
    });

    test('getDefaultPermissions returns correct permissions for manager', () {
      final perms = UserModel.getDefaultPermissions(UserRole.manager);
      expect(perms, contains(Permission.createEvent));
      expect(perms, contains(Permission.deleteStakeholder));
      expect(perms, contains(Permission.inviteStakeholder));
      expect(perms, isNot(contains(Permission.manageUsers)));
    });

    test('getDefaultPermissions returns correct permissions for member', () {
      final perms = UserModel.getDefaultPermissions(UserRole.member);
      expect(perms, contains(Permission.createEvent));
      expect(perms, contains(Permission.viewStakeholder));
      expect(perms, isNot(contains(Permission.deleteStakeholder)));
      expect(perms, isNot(contains(Permission.inviteStakeholder)));
    });

    test('getDefaultPermissions returns correct permissions for viewer', () {
      final perms = UserModel.getDefaultPermissions(UserRole.viewer);
      expect(perms, contains(Permission.viewEvent));
      expect(perms, contains(Permission.viewStakeholder));
      expect(perms, isNot(contains(Permission.createEvent)));
      expect(perms, isNot(contains(Permission.editEvent)));
    });

    test('hasPermission returns true for granted permission', () {
      final user = createUser(role: UserRole.member);
      expect(user.hasPermission(Permission.createEvent), isTrue);
    });

    test('hasPermission returns false for ungrantred permission', () {
      final user = createUser(role: UserRole.viewer);
      expect(user.hasPermission(Permission.deleteEvent), isFalse);
    });

    test('copyWith creates modified copy preserving other fields', () {
      final user = createUser();
      final updated = user.copyWith(displayName: 'New Name', role: UserRole.admin);
      expect(updated.displayName, 'New Name');
      expect(updated.role, UserRole.admin);
      expect(updated.id, 'u1');
      expect(updated.email, 'test@example.com');
    });

    test('copyWith with no args returns equivalent user', () {
      final user = createUser();
      final copy = user.copyWith();
      expect(copy.id, user.id);
      expect(copy.email, user.email);
      expect(copy.displayName, user.displayName);
      expect(copy.role, user.role);
    });

    test('isActive defaults to true', () {
      final user = createUser();
      expect(user.isActive, isTrue);
    });

    test('stakeholderId defaults to null', () {
      final user = createUser();
      expect(user.stakeholderId, isNull);
    });
  });
}
