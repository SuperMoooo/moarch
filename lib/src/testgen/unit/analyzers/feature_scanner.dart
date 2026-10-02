import 'dart:io';

import 'package:path/path.dart' as p;

/// Scans `lib/features` and groups logic (notifier / bloc / cubit), state and
/// event files by feature.
class FeatureScanner {
  /// Creates a scanner rooted at [featuresRoot].
  FeatureScanner({required this.featuresRoot});

  /// Absolute path to the `lib/features` directory.
  final String featuresRoot;

  /// Folder names that conventionally hold the state-management classes,
  /// covering both the Riverpod layout (`notifiers/`) and the common
  /// `flutter_bloc` ones (`bloc/`, `blocs/`, `cubit/`). A folder counts
  /// wherever it sits in the feature, so a feature with a folder per screen
  /// (`presentation/list/blocs/`, `presentation/notifiers/create/`) is
  /// scanned the same as a flat one.
  static const logicFolders = {
    'notifiers',
    'notifier',
    'bloc',
    'blocs',
    'cubit',
    'cubits',
    'logic',
  };

  /// File-name suffixes that mark a state-management file outside any of the
  /// [logicFolders] — `presentation/list/list_bloc.dart`, where the screen's
  /// folder is the only grouping.
  static const logicSuffixes = [
    '_notifier.dart',
    '_bloc.dart',
    '_cubit.dart',
    '_event.dart',
  ];

  /// Folder names that conventionally hold the state models, wherever they
  /// sit in the feature. Bloc projects usually keep the state next to the
  /// bloc instead, which [scan] handles by also treating every
  /// `*_state.dart` file as a state file.
  static const stateFolders = {'states', 'state'};

  /// Layers of a feature that never hold state-management classes.
  static const _skippedLayers = {'data', 'domain'};

  /// Scans the configured features directory and returns discovered bundles.
  List<FeatureBundle> scan() {
    final dir = Directory(featuresRoot);
    if (!dir.existsSync()) {
      throw ArgumentError('Features directory not found: $featuresRoot');
    }

    final bundles = <FeatureBundle>[];

    for (final featureDir in dir.listSync().whereType<Directory>()) {
      final featureName = p.basename(featureDir.path);

      final logicFiles = <String>{};
      final stateFiles = <String>{};
      for (final file in _dartFiles(featureDir)) {
        final segments = p.split(p.relative(file, from: featureDir.path));
        if (_skippedLayers.contains(segments.first)) continue;
        final folders = segments.sublist(0, segments.length - 1);
        final name = segments.last;

        final inLogicFolder = folders.any(logicFolders.contains);
        if (inLogicFolder || logicSuffixes.any(name.endsWith)) {
          logicFiles.add(file);
        }
        // Bloc convention: `auth_state.dart` sits beside `auth_bloc.dart`,
        // usually as a `part` of it, rather than in a `states/` folder.
        if (folders.any(stateFolders.contains) ||
            name.endsWith('_state.dart')) {
          stateFiles.add(file);
        }
      }
      if (logicFiles.isEmpty) continue;

      bundles.add(
        FeatureBundle(
          featureName: featureName,
          featurePath: featureDir.path,
          notifierFiles: logicFiles.toList(),
          stateFiles: stateFiles.toList(),
          // Event classes live either in a dedicated `*_event.dart` file or
          // inline in the bloc file itself, so every logic file is a candidate.
          eventFiles: logicFiles.toList(),
        ),
      );
    }

    return bundles;
  }

  List<String> _dartFiles(Directory dir) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path)
      .toList();
}

/// A discovered feature with its logic, state and event source files.
class FeatureBundle {
  /// Creates a bundle for one feature.
  const FeatureBundle({
    required this.featureName,
    required this.featurePath,
    required this.notifierFiles,
    required this.stateFiles,
    this.eventFiles = const [],
  });

  /// The feature directory name.
  final String featureName;

  /// The absolute path to the feature directory.
  final String featurePath;

  /// Source files that declare notifiers, blocs or cubits.
  final List<String> notifierFiles;

  /// Source files that declare state classes.
  final List<String> stateFiles;

  /// Source files that may declare bloc event classes.
  final List<String> eventFiles;
}
