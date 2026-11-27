import 'dart:io';

import 'package:moarch/src/templates/bloc/app_templates.dart' as bloc;
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/riverpod/app_templates.dart' as riverpod;
import 'package:moarch/src/utils/project_inspector.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Request IDs on every Dio call, and Sentry as an error reporter: what ties
/// a failure in the app to the backend's log lines for it.
void main() {
  group('request IDs', () {
    test('every call gets one, set once so its retries share it', () {
      final output = CoreTemplates.requestId();

      expect(output, contains("const requestIdHeader = 'X-Request-ID';"));
      expect(
        output,
        contains('class RequestIdInterceptor extends Interceptor'),
      );
      expect(
        output,
        contains('options.headers.putIfAbsent(requestIdHeader, newRequestId);'),
      );
      expect(output, contains('Random.secure()'));
    });

    test('a failure is known by the ID the server answered with first', () {
      final output = CoreTemplates.requestId();

      expect(
        output,
        contains('error.response?.headers.value(requestIdHeader)'),
      );
      expect(output, contains('error.requestOptions.headers[requestIdHeader]'));
    });

    test('the Dio client adds the interceptor before any other', () {
      final output = CoreTemplates.dioClient(
        withAuthFeature: true,
        withRequestId: true,
      );

      expect(output, contains("import 'request_id.dart';"));
      final requestId = output.indexOf('RequestIdInterceptor()');
      expect(requestId, greaterThan(0));
      expect(requestId, lessThan(output.indexOf('InterceptorsWrapper(')));
      expect(requestId, lessThan(output.indexOf('RetryInterceptor(')));
    });

    test('a project without request_id.dart gets a client that compiles', () {
      final output = CoreTemplates.dioClient();

      expect(output, isNot(contains('request_id.dart')));
      expect(output, isNot(contains('RequestIdInterceptor')));
    });

    test('AppException carries the ID of the call that failed', () {
      final output = ErrorTemplates.appException(hasRequestId: true);

      expect(output, contains("import '../network/request_id.dart';"));
      expect(output, contains('final String? requestId;'));
      expect(output, contains('final requestId = requestIdOf(dioError);'));
      expect(output, contains('code: code, requestId: requestId)'));
      expect(output, contains(r"request ${requestId ?? '-'}"));
    });

    test('AppException without request_id.dart still compiles', () {
      final output = ErrorTemplates.appException();

      // The field is always there; only reading it needs the file.
      expect(output, contains('final String? requestId;'));
      expect(output, isNot(contains('request_id.dart')));
      expect(output, isNot(contains('requestIdOf')));
    });

    test('there is no request ID without Dio', () {
      final output = ErrorTemplates.appException(
        hasDio: false,
        hasFirebase: true,
        hasRequestId: true,
      );

      expect(output, isNot(contains('request_id.dart')));
    });
  });

  group('Sentry', () {
    for (final (name, mainDart) in [
      ('riverpod', riverpod.AppTemplates.mainDart),
      ('bloc', bloc.AppTemplates.mainDart),
    ]) {
      test('$name main.dart starts Sentry and reports from both handlers', () {
        final output = mainDart(withSentry: true);

        expect(
          output,
          contains("import 'package:sentry_flutter/sentry_flutter.dart';"),
        );
        expect(output, contains('await SentryFlutter.init((options) {'));
        expect(
          output,
          contains(
            "kReleaseMode ? const String.fromEnvironment('SENTRY_DSN') : ''",
          ),
        );
        expect(output, contains('..captureFailedRequests = false;'));
        expect(
          output,
          contains('Sentry.captureException(error, stackTrace: st);'),
        );
        expect(
          output,
          contains(
            'Sentry.captureException(details.exception, stackTrace: details.stack);',
          ),
        );
        // Started before the handlers that replace its own are installed.
        expect(
          output.indexOf('SentryFlutter.init'),
          lessThan(output.indexOf('PlatformDispatcher.instance.onError')),
        );
      });

      test('$name main.dart omits Sentry by default', () {
        expect(mainDart(), isNot(contains('Sentry')));
      });
    }

    test('AppException reports to Sentry with the request ID as a tag', () {
      final output = ErrorTemplates.appException(
        hasSentry: true,
        hasRequestId: true,
      );

      expect(
        output,
        contains("import 'package:sentry_flutter/sentry_flutter.dart';"),
      );
      expect(output, contains("scope.setTag('request_id', requestId ?? '-')"));
      expect(
        output,
        contains('Sentry.captureException(error, stackTrace: stackTrace);'),
      );
    });

    test('AppException omits Sentry by default', () {
      expect(ErrorTemplates.appException(), isNot(contains('Sentry')));
    });

    test('appLogger mirrors records into Sentry as breadcrumbs', () {
      final output = CoreTemplates.appLogger(withSentry: true);

      expect(
        output,
        contains("import 'package:sentry_flutter/sentry_flutter.dart';"),
      );
      expect(output, contains('_SentryOutput(),'));
      expect(output, contains('Sentry.addBreadcrumb('));
      expect(output, isNot(contains('FirebaseCrashlytics')));
    });

    test('appLogger can mirror into Crashlytics and Sentry at once', () {
      final output = CoreTemplates.appLogger(
        withCrashlytics: true,
        withSentry: true,
      );

      expect(output, contains('  _CrashlyticsOutput(),\n  _SentryOutput(),\n'));
    });

    test('the Dio client hands its calls to sentry_dio last', () {
      final output = CoreTemplates.dioClient(withSentry: true);

      expect(output, contains("import 'package:sentry_dio/sentry_dio.dart';"));
      expect(
        output.indexOf('dio.addSentry();'),
        greaterThan(output.indexOf('LogInterceptor(')),
      );
      expect(CoreTemplates.dioClient(), isNot(contains('addSentry')));
    });
  });

  group('detection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_observability');
    });
    tearDown(() => tempDir.delete(recursive: true));

    Future<void> writePubspec(String dependencies) => File(
      p.join(tempDir.path, 'pubspec.yaml'),
    ).writeAsString('name: demo\n\ndependencies:\n$dependencies');

    Future<void> writeDioClient() => File(
      p.join(tempDir.path, 'lib', 'core', 'network', 'dio_client.dart'),
    ).create(recursive: true);

    test('Sentry is read off the pubspec, sentry_dio only with Dio', () async {
      await writePubspec('  sentry_flutter: ^10.7.0\n  sentry_dio: ^10.7.0\n');
      final withoutDio = ScaffoldContext.detect(tempDir.path);
      expect(withoutDio.hasSentry, isTrue);
      expect(withoutDio.hasSentryDio, isFalse);

      await writeDioClient();
      expect(ScaffoldContext.detect(tempDir.path).hasSentryDio, isTrue);
    });

    test('hasRequestId reads request_id.dart off disk', () async {
      await writePubspec('  dio: ^5.11.1\n');
      expect(ScaffoldContext.detect(tempDir.path).hasRequestId, isFalse);

      await File(
        p.join(tempDir.path, 'lib', 'core', 'network', 'request_id.dart'),
      ).create(recursive: true);
      expect(ScaffoldContext.detect(tempDir.path).hasRequestId, isTrue);
    });

    test('doctor adds request_id.dart to an older Dio project', () async {
      await writePubspec('  dio: ^5.11.1\n');
      await writeDioClient();

      final before = await ProjectInspector.inspect(tempDir.path);
      final finding = before.singleWhere(
        (d) => d.message.contains('X-Request-ID'),
      );
      expect(finding.fix, isNotNull);

      await finding.fix!();
      final written = File(
        p.join(tempDir.path, 'lib', 'core', 'network', 'request_id.dart'),
      );
      expect(written.readAsStringSync(), CoreTemplates.requestId());
      final after = await ProjectInspector.inspect(tempDir.path);
      expect(after.where((d) => d.message.contains('X-Request-ID')), isEmpty);
    });
  });
}
