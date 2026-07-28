import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:test/test.dart';

void main() {
  group('validationService', () {
    final output = SecurityTemplates.validationService();

    test('does not ship a SQL keyword blocklist', () {
      // It rejected "O'Brien" and "Create the report" while buying no safety —
      // injection is stopped by parameterised queries, not by the client.
      expect(output, isNot(contains('_sqlInjectionPatterns')));
      expect(output.toLowerCase(), isNot(contains('union|select')));
      expect(output, contains('does not screen for SQL keywords'));
    });

    test('does not HTML-escape values on the way in', () {
      expect(output, isNot(contains('_htmlEncode')));
      expect(output, contains('static String escapeHtml('));
    });

    test('scopes each safety check to the type it applies to', () {
      expect(output, contains('if (type == InputType.filePath)'));
      expect(output, contains('if (type == InputType.text)'));
      expect(output, contains('_pathTraversalPatterns'));
      expect(output, contains('_markupPatterns'));
    });

    test('holds a URL to http and https', () {
      expect(
        output,
        contains("if (uri.scheme != 'http' && uri.scheme != 'https')"),
      );
    });

    test('covers the types the input formats map onto', () {
      for (final type in [
        'text',
        'email',
        'url',
        'phone',
        'password',
        'username',
        'number',
        'creditCard',
        'cardExpiry',
        'cvv',
        'filePath',
      ]) {
        expect(output, contains('  $type'), reason: '$type is missing');
      }
    });

    test('makes the password rule configurable', () {
      expect(output, contains('class PasswordPolicy'));
      expect(output, contains('static PasswordPolicy passwordPolicy'));
      expect(output, contains('static const PasswordPolicy lengthOnly'));
    });

    test('leaves a password untrimmed', () {
      expect(output, contains('if (type == InputType.password) return'));
    });

    test('needs no Riverpod — it is pure logic', () {
      expect(output, isNot(contains('flutter_riverpod')));
      expect(output, isNot(contains('validationServiceProvider')));
    });

    test('keeps the result shape callers already use', () {
      expect(output, contains('final bool isValid'));
      expect(output, contains('final String sanitizedValue'));
      expect(output, contains('final String? error'));
      expect(output, contains('factory ValidationResult.valid('));
      expect(output, contains('factory ValidationResult.invalid('));
    });
  });

  group('launchUrlService', () {
    test('validates the link as a URL, not as free text', () {
      final output = ServicesTemplates.launchUrlService();

      expect(output, contains('inputType: InputType.url'));
      expect(output, isNot(contains('inputType: InputType.text')));
    });
  });

  group('extensions', () {
    final output = CoreTemplates.extensions();

    test('keeps the database formatters', () {
      expect(output, contains('String get formatedDateTimeToDatabase'));
      expect(output, contains('String get formattedDateToDatabase'));
    });

    test('sends a real UTC instant to the database', () {
      // The trailing Z has to mean UTC, not "local time with a Z on it".
      expect(output, contains("toUtc().toIso8601String()"));
    });

    test('pads the display formats', () {
      expect(
        output,
        contains(
          "String get formattedDate =>\n"
          "      '\${day.toString().padLeft(2, '0')}/",
        ),
      );
      expect(
        output,
        contains(
          "String get formattedTime =>\n"
          "      '\${hour.toString().padLeft(2, '0')}:",
        ),
      );
    });

    test('adds the context helpers a screen actually reaches for', () {
      for (final member in [
        'bool get isDarkMode',
        'bool get isKeyboardOpen',
        'double get keyboardInset',
        'EdgeInsets get safeInsets',
        'bool get isTablet',
        'void unfocus()',
      ]) {
        expect(output, contains(member), reason: '$member is missing');
      }
    });

    test('adds the string helpers', () {
      for (final member in [
        'bool get isBlank',
        'String? get nullIfBlank',
        'String get capitalizeWords',
        'String get initials',
        'String truncate(',
        'bool get isNumeric',
        'String get digitsOnly',
        'String get withoutDiacritics',
        'String get searchKey',
        'bool matchesSearch(',
      ]) {
        expect(output, contains(member), reason: '$member is missing');
      }
    });

    test('adds the date, time and duration helpers', () {
      for (final member in [
        'DateTime get startOfDay',
        'DateTime get endOfDay',
        'DateTime get startOfMonth',
        'DateTime get endOfMonth',
        'bool get isTomorrow',
        'bool get isPast',
        'int get yearsSince',
        'TimeOfDay get toTimeOfDay',
        'int get minutesOfDay',
        'DateTime onDate(',
        'extension DurationX on Duration',
      ]) {
        expect(output, contains(member), reason: '$member is missing');
      }
    });

    test('adds the nullable helpers without colliding with package:collection',
        () {
      expect(output, contains('extension NullableStringX on String?'));
      expect(output, contains('extension NullableListX<T> on List<T>?'));
      // firstWhereOrNull belongs to package:collection; defining it here would
      // make the call ambiguous in any file that imports both.
      expect(output, isNot(contains('firstWhereOrNull')));
    });

    test('the diacritic tables line up', () {
      // withoutDiacritics maps index for index, so a table that drifts by one
      // character silently starts translating the wrong letters.
      final accented = RegExp(
        r"const _accented = '([^']*)'",
      ).firstMatch(output);
      final unaccented = RegExp(
        r"const _unaccented = '([^']*)'",
      ).firstMatch(output);

      expect(accented, isNotNull);
      expect(unaccented, isNotNull);
      expect(accented!.group(1)!.length, unaccented!.group(1)!.length);
      expect(unaccented.group(1), isNot(contains(' ')));
    });
  });
}
