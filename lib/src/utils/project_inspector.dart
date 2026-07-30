import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/ui/shared_templates.dart';
import 'file_utils.dart';
import 'project_manifest.dart';
import 'pubspec_utils.dart';
import 'widget_catalog.dart';

/// How much a [Diagnostic] matters.
enum DiagnosticSeverity {
  /// The project is broken or will not build as generated.
  error,

  /// Works, but something is inconsistent or half-configured.
  warning,

  /// Informational — nothing is wrong.
  info,
}

/// Applies a fix for a [Diagnostic], returning a description of what it did.
typedef DiagnosticFix = Future<String> Function();

/// One finding from [ProjectInspector.inspect].
class Diagnostic {
  /// Creates a diagnostic.
  const Diagnostic({
    required this.severity,
    required this.message,
    this.hint,
    this.fix,
  });

  /// An error-level finding.
  const Diagnostic.error(this.message, {this.hint, this.fix})
      : severity = DiagnosticSeverity.error;

  /// A warning-level finding.
  const Diagnostic.warning(this.message, {this.hint, this.fix})
      : severity = DiagnosticSeverity.warning;

  /// How much this finding matters.
  final DiagnosticSeverity severity;

  /// One-line description of what is wrong.
  final String message;

  /// What the user should do about it, when there is no automatic fix.
  final String? hint;

  /// Applies the fix, or null when this needs a human decision.
  final DiagnosticFix? fix;

  /// Whether `doctor --fix` can resolve this without asking.
  bool get isFixable => fix != null;
}

/// Inspects a project previously scaffolded by moarch.
///
/// This is the shared answer to "what did moarch generate here, and is it
/// still coherent?" — `doctor` reports and fixes the findings, `update`
/// uses the same widget detection to decide what it can refresh.
abstract final class ProjectInspector {
  /// Every check, in reporting order.
  ///
  /// Structural checks come first because a missing `lib/core/` makes the
  /// widget and dependency findings below it noise rather than signal.
  static Future<List<Diagnostic>> inspect(String projectRoot) async {
    final root = p.absolute(projectRoot);
    final libPath = p.join(root, 'lib');
    final pubspecFile = File(p.join(root, 'pubspec.yaml'));
    final pubspec =
        pubspecFile.existsSync() ? pubspecFile.readAsStringSync() : null;

    return [
      ..._structure(root, libPath),
      if (pubspec != null) ..._dependencies(libPath, pubspec),
      if (pubspec != null) ..._localization(libPath, pubspec),
      ..._codegen(libPath),
      ..._widgets(root, libPath, pubspec),
    ];
  }

  // ── Structure ───────────────────────────────────────────────────────────────

  static List<Diagnostic> _structure(String root, String libPath) {
    final expected = <String, bool>{
      'lib/core/': Directory(p.join(libPath, 'core')).existsSync(),
      'lib/config/': Directory(p.join(libPath, 'config')).existsSync(),
      'lib/shared/': Directory(p.join(libPath, 'shared')).existsSync(),
      'lib/main.dart': File(p.join(libPath, 'main.dart')).existsSync(),
      'pubspec.yaml': File(p.join(root, 'pubspec.yaml')).existsSync(),
      '.env': File(p.join(root, '.env')).existsSync(),
      '.fvmrc': File(p.join(root, '.fvmrc')).existsSync(),
    };

    return [
      for (final entry in expected.entries)
        if (!entry.value)
          Diagnostic.error(
            '${entry.key} is missing',
            hint: 'Run `moarch init` to scaffold it.',
          ),
    ];
  }

  // ── Dependencies ────────────────────────────────────────────────────────────

