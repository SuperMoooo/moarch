import 'package:dart_style/dart_style.dart';

import '../../testgen_conventions.dart';
import '../models/datasource_info.dart';

/// Generates integration test files for GET datasource endpoints.
///
/// Each file holds one group for one endpoint: a fresh Dio client and
/// datasource per test, and a test that calls the datasource method against
/// the real API.
///
/// The test fails only when the server could not be reached. An error status
/// still proves the endpoint exists and answers, which is what these tests
/// are for — they are a smoke check of the wiring, not of the data. A moarch
/// datasource goes through `safeApiCall`, so a failure arrives as an
/// `AppException` (`NetworkException` for "unreachable"); a datasource calling
/// Dio directly still surfaces a `DioException`, and both are handled.
class IntegrationTestGenerator {
  final _fmt = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Generates a complete integration test file for [endpoint].
  String generate(EndpointInfo endpoint, {required String packageName}) {
    final importPath = _calculateImportPath(
      sourceFilePath: endpoint.sourceFilePath,
      packageName: packageName,
    );
    final args = endpoint.callArguments;

    final source =
        '''
${TestGenConventions.header}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
${TestGenConventions.appExceptionImport(packageName)}
import '$importPath';

import '../../dio_helper.dart';

void main() {
  group('GET ${endpoint.endpoint}', () {
    late Dio dio;
    late ${endpoint.className} datasource;

    setUp(() {
      dio = buildTestDio();
      datasource = ${endpoint.className}(${endpoint.constructorArguments});
    });

    test('calls ${endpoint.methodName}() and reaches the server', () async {
      try {
        await datasource.${endpoint.methodName}($args);
      } on NetworkException catch (e) {
        // safeApiCall's name for "the server could not be reached".
        fail('Connection failed: \${e.message}');
      } on AppException {
        // The server answered. An error status still proves the endpoint is
        // there and reachable, which is all this test checks.
      } on DioException catch (e) {
        // A datasource that calls Dio without safeApiCall.
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.unknown) {
          fail('Connection failed: \${e.message}');
        }
      }
    });
  });
}
''';

    try {
      return _fmt.format(source);
    } catch (_) {
      return source;
    }
  }

  /// The `package:` import for the datasource at [sourceFilePath].
  ///
  /// Throws [ArgumentError] if the file does not live under a `lib/`
  /// directory, since no valid `package:` import can be built for it.
  String _calculateImportPath({
    required String sourceFilePath,
    required String packageName,
  }) {
    final normalized = sourceFilePath.replaceAll('\\', '/');
    final libIndex = normalized.indexOf('/lib/');
    if (libIndex < 0) {
      throw ArgumentError('Datasource file is not under lib/: $sourceFilePath');
    }
    final relativePath = normalized.substring(libIndex + 5);
    return 'package:$packageName/$relativePath';
  }

  /// The shared `test/integration/dio_helper.dart`, written once and never
  /// overwritten — it is where the tests' base URL and login live.
  static String dioHelper(String packageName) =>
      '''
import 'package:dio/dio.dart';
import 'package:$packageName/config/env/app_env.dart';
import 'package:$packageName/core/constants/api_constants.dart';

/// A plain Dio client against the real API, for the integration tests in
/// this folder.
///
/// The base URL is `AppEnv.baseUrl` — BASE_URL from `.env`, the value the
/// app itself uses — so run `build_runner` before the tests, and point
/// `.env` at a server that is safe to call. Written once by
/// `moarch create tests`; edit it freely, it is never overwritten.
Dio buildTestDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppEnv.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
}

/// [buildTestDio], signed in — for endpoints that answer 401 to anyone
/// else.
Future<Dio> buildAuthenticatedTestDio() async {
  final dio = buildTestDio();
  // TODO: sign in with a test account and send its token, e.g.
  // final response = await dio.post(
  //   '/auth/login',
  //   data: {'email': 'test@example.com', 'password': '...'},
  // );
  // dio.options.headers['Authorization'] =
  //     'Bearer \${response.data['accessToken']}';
  return dio;
}
''';
}
