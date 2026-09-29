import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/core/core_templates.dart';
import 'dart_source.dart';

/// What [ApiConstantsUtils.register] did with a feature's endpoint.
enum EndpointPatchResult {
  /// The project has no `api_constants.dart`.
  noConstants,

  /// The constant went in above the anchor.
  added,

  /// `ApiConstants` already declares it — `create feature` re-run on a
  /// feature whose endpoint is there.
  alreadyThere,

  /// The file has no [ApiConstantsUtils.anchor] (a project from before the
  /// anchor, or one that removed it), so it was not touched.
  missingAnchor;

  /// Whether the datasource can name the endpoint as `ApiConstants.<name>`.
  bool get declared => this == added || this == alreadyThere;
}

/// Adds a feature's endpoint to `ApiConstants` — the constants' counterpart
/// to `RouterUtils`.
///
/// Every path the app calls lives in `lib/core/constants/api_constants.dart`,
/// so `create feature` declares the new feature's there, above the [anchor]
/// comment the template carries, and the datasource refers to it by name.
abstract final class ApiConstantsUtils {
  /// The comment each endpoint is inserted above. Load-bearing: the generated
  /// source says so.
  static const String anchor = CoreTemplates.endpointsAnchor;

  /// `lib/core/constants/api_constants.dart` inside [libPath].
  static String fileFor(String libPath) =>
      p.join(libPath, 'core', 'constants', 'api_constants.dart');

  /// The API path for [featureName] — the same one the datasource used to
  /// spell inline.
  static String pathFor(String featureName) => '/$featureName';

  /// The `ApiConstants` line declaring [featureName]'s endpoint.
  static String endpointConstant(String featureName, String varName) =>
      "  static const $varName = '${pathFor(featureName)}';";

  /// Declares [featureName]'s endpoint as `ApiConstants.<varName>`.
  static Future<EndpointPatchResult> register(
    String libPath, {
    required String featureName,
    required String varName,
  }) async {
    final file = File(fileFor(libPath));
    if (!file.existsSync()) return EndpointPatchResult.noConstants;

    final source = file.readAsStringSync();
    if (CoreTemplates.declaredEndpoints(source).contains(varName)) {
      return EndpointPatchResult.alreadyThere;
    }
    final patched = DartSource.insertAbove(
      source,
      anchor,
      endpointConstant(featureName, varName),
    );
    if (patched == null) return EndpointPatchResult.missingAnchor;
    await file.writeAsString(patched);
    return EndpointPatchResult.added;
  }
}
