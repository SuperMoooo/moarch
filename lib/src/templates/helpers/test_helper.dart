/// Test helper
class TestHelper {
  TestHelper._();

  /// Test helper
  static String testHelper() => '''

import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';

// ── File System ──────────────────────────────────────────────────────────────
class FakeFile extends Fake implements File {}

class FakeDirectory extends Fake implements Directory {}

class FakeFileStat extends Fake implements FileStat {}

class FakeIOSink extends Fake implements IOSink {}

class FakeRandomAccessFile extends Fake implements RandomAccessFile {}

// ── HTTP / Networking ────────────────────────────────────────────────────────
class FakeHttpClient extends Fake implements HttpClient {}

class FakeHttpClientRequest extends Fake implements HttpClientRequest {}

class FakeHttpClientResponse extends Fake implements HttpClientResponse {}

class FakeHttpHeaders extends Fake implements HttpHeaders {}

// ── Streams & Sinks ──────────────────────────────────────────────────────────
class FakeStream<T> extends Fake implements Stream<T> {}

class FakeStreamSubscription<T> extends Fake implements StreamSubscription<T> {}

class FakeStreamController<T> extends Fake implements StreamController<T> {}

class FakeEventSink<T> extends Fake implements EventSink<T> {}

// ── Futures ──────────────────────────────────────────────────────────────────
class FakeCompleter<T> extends Fake implements Completer<T> {}

// ── Others ──────────────────────────────────────────────────────────────────

class FakePageController extends Fake implements PageController {}

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
