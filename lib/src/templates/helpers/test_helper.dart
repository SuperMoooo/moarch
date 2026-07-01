/// Test helper
class TestHelper {
  TestHelper._();

  /// Test helper
  static String testHelper() => '''

import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';


// ── Fakes ───────────────────────
class FakeFile extends Fake implements File {}


// ── Mocks ───────────────────────
class MockGoRouter extends Mock implements GoRouter {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// ── Fallback values (register once, reuse everywhere) ───────────────────────
// Call this in your test main() or setUpAll()
void registerFallbacks() {
  registerFallbackValue(File(''));
  registerFallbackValue(Uri.parse('/'));
}

// ── Common Stubs/Whens ───────────────────────
// Use these extensions to keep your test files readable
extension SecureStorageStubs on MockFlutterSecureStorage {
  void mockRead({String? key, String? value}) {
    when(() => read(key: key ?? any(named: 'key')))
        .thenAnswer((_) async => value);
  }

  void mockWrite({String? key, String? value}) {
    when(() => write(key: key ?? any(named: 'key'), value: value ?? any(named: 'value')))
        .thenAnswer((_) async => {});
  }
}

extension GoRouterStubs on MockGoRouter {
  void mockGo(String location) {
    when(() => go(location)).thenReturn(null);
  }

  void mockPush(String location) {
    when(() => push(location)).thenReturn(null);
  }

  void mockPop() {
    when(() => pop()).thenReturn(null);
  }
}

 ''';
}
