/// Security Template
class SecurityTemplates {
  SecurityTemplates._();

  /// Returns the generated secureStorage template.
  static String secureStorage() => r'''
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);

/// Single owner of the auth session kept in secure storage — used by the Dio
/// client and by the auth repository.
class TokenStorage {
  const TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const userIdKey = 'user_id';

  Future<String?> get accessToken => _storage.read(key: accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: refreshTokenKey);
  Future<String?> get userId => _storage.read(key: userIdKey);

  /// Saves both tokens plus the user id extracted from the access token.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: accessTokenKey, value: accessToken);
    await _storage.write(key: refreshTokenKey, value: refreshToken);
    final userId = _userIdFromJwt(accessToken);
    if (userId != null) {
      await _storage.write(key: userIdKey, value: userId);
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
    await _storage.delete(key: userIdKey);
  }

  /// Reads the user id claim from the JWT payload. The signature is not
  /// verified — that is the backend's job.
  String? _userIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      // Adjust the claim name to whatever your backend puts the user id in.
      final id = payload['sub'] ?? payload['userId'] ?? payload['id'];
      return id?.toString();
    } catch (_) {
      return null;
    }
  }
}
''';

  /// Returns the generated biometricService template.
  static String biometricService() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/types/auth_messages_ios.dart';

import '../utils/app_logger.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(LocalAuthentication());
});

class BiometricService {
  BiometricService(this._auth);

  final LocalAuthentication _auth;

  // True when the device has a lock screen, biometrics enrolled or not.
  Future<bool> canAuthenticate() => _auth.isDeviceSupported();

  Future<bool> authenticate() {
    return _auth.authenticate(
      localizedReason: 'Please authenticate to continue',
      biometricOnly: false,
      authMessages: const <AuthMessages>[
        AndroidAuthMessages(
          signInTitle: 'Authentication required',
          cancelButton: 'Cancel',
        ),
        IOSAuthMessages(cancelButton: 'Cancel'),
      ],
    );
  }

  /// Runs local authentication, reporting failure as a snackbar rather than
  /// throwing, so callers only need the bool.
  Future<bool> verifyUserLocalAuth(BuildContext context) async {
    // Resolved before any await — the prompt can outlive the calling widget.
    final messenger = ScaffoldMessenger.of(context);

    try {
      final didAuthenticate = await authenticate();
      if (!didAuthenticate) {
        _showFeedback(messenger, 'Authentication failed');
        return false;
      }
      return true;
    } on LocalAuthException catch (e) {
      appLogger.e('LocalAuthException: ${e.code.name} - ${e.description}');
      // Device has neither biometrics nor a PIN/pattern/password set up, so
      // there is no local credential to fall back to.
      final message = e.code == LocalAuthExceptionCode.noCredentialsSet
          ? 'Device has no lock method configured'
          : e.description ?? 'Authentication error';
      _showFeedback(messenger, message);
      return false;
    } on PlatformException catch (e) {
      appLogger.e('PlatformException: ${e.message}');
      _showFeedback(messenger, e.message ?? 'Authentication error');
      return false;
    }
  }

  void _showFeedback(ScaffoldMessengerState messenger, String message) {
    // The screen may have been popped while the prompt was up.
    if (!messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
''';

  /// Returns the generated validationService template.
  static String validationService() => r'''
/// What a value is meant to be — drives the rule and the tidying it gets.
enum InputType {
  text,
  email,
  url,
  phone,
  password,
  username,
  number,
  creditCard,
  cardExpiry,
  cvv,
  filePath;

  /// How the type is named in a message — 'card number', not 'creditCard'.
  String get label => switch (this) {
    InputType.text => 'text',
    InputType.email => 'email',
    InputType.url => 'URL',
    InputType.phone => 'phone number',
    InputType.password => 'password',
    InputType.username => 'username',
    InputType.number => 'number',
    InputType.creditCard => 'card number',
    InputType.cardExpiry => 'expiry date',
    InputType.cvv => 'security code',
    InputType.filePath => 'file path',
  };
}

/// The outcome of validating one value.
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    required this.sanitizedValue,
    this.error,
  });

  /// A value that passed, carrying its cleaned form.
  factory ValidationResult.valid(String sanitized) =>
      ValidationResult(isValid: true, sanitizedValue: sanitized);

  /// A value that failed, keeping the original so it can be shown back.
  factory ValidationResult.invalid(String error, String original) =>
      ValidationResult(isValid: false, sanitizedValue: original, error: error);

  final bool isValid;

  /// Trimmed and normalised for its type — what you store. Untouched on
  /// failure.
  final String sanitizedValue;

  /// A message to show under the field, or null when [isValid].
  final String? error;

  @override
  String toString() => isValid
      ? 'ValidationResult.valid($sanitizedValue)'
      : 'ValidationResult.invalid($error)';
}

