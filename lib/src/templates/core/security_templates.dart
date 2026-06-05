/// Security Template
class SecurityTemplates {
  SecurityTemplates._();

  /// Returns the generated secureStorage template.
  static String secureStorage() => r'''
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => FlutterSecureStorage());

''';

  /// Returns the generated validationService template.
  static String validationService() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';

/// Enum com tipos de input para validação
enum InputType {
  email,
  url,
  phone,
  password,
  username,
  text, // generic text
  number,
  creditCard,
}

/// Resultado da validação
class ValidationResult {
  final bool isValid;
  final String? error;
  final String sanitizedValue;

  ValidationResult({
    required this.isValid,
    this.error,
    required this.sanitizedValue,
  });

  factory ValidationResult.valid(String sanitized) =>
      ValidationResult(isValid: true, sanitizedValue: sanitized);

  factory ValidationResult.invalid(String error, String original) {
    throw AppException.fromMessage(error);
  }
}

/// Validador principal
final validationServiceProvider = Provider<ValidationService>((ref) {
  return ValidationService();
});

class ValidationService {
  // Regex patterns
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );

  static final _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  static final _phoneRegex = RegExp(
    r'^[+]?[(]?[0-9]{3}[)]?[-\s.]?[0-9]{3}[-\s.]?[0-9]{4,6}$',
  );
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
  static final _numberRegex = RegExp(r'^-?\d+\.?\d*$');

  // SQL Injection Patterns
  static final _sqlInjectionPatterns = [
    RegExp(
      r"('|(\x27))+|(--)|;|(\*|union|select|insert|update|delete|drop|create|alter)",
      caseSensitive: false,
    ),
  ];

  static final _xssPatterns = [
    RegExp(
      r'<script|javascript:|onerror=|onload=|onclick=|<iframe',
      caseSensitive: false,
    ),
  ];

  static final _pathTraversalPatterns = [RegExp(r'\.\./|\.\.\\|%2e%2e')];

  static ValidationResult validate(
    String value, {
    required InputType inputType,
    int minLength = 1,
    int maxLength = 1000,
    bool trimWhitespace = true,
    bool toLowerCase = false,
  }) {

  if (value.isEmpty) {
      return ValidationResult.valid(value);
    }
    // Trim
    var processed = trimWhitespace ? value.trim() : value;

    if (toLowerCase) {
      processed = processed.toLowerCase();
    }

    // Length validation
    if (processed.isEmpty && minLength > 0) {
      return ValidationResult.invalid(
        '${inputType.name} cannot be empty',
        value,
      );
    }

    if (processed.length < minLength) {
      return ValidationResult.invalid(
        '${inputType.name} must have at least $minLength characters',
        value,
      );
    }

    if (processed.length > maxLength) {
      return ValidationResult.invalid(
        '${inputType.name} must have at most $maxLength characters',
        value,
      );
    }

    // Type validation
    if (inputType != InputType.text) {
      final typeValidation = _validateByType(processed, inputType);
      if (!typeValidation.isValid) {
        return typeValidation;
      }
    }

    // Security validation for all types
    final securityCheck = _validateSecurity(processed, inputType);
    if (!securityCheck.isValid) {
      return securityCheck;
    }

    // Final sanitization
    final sanitized = _sanitize(processed, inputType);

    return ValidationResult.valid(sanitized);
  }