  static List<Diagnostic> _dependencies(String libPath, String pubspec) {
    final findings = <Diagnostic>[
      if (!pubspec.contains('flutter_riverpod:'))
        const Diagnostic.error(
          'flutter_riverpod is missing from pubspec.yaml',
          hint: 'The generated notifiers and providers need it.',
        ),
      if (!pubspec.contains('envied:'))
        const Diagnostic.error(
          'envied is missing from pubspec.yaml',
          hint: 'config/env/app_env.dart is generated from .env by envied.',
        ),
    ];

    // go_router and config/router/ are generated together — one without the
    // other means an edit went half-applied.
    final hasRouterDep = pubspec.contains('go_router:');
    final hasRouterFiles =
        File(p.join(libPath, 'config', 'router', 'app_router.dart'))
            .existsSync();
    if (hasRouterDep != hasRouterFiles) {
      findings.add(
        Diagnostic.warning(
          hasRouterDep
              ? 'go_router is in pubspec.yaml but config/router/ is missing'
              : 'config/router/ exists but go_router is not in pubspec.yaml',
          hint: hasRouterDep
              ? 'Re-run `moarch init` and select the router option, or drop the dependency.'
              : 'Add `go_router` to pubspec.yaml and run `flutter pub get`.',
        ),
      );
    }

    return findings;
  }

  // ── Localization ────────────────────────────────────────────────────────────

  /// `moarch init` keeps the two localization approaches mutually exclusive,
  /// but nothing stops a later hand-edit from installing both — at which
  /// point `MaterialApp` has two competing sets of delegates.
  static List<Diagnostic> _localization(String libPath, String pubspec) {
    final hasFlutterL10n = pubspec.contains('flutter_localizations:');
    final hasEasyL10n = pubspec.contains('easy_localization:');

    if (hasFlutterL10n && hasEasyL10n) {
      return [
        const Diagnostic.warning(
          'both flutter_localizations and easy_localization are installed',
          hint: 'moarch generates one or the other. Pick one and remove the '
              'other from pubspec.yaml — two sets of localization delegates '
              'will fight over MaterialApp.',
        ),
      ];
    }

    // The dependency without its files is a build failure waiting to happen.
    if (hasFlutterL10n &&
        !Directory(p.join(libPath, 'l10n')).existsSync() &&
        !File(p.join(p.dirname(libPath), 'l10n.yaml')).existsSync()) {
      return [
        const Diagnostic.warning(
          'flutter_localizations is installed but lib/l10n/ is missing',
          hint: 'Run `flutter gen-l10n`, or re-run `moarch init` to scaffold '
              'the .arb files.',
        ),
      ];
    }

    return const [];
  }

  // ── Code generation ─────────────────────────────────────────────────────────

  /// `config/env/app_env.dart` is a `part` of an envied-generated file. Until
  /// `build_runner` has run, `app_env.g.dart` doesn't exist and the project
  /// does not compile — the single most common first-run failure.
  static List<Diagnostic> _codegen(String libPath) {
    final envDart = File(p.join(libPath, 'config', 'env', 'app_env.dart'));
    final envGenerated =
        File(p.join(libPath, 'config', 'env', 'app_env.g.dart'));

    if (envDart.existsSync() && !envGenerated.existsSync()) {
      return [
        const Diagnostic.error(
          'config/env/app_env.g.dart has not been generated',
          hint: 'Run: dart run build_runner build --delete-conflicting-outputs',
        ),
      ];
    }
    return const [];
  }

  // ── Widget kit ──────────────────────────────────────────────────────────────

  /// The catalog slugs whose file is present under `lib/shared/widgets/`.
  static List<WidgetSpec> generatedWidgets(String libPath) {
    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    return WidgetCatalog.all
        .where((spec) => File(p.join(widgetsRoot, spec.file)).existsSync())
        .toList();
  }

