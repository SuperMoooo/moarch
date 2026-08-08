import 'package:moarch/src/templates/misc/android_templates.dart';
import 'package:moarch/src/templates/misc/docs_templates.dart';
import 'package:test/test.dart';

void main() {
  group('proguardRules', () {
    test(
        'keeps the classes R8 would otherwise strip out from under the '
        'engine and the plugins', () {
      final rules = AndroidTemplates.proguardRules();

      expect(rules, contains('-keep class io.flutter.** { *; }'));
      expect(rules, contains('-keep class com.google.firebase.** { *; }'));
      expect(rules, contains('-keep class okhttp3.** { *; }'));
      expect(rules, contains('-dontwarn kotlinx.coroutines.**'));
    });

    test('preserves line numbers, or a release stack trace is unreadable', () {
      final rules = AndroidTemplates.proguardRules();

      expect(rules, contains('-keepattributes SourceFile,LineNumberTable'));
      expect(rules, contains('-renamesourcefileattribute SourceFile'));
    });

    test('says up front that the rules are inert until R8 is enabled', () {
      expect(
        AndroidTemplates.proguardRules(),
        contains('docs/SECURITY_BEFORE_DEPLOYMENT.md'),
      );
    });
  });

  test('the security checklist documents the rules it generates', () {
    // Both come from the one template, so the doc cannot describe a file the
    // project does not have.
    final doc = DocsTemplates.securityChecklist();

    expect(doc, contains(AndroidTemplates.proguardRules()));
    expect(
        doc, contains('### ProGuard Rules — `android/app/proguard-rules.pro`'));
    // The fenced block is still closed after the substitution.
    expect('```proguard'.allMatches(doc).length, 1);
    expect('```'.allMatches(doc).length.isEven, isTrue);
  });
}
