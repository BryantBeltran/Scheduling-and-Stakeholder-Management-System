// ==============================================================================
// AUTHENTICATION VALIDATORS
// ==============================================================================
// Centralized validation logic for authentication operations.
// Includes email, password, and user data validation.
// ==============================================================================

/// Validation result containing success status and error message
class AuthValidationResult {
  final bool isValid;
  final String? errorMessage;

  const AuthValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const AuthValidationResult.invalid(String message)
      : isValid = false,
        errorMessage = message;
}

/// Authentication validators for registration, login, and profile updates
class AuthValidators {
  // Password constraints
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  
  // Name constraints
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  
  // Email constraints
  static const int maxEmailLength = 254;

  // ============================================================================
  // EMAIL VALIDATION
  // ============================================================================

  /// Validates email format and requirements
  static AuthValidationResult validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return const AuthValidationResult.invalid('Email is required');
    }

    final trimmedEmail = email.trim();

    if (trimmedEmail.length > maxEmailLength) {
      return const AuthValidationResult.invalid('Email is too long');
    }

    // Comprehensive email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmedEmail)) {
      return const AuthValidationResult.invalid('Please enter a valid email address');
    }

    // Check for common typos in popular domains
    final domain = trimmedEmail.split('@').last.toLowerCase();
    final commonMisspellings = {
      'gmial.com': 'gmail.com',
      'gmal.com': 'gmail.com',
      'gamil.com': 'gmail.com',
      'gnail.com': 'gmail.com',
      'hotmal.com': 'hotmail.com',
      'hotmial.com': 'hotmail.com',
      'yaho.com': 'yahoo.com',
      'yahooo.com': 'yahoo.com',
      'outloo.com': 'outlook.com',
    };

    if (commonMisspellings.containsKey(domain)) {
      return AuthValidationResult.invalid(
        'Did you mean ${trimmedEmail.split('@').first}@${commonMisspellings[domain]}?',
      );
    }

    return const AuthValidationResult.valid();
  }

  /// Form field validator for email
  static String? emailValidator(String? value) {
    final result = validateEmail(value);
    return result.errorMessage;
  }

  // ============================================================================
  // PASSWORD VALIDATION
  // ============================================================================

  /// Validates password strength and requirements
  static AuthValidationResult validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return const AuthValidationResult.invalid('Password is required');
    }

    if (password.length < minPasswordLength) {
      return AuthValidationResult.invalid(
        'Password must be at least $minPasswordLength characters',
      );
    }

    if (password.length > maxPasswordLength) {
      return const AuthValidationResult.invalid('Password is too long');
    }

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return const AuthValidationResult.invalid(
        'Password must contain at least one uppercase letter',
      );
    }

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return const AuthValidationResult.invalid(
        'Password must contain at least one lowercase letter',
      );
    }

    // Check for at least one digit
    if (!password.contains(RegExp(r'[0-9]'))) {
      return const AuthValidationResult.invalid(
        'Password must contain at least one number',
      );
    }

    // Check for at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]'))) {
      return const AuthValidationResult.invalid(
        'Password must contain at least one special character',
      );
    }

    // Check for common weak passwords
    if (_isCommonPassword(password.toLowerCase())) {
      return const AuthValidationResult.invalid(
        'This password is too common. Please choose a stronger password.',
      );
    }

    return const AuthValidationResult.valid();
  }

  /// Form field validator for password
  static String? passwordValidator(String? value) {
    final result = validatePassword(value);
    return result.errorMessage;
  }

  /// Validates password for login (less strict, just checks not empty)
  static String? loginPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  /// Validates password confirmation matches original
  static AuthValidationResult validatePasswordConfirmation(
    String? password,
    String? confirmation,
  ) {
    if (confirmation == null || confirmation.isEmpty) {
      return const AuthValidationResult.invalid('Please confirm your password');
    }

    if (password != confirmation) {
      return const AuthValidationResult.invalid('Passwords do not match');
    }

    return const AuthValidationResult.valid();
  }

  /// Form field validator for password confirmation
  static String? passwordConfirmationValidator(
    String? confirmation,
    String? originalPassword,
  ) {
    final result = validatePasswordConfirmation(originalPassword, confirmation);
    return result.errorMessage;
  }

  /// Calculates password strength (0-100)
  static int calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // Length contribution (up to 30 points)
    strength += (password.length * 3).clamp(0, 30);

    // Uppercase letters (up to 15 points)
    if (password.contains(RegExp(r'[A-Z]'))) {
      strength += 15;
    }

    // Lowercase letters (up to 15 points)
    if (password.contains(RegExp(r'[a-z]'))) {
      strength += 15;
    }

    // Numbers (up to 15 points)
    if (password.contains(RegExp(r'[0-9]'))) {
      strength += 15;
    }

    // Special characters (up to 15 points)
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]'))) {
      strength += 15;
    }

    // Variety bonus (up to 10 points)
    final uniqueChars = password.split('').toSet().length;
    strength += ((uniqueChars / password.length) * 10).round();

    // Penalty for common patterns
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      strength -= 10; // Repeated characters
    }
    if (RegExp(r'(012|123|234|345|456|567|678|789|890)').hasMatch(password)) {
      strength -= 10; // Sequential numbers
    }
    if (RegExp(r'(abc|bcd|cde|def|efg|fgh|ghi)', caseSensitive: false)
        .hasMatch(password)) {
      strength -= 10; // Sequential letters
    }

    return strength.clamp(0, 100);
  }

  /// Returns a description of password strength
  static String getPasswordStrengthLabel(int strength) {
    if (strength < 30) return 'Weak';
    if (strength < 50) return 'Fair';
    if (strength < 70) return 'Good';
    if (strength < 90) return 'Strong';
    return 'Excellent';
  }

  // ============================================================================
  // NAME VALIDATION
  // ============================================================================

  /// Validates display name
  static AuthValidationResult validateDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return const AuthValidationResult.invalid('Name is required');
    }

    final trimmedName = name.trim();

    if (trimmedName.length < minNameLength) {
      return AuthValidationResult.invalid(
        'Name must be at least $minNameLength characters',
      );
    }

    if (trimmedName.length > maxNameLength) {
      return AuthValidationResult.invalid(
        'Name must be less than $maxNameLength characters',
      );
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s'\-\.]+$").hasMatch(trimmedName)) {
      return const AuthValidationResult.invalid(
        'Name can only contain letters, spaces, hyphens, and apostrophes',
      );
    }

    return const AuthValidationResult.valid();
  }

  /// Form field validator for display name
  static String? displayNameValidator(String? value) {
    final result = validateDisplayName(value);
    return result.errorMessage;
  }

  // ============================================================================
  // PHONE NUMBER VALIDATION
  // ============================================================================

  /// Validates phone number format
  static AuthValidationResult validatePhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return const AuthValidationResult.valid(); // Phone is optional
    }

    final trimmedPhone = phone.trim();

    // Remove common formatting characters for validation
    final digitsOnly = trimmedPhone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    if (digitsOnly.length < 10) {
      return const AuthValidationResult.invalid(
        'Phone number must have at least 10 digits',
      );
    }

    if (digitsOnly.length > 15) {
      return const AuthValidationResult.invalid(
        'Phone number is too long',
      );
    }

    // Check that remaining characters are all digits
    if (!RegExp(r'^[0-9]+$').hasMatch(digitsOnly)) {
      return const AuthValidationResult.invalid(
        'Phone number can only contain digits',
      );
    }

    return const AuthValidationResult.valid();
  }

  /// Form field validator for phone number
  static String? phoneValidator(String? value) {
    final result = validatePhoneNumber(value);
    return result.errorMessage;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Checks if password is in common passwords list
  static bool _isCommonPassword(String password) {
    const commonPasswords = [
      'password', 'password1', 'password123',
      '12345678', '123456789', '1234567890',
      'qwerty123', 'qwertyuiop',
      'letmein', 'welcome', 'welcome1',
      'admin123', 'admin1234',
      'iloveyou', 'sunshine', 'princess',
      'football', 'baseball', 'basketball',
      'dragon', 'master', 'monkey', 'shadow',
      'michael', 'jennifer', 'jordan',
      'superman', 'batman', 'trustno1',
      'abc12345', 'abc123456',
      'passw0rd', 'p@ssword', 'p@ssw0rd',
    ];
    return commonPasswords.contains(password);
  }

  /// Validates all registration fields at once
  static Map<String, String?> validateRegistration({
    required String email,
    required String password,
    required String confirmPassword,
    required String displayName,
    String? phoneNumber,
  }) {
    return {
      'email': emailValidator(email),
      'password': passwordValidator(password),
      'confirmPassword': passwordConfirmationValidator(confirmPassword, password),
      'displayName': displayNameValidator(displayName),
      'phone': phoneValidator(phoneNumber),
    };
  }

  /// Checks if all registration validations pass
  static bool isRegistrationValid({
    required String email,
    required String password,
    required String confirmPassword,
    required String displayName,
    String? phoneNumber,
  }) {
    final errors = validateRegistration(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      displayName: displayName,
      phoneNumber: phoneNumber,
    );
    return errors.values.every((error) => error == null);
  }

  /// Validates login credentials format
  static Map<String, String?> validateLogin({
    required String email,
    required String password,
  }) {
    return {
      'email': emailValidator(email),
      'password': loginPasswordValidator(password),
    };
  }

  /// Checks if login validation passes
  static bool isLoginValid({
    required String email,
    required String password,
  }) {
    final errors = validateLogin(email: email, password: password);
    return errors.values.every((error) => error == null);
  }
}