/// The rule [InputType.password] is checked against. Set
/// [ValidationService.passwordPolicy] once at startup to change it app-wide.
class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 6,
    this.maxLength = 128,
    this.requiredClasses = 3,
  });

  final int minLength;
  final int maxLength;

  /// How many of upper case, lower case, digit and symbol must appear (0-4).
  final int requiredClasses;

  /// Length over composition, in the spirit of NIST 800-63B.
  static const PasswordPolicy lengthOnly = PasswordPolicy(
    minLength: 12,
    requiredClasses: 0,
  );
}

/// Validates and cleans user input.
///
/// It does not screen for SQL keywords — a blocklist rejects real input like
/// "O'Brien" and buys no safety, since parameterised queries stop injection.
/// It does not HTML-escape either: Flutter renders text, so escaping on the
/// way in corrupts stored values. Use [escapeHtml] where you build HTML.
class ValidationService {
  const ValidationService._();

  /// The rule [InputType.password] is measured against. Assign once at startup.
  static PasswordPolicy passwordPolicy = const PasswordPolicy();

  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
  static final _phoneShapeRegex = RegExp(r'^\+?[\d\-() .]+$');
  static final _cvvRegex = RegExp(r'^\d{3,4}$');

  static final _upperRegex = RegExp(r'[A-Z]');
  static final _lowerRegex = RegExp(r'[a-z]');
  static final _digitRegex = RegExp(r'[0-9]');
  static final _symbolRegex = RegExp(r'[^A-Za-z0-9]');

  static final _nonDigits = RegExp(r'\D');
  static final _whitespace = RegExp(r'\s');

  /// Stripped rather than rejected — they arrive by paste accident, and there
  /// is nothing a user can do about an error naming them.
  static final _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  static final _markupPatterns = [
    RegExp(
      r'<script|javascript:|data:text/html|onerror\s*=|onload\s*=|onclick\s*=|<iframe',
      caseSensitive: false,
    ),
  ];

  static final _pathTraversalPatterns = [RegExp(r'\.\./|\.\.\\|%2e%2e')];

  /// Checks [value] against the rule for [inputType].
  ///
  /// An empty value passes — whether a field is required is the form's call.
  /// Order is clean, length, safety, shape; the first failure is returned.
  static ValidationResult validate(
    String value, {
    required InputType inputType,
    int minLength = 1,
    int maxLength = 1000,
    bool trimWhitespace = true,
  }) {
    if (value.isEmpty) return ValidationResult.valid(value);

    final cleaned = _clean(value, inputType, trim: trimWhitespace);

    if (cleaned.isEmpty) {
      return ValidationResult.invalid('Cannot be blank', value);
    }
    if (cleaned.length < minLength) {
      return ValidationResult.invalid(
        'Must be at least $minLength characters',
        value,
      );
    }
    if (cleaned.length > maxLength) {
      return ValidationResult.invalid(
        'Must be at most $maxLength characters',
        value,
      );
    }

    final unsafe = _unsafeReason(cleaned, inputType);
    if (unsafe != null) return ValidationResult.invalid(unsafe, value);

    final wrongShape = _shapeError(cleaned, inputType);
    if (wrongShape != null) return ValidationResult.invalid(wrongShape, value);

    return ValidationResult.valid(cleaned);
  }

  /// Tidying only — it never removes characters that would have made the value
  /// invalid, so a bad value still fails instead of being repaired.
  static String _clean(String value, InputType type, {required bool trim}) {
    final withoutControls = value.replaceAll(_controlChars, '');

    // A password is opaque — trimming would measure the wrong string.
    if (type == InputType.password) return withoutControls;

    final cleaned = trim ? withoutControls.trim() : withoutControls;

    return switch (type) {
      InputType.email => cleaned.replaceAll(_whitespace, '').toLowerCase(),
      InputType.url ||
      InputType.username => cleaned.replaceAll(_whitespace, ''),
      _ => cleaned,
    };
  }

  /// The safety checks, each scoped to the type it applies to.
  static String? _unsafeReason(String value, InputType type) {
    if (type == InputType.filePath) {
      for (final pattern in _pathTraversalPatterns) {
        if (pattern.hasMatch(value)) {
          return 'Contains a path traversal sequence';
        }
      }
    }

    // Markup matters for values that end up inside a WebView or an HTML mail.
    // The false-positive rate on prose is near zero, so free text keeps it.
    if (type == InputType.text) {
      for (final pattern in _markupPatterns) {
        if (pattern.hasMatch(value)) return 'Contains scripts or markup';
      }
    }

    return null;
  }