  /// Two ways the kit drifts out of sync, both of which stop the project
  /// compiling: a widget whose dependency was never generated (broken
  /// import), and a widget whose pub package was never added (unresolved
  /// package import). Both are mechanically fixable from the catalog.
  static List<Diagnostic> _widgets(
    String root,
    String libPath,
    String? pubspec,
  ) {
    final present = generatedWidgets(libPath);
    if (present.isEmpty) return const [];

    final presentNames = {for (final spec in present) spec.name};
    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    final findings = <Diagnostic>[];

    // Missing widget dependencies.
    final missingDeps = <String, Set<String>>{};
    for (final spec in present) {
      for (final dep in spec.deps) {
        if (!presentNames.contains(dep)) {
          missingDeps.putIfAbsent(dep, () => <String>{}).add(spec.name);
        }
      }
    }

    for (final entry in missingDeps.entries) {
      final dep = WidgetCatalog.byName(entry.key);
      if (dep == null) continue;
      final dependents = entry.value.toList()..sort();
      findings.add(
        Diagnostic.error(
          '${dep.title} is missing but imported by '
          '${dependents.join(', ')}',
          hint: 'Run: moarch create widget ${dep.name}',
          // Does exactly what the hint says, dependencies and pub packages
          // included — generating the widget alone would just surface its own
          // missing dependency on the next run.
          fix: () async {
            final manifest = ProjectManifest.loadOrCreate(root);
            final written = <String>[];
            final packages = <String>{};

            for (final spec in WidgetCatalog.resolve([dep.name])) {
              final path = p.join(widgetsRoot, spec.file);
              final content = widgetSource(libPath, spec);
              if (await FileUtils.writeFile(path, content)) {
                manifest.record(root, path, content);
                written.add(spec.file);
              }
              packages.addAll(spec.packages);
            }

            if (packages.isNotEmpty) {
              await PubspecUtils.ensureDependencies(
                root,
                dependencies: packages.toList(),
              );
            }
            if (written.isNotEmpty) await manifest.save(root);

            return 'generated ${written.map((f) => 'shared/widgets/$f').join(', ')}';
          },
        ),
      );
    }

    // Missing pub packages for generated widgets.
    if (pubspec != null) {
      final missingPackages = <String, Set<String>>{};
      for (final spec in present) {
        for (final package in spec.packages) {
          final name = package.replaceAll(':', '').trim();
          if (!pubspec.contains('$name:')) {
            missingPackages.putIfAbsent(name, () => <String>{}).add(spec.title);
          }
        }
      }

      for (final entry in missingPackages.entries) {
        final users = entry.value.toList()..sort();
        findings.add(
          Diagnostic.error(
            '${entry.key} is missing from pubspec.yaml but needed by '
            '${users.join(', ')}',
            hint:
                'Add `${entry.key}` to pubspec.yaml and run `flutter pub get`.',
            fix: () async {
              await PubspecUtils.ensureDependencies(
                root,
                dependencies: ['${entry.key}: '],
              );
              return 'added ${entry.key} to pubspec.yaml (run `flutter pub get`)';
            },
          ),
        );
      }
    }

    // Router-dependent widgets need config/router/app_router.dart for the
    // rootNavigatorKey they import.
    final needsRouter = present.where((spec) => spec.needsRouter).toList();
    final hasRouter =
        File(p.join(libPath, 'config', 'router', 'app_router.dart'))
            .existsSync();
    if (needsRouter.isNotEmpty && !hasRouter) {
      final names = needsRouter.map((spec) => spec.title).toList()..sort();
      findings.add(
        Diagnostic.error(
          '${names.join(', ')} import config/router/app_router.dart, which is missing',
          hint: 'Generate the GoRouter setup, or point them at your own '
              'navigator key.',
        ),
      );
    }

    return findings;
  }

  /// The current template source for [spec], matching how the generator
  /// writes it — `AppButton` varies with the biometric option.
  static String widgetSource(String libPath, WidgetSpec spec) {
    if (spec.name != 'button') return spec.template();
    final hasBiometric =
        File(p.join(libPath, 'core', 'security', 'biometric_service.dart'))
            .existsSync();
    return SharedTemplates.appButton(hasBiometricAuth: hasBiometric);
  }
}
