/// Test helper
class TestHelper {
  TestHelper._();

  /// Test helper
  static String testHelper() => '''

import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';

// ── File System ──────────────────────────────────────────────────────────────
class MockFile extends Mock implements File {}

class MockDirectory extends Mock implements Directory {}

class MockFileStat extends Mock implements FileStat {}

class MockIOSink extends Mock implements IOSink {}

class MockRandomAccessFile extends Mock implements RandomAccessFile {}

// ── HTTP / Networking ────────────────────────────────────────────────────────
class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

// ── Streams & Sinks ──────────────────────────────────────────────────────────
class MockStream<T> extends Mock implements Stream<T> {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

class MockStreamController<T> extends Mock implements StreamController<T> {}

class MockEventSink<T> extends Mock implements EventSink<T> {}

// ── Futures ──────────────────────────────────────────────────────────────────
class MockCompleter<T> extends Mock implements Completer<T> {}

// ── Fallback values (register once, reuse everywhere) ───────────────────────
// Call this in your test main() or setUpAll()
void registerFallbacks() {
  registerFallbackValue(File(''));
  registerFallbackValue(Directory(''));
  registerFallbackValue(Uri());
  registerFallbackValue(<int>[]);
  registerFallbackValue(FileMode.read);
}

 ''';
}