  /// Whether the value is shaped like its type. Returns the message, or null
  /// when it is fine.
  static String? _shapeError(String value, InputType type) => switch (type) {
    InputType.email =>
      value.length <= 254 && _emailRegex.hasMatch(value)
          ? null
          : 'Invalid ${type.label}',
    InputType.url => _urlError(value),
    InputType.phone => _phoneError(value),
    InputType.username =>
      _usernameRegex.hasMatch(value)
          ? null
          : 'Use 3-20 letters, numbers, - or _',
    InputType.password => _passwordError(value),
    InputType.number =>
      num.tryParse(value) == null ? 'Invalid ${type.label}' : null,
    InputType.creditCard => _cardError(value),
    InputType.cardExpiry => _expiryError(value),
    InputType.cvv =>
      _cvvRegex.hasMatch(value.replaceAll(_nonDigits, ''))
          ? null
          : 'Invalid ${type.label}',
    InputType.text || InputType.filePath => null,
  };

  static String? _urlError(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return 'Invalid URL';

    // Checked before the host so a `javascript:` or `file:` URL is reported as
    // the scheme problem it is. The allowlist is the point of validating a URL.
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Only http and https links are allowed';
    }
    if (uri.host.isEmpty) return 'Invalid URL';
    return null;
  }

  static String? _phoneError(String value) {
    if (!_phoneShapeRegex.hasMatch(value)) return 'Invalid phone number';

    // E.164 tops out at 15 digits, and nothing shorter than 7 is dialable.
    final digits = value.replaceAll(_nonDigits, '').length;
    return digits < 7 || digits > 15 ? 'Invalid phone number' : null;
  }

  static String? _passwordError(String value) {
    final policy = passwordPolicy;

    if (value.length < policy.minLength) {
      return 'Password must be at least ${policy.minLength} characters';
    }
    if (value.length > policy.maxLength) {
      return 'Password must be at most ${policy.maxLength} characters';
    }
    if (policy.requiredClasses <= 0) return null;

    final classes = [
      _upperRegex,
      _lowerRegex,
      _digitRegex,
      _symbolRegex,
    ].where((pattern) => pattern.hasMatch(value)).length;

    if (classes < policy.requiredClasses) {
      return 'Password needs ${policy.requiredClasses} of: an upper case '
          'letter, a lower case letter, a number, a symbol';
    }
    return null;
  }

  static String? _cardError(String value) {
    final digits = value.replaceAll(_nonDigits, '');
    if (digits.length < 13 || digits.length > 19) return 'Invalid card number';
    return luhnCheck(digits) ? null : 'Invalid card number';
  }

  /// Accepts whatever the field's mask produced — `MM/YY`, `MMYY` or `MM/YYYY`.
  static String? _expiryError(String value) {
    final digits = value.replaceAll(_nonDigits, '');
    if (digits.length != 4 && digits.length != 6) return 'Invalid expiry date';

    final month = int.parse(digits.substring(0, 2));
    if (month < 1 || month > 12) return 'Invalid expiry date';

    final year = digits.length == 4
        ? 2000 + int.parse(digits.substring(2))
        : int.parse(digits.substring(2));

    // Day 0 of the next month is the last day of this one — a card is good
    // through the end of the month it names.
    final expiresAt = DateTime(year, month + 1, 0, 23, 59, 59);
    return expiresAt.isBefore(DateTime.now()) ? 'Card has expired' : null;
  }

  /// The Luhn checksum every card number carries. Public so a payment form can
  /// use it while typing.
  static bool luhnCheck(String cardNumber) {
    var sum = 0;
    var isEven = false;

    for (var i = cardNumber.length - 1; i >= 0; i--) {
      var digit = int.tryParse(cardNumber[i]);
      if (digit == null) return false;

      if (isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      isEven = !isEven;
    }

    return sum % 10 == 0;
  }

  /// Escapes the five characters that matter in HTML. Call it where you build
  /// HTML, not on the way into your database, or you will store the escapes.
  static String escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  /// Validates a whole form at once, keyed the same way as [inputs]. A key
  /// missing from [types] is invalid, so an unwired field cannot pass.
  static Map<String, ValidationResult> validateMultiple(
    Map<String, String> inputs,
    Map<String, InputType> types, {
    Map<String, int> minLengths = const {},
    Map<String, int> maxLengths = const {},
  }) {
    return {
      for (final entry in inputs.entries)
        entry.key: switch (types[entry.key]) {
          null => ValidationResult.invalid(
            'No validation type defined',
            entry.value,
          ),
          final type => validate(
            entry.value,
            inputType: type,
            minLength: minLengths[entry.key] ?? 1,
            maxLength: maxLengths[entry.key] ?? 1000,
          ),
        },
    };
  }

  /// True when every result in [results] passed — the usual "can I submit?".
  static bool allValid(Map<String, ValidationResult> results) =>
      results.values.every((result) => result.isValid);

  /// The failures only, keyed by field, ready to hand to a form.
  static Map<String, String> errorsOf(Map<String, ValidationResult> results) =>
      {
        for (final entry in results.entries)
          if (!entry.value.isValid) entry.key: entry.value.error!,
      };
}
''';
}