  /// Validation by type
  static ValidationResult _validateByType(String value, InputType type) {
    switch (type) {
      case InputType.email:
        if (!_emailRegex.hasMatch(value)) {
          return ValidationResult.invalid('Invalid email', value);
        }
        break;

      case InputType.url:
        if (!_urlRegex.hasMatch(value)) {
          return ValidationResult.invalid('Invalid URL', value);
        }
        break;

      case InputType.phone:
        final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
        if (!_phoneRegex.hasMatch(cleaned)) {
          return ValidationResult.invalid('Invalid phone number', value);
        }
        break;

      case InputType.username:
        if (!_usernameRegex.hasMatch(value)) {
          return ValidationResult.invalid(
            'Invalid username (3-20 characters, only letters, numbers, -, _)',
            value,
          );
        }
        break;

      case InputType.password:
        if (value.length < 6) {
          return ValidationResult.invalid(
            'Password must have at least 6 characters',
            value,
          );
        }

        // Password strength
        final hasUppercase = value.contains(RegExp(r'[A-Z]'));
        final hasLowercase = value.contains(RegExp(r'[a-z]'));
        final hasNumbers = value.contains(RegExp(r'[0-9]'));
        final hasSpecial = value.contains(
          RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\x27",.<>?]'),
        );

        final strength = [
          hasUppercase,
          hasLowercase,
          hasNumbers,
          hasSpecial,
        ].where((e) => e).length;

        if (strength < 3) {
          return ValidationResult.invalid(
            'Password too weak: needs uppercase, lowercase, numbers and special characters',
            value,
          );
        }
        break;

      case InputType.number:
        if (!_numberRegex.hasMatch(value)) {
          return ValidationResult.invalid('Invalid number', value);
        }
        break;

      case InputType.creditCard:
        final cleaned = value.replaceAll(RegExp(r'\s'), '');
        if (!RegExp(r'^\d{13,19}$').hasMatch(cleaned)) {
          return ValidationResult.invalid('Invalid credit card number', value);
        }
        // Luhn algorithm
        if (!_luhnCheck(cleaned)) {
          return ValidationResult.invalid(
            'Invalid credit card number (Luhn)',
            value,
          );
        }
        break;

      case InputType.text:
        // No validation needed
        break;
    }

    return ValidationResult.valid(value);
  }

  /// Security validation (XSS, SQL Injection, Path Traversal)
  static ValidationResult _validateSecurity(String value, InputType type) {
    // SQL Injection
    if (type == InputType.text || type == InputType.username) {
      for (var pattern in _sqlInjectionPatterns) {
        if (pattern.hasMatch(value)) {
          return ValidationResult.invalid(
            'Input contains suspicious characters (SQL)',
            value,
          );
        }
      }
    }

    // XSS
    if (type == InputType.text) {
      for (var pattern in _xssPatterns) {
        if (pattern.hasMatch(value)) {
          return ValidationResult.invalid(
            'Input contains suspicious scripts (XSS)',
            value,
          );
        }
      }
    }

    // Path Traversal (paths/filenames)
    for (var pattern in _pathTraversalPatterns) {
      if (pattern.hasMatch(value)) {
        return ValidationResult.invalid(
          'Input contains suspicious path traversal characters',
          value,
        );
      }
    }

    // Null characters
    if (value.contains('\x00')) {
      return ValidationResult.invalid('Input contains null characters', value);
    }

    return ValidationResult.valid(value);
  }

  /// Sanitization: remove/escape dangerous characters
  static String _sanitize(String value, InputType type) {
    var sanitized = value;

    // Remove dangerous control characters
    sanitized = sanitized.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    // For email and URL, remove extra whitespace
    if (type == InputType.email || type == InputType.url) {
      sanitized = sanitized.replaceAll(RegExp(r'\s'), '');
    }

    // For phone, remove everything except digits, +, -, (, ), space
    if (type == InputType.phone) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\d+\-() ]'), '');
    }

    // For username, only allow a-z, 0-9, -, _
    if (type == InputType.username) {
      sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    }

    // For number, only allow digits, -, .
    if (type == InputType.number) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\d\-.]'), '');
    }

    // HTML encode for generic text
    if (type == InputType.text) {
      sanitized = _htmlEncode(sanitized);
    }

    return sanitized;
  }

  /// Luhn algorithm for validating credit card numbers
  static bool _luhnCheck(String cardNumber) {
    int sum = 0;
    bool isEven = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      isEven = !isEven;
    }

    return sum % 10 == 0;
  }

  /// Basic HTML encoding - escapes special characters to prevent XSS
  static String _htmlEncode(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Validate multiple inputs at once
  static Map<String, ValidationResult> validateMultiple(
    Map<String, String> inputs,
    Map<String, InputType> types, {
    Map<String, int> minLengths = const {},
    Map<String, int> maxLengths = const {},
  }) {
    final results = <String, ValidationResult>{};

    for (final entry in inputs.entries) {
      final key = entry.key;
      final value = entry.value;
      final type = types[key];

      if (type == null) {
        results[key] = ValidationResult.invalid(
          'Validation type not defined',
          value,
        );
        continue;
      }

      results[key] = validate(
        value,
        inputType: type,
        minLength: minLengths[key] ?? 1,
        maxLength: maxLengths[key] ?? 1000,
      );
    }

    return results;
  }
}

''';
}
