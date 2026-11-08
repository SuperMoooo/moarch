import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/analytics_templates.dart';
import '../templates/core/cache_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/core/error_templates.dart';
import '../templates/core/feature_flags_templates.dart';
import '../templates/core/security_templates.dart';
import '../templates/core/services_templates.dart';
import '../templates/core/sync_templates.dart';
import '../templates/misc/agents_templates.dart';
import '../templates/misc/deep_links_templates.dart';
import '../templates/misc/android_templates.dart';
import '../templates/misc/dev_templates.dart';
import '../templates/misc/docs_templates.dart';
import '../templates/misc/offline_docs_templates.dart';
import '../templates/misc/project_docs_templates.dart';
import '../templates/misc/ios_templates.dart';
import '../templates/misc/readme_templates.dart';
import '../templates/misc/skills_templates.dart';
import '../templates/misc/workflow_templates.dart';
import '../templates/stack_templates.dart';
import 'state_management.dart';
import 'widget_catalog.dart';

/// The options a generated file's template varies with, read back off a
/// project that was scaffolded earlier.
///
/// `moarch init` picks these from a checklist; `moarch update` works them out
/// from what is on disk, the only record that stays true once the project is
/// edited.
class ScaffoldContext {
  /// Creates a context. Prefer [detect] — this exists for tests.
  const ScaffoldContext({required this.projectRoot, required this.pubspec});

  /// Reads [projectRoot] and works out which options it was generated with.
  factory ScaffoldContext.detect(String projectRoot) {
    final root = p.absolute(projectRoot);
    final pubspecFile = File(p.join(root, 'pubspec.yaml'));
    return ScaffoldContext(
      projectRoot: root,
      pubspec: pubspecFile.existsSync() ? pubspecFile.readAsStringSync() : '',
    );
  }

  /// Absolute path to the project root.
  final String projectRoot;

  /// The project's `pubspec.yaml`, or empty when it has none.
  final String pubspec;

  /// Absolute path to a project-relative, forward-slash [path].
  String resolve(String path) =>
      p.joinAll([projectRoot, ...p.posix.split(path)]);

  /// Whether the project has a file at the project-relative [path].
  bool hasFile(String path) => File(resolve(path)).existsSync();

  /// Whether [package] is a dependency.
  ///
  /// Matched as a whole entry rather than a substring, so `dio` is not
  /// reported by `dio_smart_retry` and `local_auth` not by `local_auth_android`.
  bool hasPackage(String package) => RegExp(
    '^\\s+${RegExp.escape(package)}:',
    multiLine: true,
  ).hasMatch(pubspec);

  /// The project talks to a REST API through Dio.
  bool get hasDio =>
      hasFile('lib/core/network/dio_client.dart') || hasPackage('dio');

  /// The state-management stack the project was generated against, read off
  /// `pubspec.yaml` — `flutter_bloc` says bloc, anything else says riverpod.
  StateManagement get stateManagement => StateManagement.fromPubspec(pubspec);

  /// The templates for this project's stack — what every state-bearing spec
  /// below generates through.
  StackTemplates get stack => StackTemplates(stateManagement);

  /// The project uses flutter_bloc rather than Riverpod.
  bool get hasBloc => stateManagement.isBloc;

  /// `bloc_concurrency` is installed, so a bloc may use `droppable()`. Read
  /// off the pubspec: a bloc project from before 9.0.0 does not have it.
  bool get hasBlocConcurrency => hasPackage('bloc_concurrency');

  /// Firestore or Firebase Auth is installed — either brings in
  /// `firebase_core`, and with it `FirebaseException`.
  bool get hasFirebase =>
      hasPackage('cloud_firestore') || hasPackage('firebase_auth');

  /// Any Firebase package at all, which is what the iOS build workflow keys
  /// off: it has to relink `GoogleService-Info.plist` for all of them.
  bool get hasAnyFirebase => hasPackage('firebase_core') || hasFirebase;

  /// Crash reporting is wired into the error handlers.
  bool get hasCrashlytics => hasPackage('firebase_crashlytics');

  /// `AnalyticsService` was generated (10.3.0 on, with Firebase Analytics).
  bool get hasAnalytics => hasFile('lib/core/services/analytics_service.dart');

  /// The GoRouter setup was generated.
  bool get hasRouter => hasFile('lib/config/router/app_router.dart');

  /// The project took the dark palette: `AppTheme` has a `dark` getter, and
  /// with it the `*Dark` half of `AppConstants`.
  ///
  /// Read off `app_theme.dart` rather than remembered from the checklist, so a
  /// project that added dark later — or removed it — refreshes as what it is.
  bool get hasDarkTheme => WidgetVariants.hasDarkThemeIn(resolve('lib'));

  /// `flutter_localizations` (the `.arb` approach) is installed.
  bool get hasLocalization => hasPackage('flutter_localizations');

  /// `easy_localization` (the JSON-assets approach) is installed.
  bool get hasEasyLocalization => hasPackage('easy_localization');

  /// The local notifications service was generated.
  bool get hasNotifications =>
      hasFile('lib/core/services/notifications_service.dart');

  /// The FCM push service was generated.
  bool get hasFirebaseNotifications =>
      hasFile('lib/core/services/firebase_notifications_service.dart');

  /// The biometric service was generated — `AppButton` varies with it.
  bool get hasBiometric => hasFile('lib/core/security/biometric_service.dart');

  /// The maintenance gate was generated. `main.dart` mounts it in
  /// `MaterialApp.builder`, so refreshing main without checking would quietly
  /// unmount the one widget whose whole job is to be unavoidable.
  bool get hasMaintenanceGate =>
      hasFile('lib/shared/widgets/maintenance_gate.dart');

  /// `FeatureFlagsService` was generated (10.3.0 on). It reads the Firestore
  /// document when the project has Firestore, the endpoint otherwise.
  bool get hasFeatureFlags => hasFile('lib/core/services/feature_flags.dart');

  /// The update gate was generated — mounted in `MaterialApp.builder` beside
  /// the maintenance gate, for the same reason that has to be checked.
  bool get hasUpdateGate => hasFile('lib/shared/widgets/update_gate.dart');

  /// `AppStatusColors` was generated, so `AppTheme` registers it and the
  /// status widgets read it — see [WidgetVariants.hasStatusColorsIn].
  bool get hasStatusColors => WidgetVariants.hasStatusColorsIn(resolve('lib'));

  /// `app_constants.dart` declares the color roles `AppTheme` reads since
  /// 9.9.0 (`onPrimary`, `onSurfaceMuted`…) — or does not exist yet, as
  /// during `init`. Without them a refreshed theme falls back to the tokens
  /// the old one used: see [CoreTemplates.colorRoleLiterals].
  bool get hasColorRoles {
    final file = File(resolve('lib/core/constants/app_constants.dart'));
    return !file.existsSync() ||
        CoreTemplates.declaresColorRoles(file.readAsStringSync());
  }

  /// MoAdapt was generated. `main.dart` mounts it above the whole app, so
  /// refreshing main without checking would silently drop the proportional
  /// scaling every screen was built against.
  bool get hasMoAdapt => hasFile('lib/shared/widgets/mo_adapt.dart');

  /// The offline-first cache was generated: the drift database and the
  /// `LocalCache` over it. The locator registers both, and `create feature`
  /// writes a feature's local datasource and repository against it.
  bool get hasLocalCache => hasFile('lib/core/database/local_cache.dart');

  /// The local database is encrypted (10.3.0 on): its key's file is there.
  bool get hasEncryptedDatabase =>
      hasFile('lib/core/database/database_key.dart');

  /// The REST auth feature has Sign in with Apple: `sign_in_with_apple` is a
  /// dependency. The Firebase one always has it, through FirebaseAuth.
  bool get hasRestAppleSignIn =>
      hasRestAuthFeature && hasPackage('sign_in_with_apple');

  /// Sign in with Apple, on either backend.
  bool get hasAppleSignIn => hasFirebaseAuthFeature || hasRestAppleSignIn;

  /// The REST `UserModel` declares `emailVerified` (10.2.0). It is the team's
  /// file, so the state only reads the field once it is there.
  bool get hasRestEmailVerification {
    final file = File(resolve('lib/features/auth/data/models/user_model.dart'));
    return file.existsSync() &&
        file.readAsStringSync().contains('emailVerified');
  }

  /// The forgot-password and verify-email screens exist and `AppRoutes`
  /// declares their paths (10.2.0) — what the router needs to route to them.
  bool get hasAuthAccountScreens {
    final routes = File(resolve('lib/config/router/app_routes.dart'));
    return hasFile(
          'lib/features/auth/presentation/views/verify_email_view.dart',
        ) &&
        hasFile(
          'lib/features/auth/presentation/views/forgot_password_view.dart',
        ) &&
        routes.existsSync() &&
        routes.readAsStringSync().contains('verifyEmail');
  }

  /// What `Runner.entitlements` already declares, read back so `update`
  /// never adds a capability the App ID was not given: codesigning fails on
  /// an entitlement the provisioning profile lacks.
  bool _entitlement(String key) {
    final file = File(resolve('ios/Runner/Runner.entitlements'));
    return file.existsSync() && file.readAsStringSync().contains(key);
  }

  /// `Runner.entitlements` declares push.
  bool get hasPushEntitlement => _entitlement('aps-environment');

  /// `Runner.entitlements` declares Sign in with Apple.
  bool get hasAppleSignInEntitlement =>
      _entitlement('com.apple.developer.applesignin');

  /// The image and file pickers were generated.
  bool get hasMediaService => hasFile('lib/core/services/media_service.dart');

  /// The external-link service was generated.
  bool get hasUrlService =>
      hasFile('lib/core/services/url_launcher_service.dart');

  /// The debouncer was generated.
  bool get hasDebouncer => hasFile('lib/core/services/debouncer_service.dart');

  /// What the README and the guides in `docs/` vary with, read off the
  /// project.
  DocsOptions get docsOptions => DocsOptions(
    projectName: projectName,
    stateManagement: stateManagement,
    flavors: flavorNames,
    withDio: hasDio,
    withRouter: hasRouter,
    withAuthFeature: hasAuthFeature,
    withFirebaseAuthFeature: hasFirebaseAuthFeature,
    withFirebase: hasAnyFirebase,
    withFirestore: hasFirestore,
    withCrashlytics: hasCrashlytics,
    withAnalytics: hasAnalytics,
    withFirebaseNotifications: hasFirebaseNotifications,
    withNotifications: hasNotifications,
    withLocalization: hasLocalization,
    withEasyLocalization: hasEasyLocalization,
    withBiometric: hasBiometric,
    withDarkTheme: hasDarkTheme,
    withThemeMode: hasThemeMode,
    withStatusColors: hasStatusColors,
    withMoAdapt: hasMoAdapt,
    withWorkflows: hasWorkflows,
    withLocalCache: hasLocalCache,
    withSync: hasSync,
    withOfflineGate: hasOfflineGate,
    withDeepLinks: hasDeepLinks,
    withMaintenanceGate: hasMaintenanceGate,
    withUpdateGate: hasUpdateGate,
    withMediaService: hasMediaService,
    withUrlService: hasUrlService,
    withDebouncer: hasDebouncer,
    withAppLifecycle: hasAppLifecycle,
    withPreferences: hasPreferences,
    withAppleSignIn: hasAppleSignIn,
  );

  /// The tables `moarch create table` wrote, one per feature that has one,
  /// sorted by path so `app_database.dart` lists them in a stable order.
  List<FeatureTableRef> get featureTables {
    final features = Directory(resolve('lib/features'));
    if (!features.existsSync()) return const [];
    final tables = <FeatureTableRef>[];
    final files =
        features
            .listSync()
            .whereType<Directory>()
            .expand((feature) {
              final dir = Directory(p.join(feature.path, 'data', 'tables'));
              return dir.existsSync()
                  ? dir.listSync().whereType<File>()
                  : const <File>[];
            })
            .where((file) => file.path.endsWith('_table.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final match = RegExp(
        r'^class\s+(\w+)\s+extends\s+Table\b',
        multiLine: true,
      ).firstMatch(file.readAsStringSync());
      if (match == null) continue;
      final relative = p
          .relative(file.path, from: resolve('lib/core/database'))
          .replaceAll(r'\', '/');
      tables.add((className: match.group(1)!, importPath: relative));
    }
    return tables;
  }

  /// The `schemaVersion` `app_database.dart` declares, or 1 when there is
  /// none to read.
  int get databaseSchemaVersion {
    final file = File(resolve('lib/core/database/app_database.dart'));
    if (!file.existsSync()) return 1;
    final match = RegExp(
      r'int\s+get\s+schemaVersion\s*=>\s*(\d+)\s*;',
    ).firstMatch(file.readAsStringSync());
    return match == null ? 1 : int.parse(match.group(1)!);
  }

  /// Offline sync was generated: the queue in the database, the service that
  /// sends it and the background task. Repositories queue their writes, and
  /// `main.dart` starts it.
  bool get hasSync => hasFile('lib/core/sync/sync_service.dart');

  /// The toast for refused writes and the pending-count banner (10.3.0 on,
  /// with sync). `main.dart` mounts the listener only when it is there.
  bool get hasSyncStatus => hasFile('lib/shared/widgets/sync_status.dart');

  /// The offline screen over the app, with the reconnect hook in main.dart.
  bool get hasOfflineGate => hasFile('lib/shared/widgets/offline_gate.dart');

  /// The saved light / dark / system switch (9.2.0 on, with the dark theme).
  bool get hasThemeMode => hasFile('lib/core/services/theme_mode_service.dart');

  /// `PreferencesService`, which the theme-mode switch saves through.
  bool get hasPreferences =>
      hasFile('lib/core/services/preferences_service.dart');

  /// `AppBlocObserver` was generated (bloc, 9.0.2 on). `main.dart` installs
  /// it, so refreshing main checks rather than importing a file an older
  /// project does not have.
  bool get hasBlocObserver => hasFile('lib/core/utils/app_bloc_observer.dart');

  /// Firestore is installed.
  bool get hasFirestore => hasPackage('cloud_firestore');

  /// Firebase Auth is installed.
  bool get hasFirebaseAuth => hasPackage('firebase_auth');

  /// The locator's registrations are split one file per layer, rather than
  /// all in `injector.dart`.
  ///
  /// Read off disk like every other option: projects scaffolded before the
  /// split still have the single file, and `update` has to refresh each as
  /// the shape it actually is.
  bool get hasSplitDi => hasFile('lib/config/di/data_module.dart');

  /// `feature_module.dart` was generated — 9.0.0 on. `injector.dart` calls it
  /// only when it is there.
  bool get hasFeatureModule => hasFile('lib/config/di/feature_module.dart');

  /// The lifecycle service was generated, so the core module registers it.
  bool get hasAppLifecycle =>
      hasFile('lib/core/services/app_lifecycle_service.dart');

  /// The auth feature was generated, in either variant — the router's redirect
  /// reads its notifier (riverpod) or its bloc.
  bool get hasAuthFeature =>
      hasFile('lib/features/auth/presentation/notifiers/auth_notifier.dart') ||
      hasFile('lib/features/auth/presentation/blocs/auth_bloc.dart');

  /// The auth feature was generated against Firebase Auth rather than the
  /// REST client.
  ///
  /// Read off the model, the one file whose name differs between the two
  /// variants — a project can have `firebase_auth` in its pubspec and still
  /// have taken the REST auth feature. A project scaffolded between 8.0.0 and
  /// 10.0.0 keeps the model under `domain/`, which is looked at too.
  bool get hasFirebaseAuthFeature =>
      hasFile('lib/features/auth/data/models/auth_user_model.dart') ||
      hasFile('lib/features/auth/domain/models/auth_user_model.dart');

  /// The auth feature was generated against the REST client — the variant
  /// that owns a refresh token, and so the only one whose `/auth/*` paths and
  /// refresh callback the Dio client has anything to do with.
  bool get hasRestAuthFeature => hasAuthFeature && !hasFirebaseAuthFeature;

  /// The constant names `lib/core/constants/api_constants.dart` declares —
  /// see [CoreTemplates.inlineMissingEndpoints] for why a template asks.
  Set<String> get apiEndpoints {
    final file = File(resolve('lib/core/constants/api_constants.dart'));
    return file.existsSync()
        ? CoreTemplates.declaredEndpoints(file.readAsStringSync())
        : const {};
  }

  /// The package name from `pubspec.yaml` — what the README calls the project.
  ///
  /// Falls back to `app` for a project with no pubspec, which is the same
  /// case every `hasPackage` above answers false for.
  String get projectName =>
      RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec)?.group(1) ??
      'app';

  /// The flavors declared in `flavorizr.yaml`, or empty when the project has
  /// not run `moarch create flavors`.
  ///
  /// Scanned rather than parsed as YAML on purpose: `flavorizr.yaml` is a file
  /// the developer edits, and a malformed one should leave the README without
  /// a flavor list, not make every template in the catalog throw.
  List<String> get flavorNames {
    final file = File(resolve('flavorizr.yaml'));
    if (!file.existsSync()) return const [];
    final names = <String>[];
    var inFlavors = false;
    for (final line in file.readAsStringSync().split('\n')) {
      if (RegExp(r'^flavors:\s*$').hasMatch(line)) {
        inFlavors = true;
        continue;
      }
      if (!inFlavors) continue;
      // Any other top-level key ends the block — `instructions:` follows it.
      if (RegExp(r'^\S').hasMatch(line)) break;
      final match = RegExp(r'^  ([a-z][a-z0-9]*):\s*$').firstMatch(line);
      if (match != null) names.add(match.group(1)!);
    }
    return names;
  }

  /// The GitHub Actions workflows were generated — what the README's CI/CD
  /// section describes, and skips when they are absent.
  bool get hasWorkflows => hasFile('.github/workflows/build_ipa.yml');

  /// The `applicationId` in `android/app/build.gradle(.kts)`, or null when
  /// there is no Android project or it declares none.
  String? get androidApplicationId {
    for (final path in [
      'android/app/build.gradle.kts',
      'android/app/build.gradle',
    ]) {
      if (!hasFile(path)) continue;
      final match = RegExp(
        r'''applicationId\s*=?\s*["']([^"']+)["']''',
      ).firstMatch(File(resolve(path)).readAsStringSync());
      if (match != null) return match.group(1)!;
    }
    return null;
  }

  /// The app's `PRODUCT_BUNDLE_IDENTIFIER` from the Xcode project, or null
  /// when there is no iOS project — usually the Android id, but not
  /// guaranteed to be.
  String? get iosBundleId {
    const path = 'ios/Runner.xcodeproj/project.pbxproj';
    if (!hasFile(path)) return null;
    final match = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\s]+);',
      multiLine: true,
    ).firstMatch(File(resolve(path)).readAsStringSync());
    // The RunnerTests target's id ends in .RunnerTests — strip that rather
    // than hand back the test bundle when it happens to match first.
    final id = match?.group(1)?.replaceAll('"', '');
    if (id == null) return null;
    return id.endsWith('.RunnerTests')
        ? id.substring(0, id.length - '.RunnerTests'.length)
        : id;
  }

  /// The deep-link setup was generated (9.2.0 on).
  bool get hasDeepLinks => hasFile('docs/DEEP_LINKS.md');

  /// The agent skills were generated (9.1.0 on) — what `AGENTS.md`'s skills
  /// section lists, and leaves out on a project that does not have them yet.
  bool get hasAgentSkills => hasFile(SkillsTemplates.all.first.agentsPath);

  /// `.mcp.json` starts the Dart MCP server (9.10.0 on) — what lets the
  /// agent guide tell an agent to run the app itself. Read for the server
  /// rather than the file, since a team may keep other servers there.
  bool get hasDartMcp {
    if (!hasFile('.mcp.json')) return false;
    return File(resolve('.mcp.json')).readAsStringSync().contains('mcp-server');
  }
}

/// One generated file outside the widget kit that `moarch update` can refresh.
class ScaffoldSpec {
  /// Creates a catalog entry.
  const ScaffoldSpec({
    required this.name,
    required this.title,
    required this.path,
    required this.template,
    required this.category,
    required this.description,
    this.blocPath,
    this.movedFrom,
  });

  /// CLI slug, e.g. `validation` → `moarch update validation`.
  final String name;

  /// Human-facing name of what the file holds, e.g. `ValidationService`.
  final String title;

  /// Project-relative path with forward slashes, e.g.
  /// `lib/core/security/validation_service.dart`.
  ///
  /// Where the file lives in a Riverpod project when [blocPath] is set.
  final String path;

  /// Where the file lives in a bloc project, when that is not [path].
  ///
  /// The state is the one file the two stacks disagree about: bloc keeps it in
  /// `presentation/blocs/` with the events and the bloc, Riverpod in
  /// `presentation/states/`. Everything else is either at the same path in
  /// both or has a spec of its own.
  final String? blocPath;

  /// Where moarch used to write this file, project-relative with forward
  /// slashes, for an entry that has since moved.
  ///
  /// `update` reads it to recognise a project still holding the file at the old
  /// path, so the refresh relocates it instead of writing a second copy and
  /// leaving the first behind.
  final String? movedFrom;

  /// This file's path in [context]'s project.
  String pathIn(ScaffoldContext context) =>
      context.hasBloc ? (blocPath ?? path) : path;

  /// Produces the file's current source for a given project.
  final String Function(ScaffoldContext context) template;

  /// Grouping, and the group slug's label — see [ScaffoldCatalog.groups].
  final String category;

  /// One-line summary used by `moarch update --list`.
  final String description;
}

/// Everything `moarch init` generates outside `lib/shared/widgets/`.
///
/// The widget kit has its own catalog because widgets are also *created* on
/// demand; these files are only ever written by `init`, so all they need is
/// enough to find them again and reproduce what the current templates would
/// write. `moarch update` refreshes any of them that is present — it never
/// adds a file the project chose not to generate.
abstract final class ScaffoldCatalog {
  /// Category order used by `moarch update --list`.
  static const List<String> categories = [
    'Core',
    'Network',
    'Security',
    'Services',
    'Config',
    'Auth feature',
    'Docs',
    'AI agents',
    'Workflows',
    'Project',
    'iOS',
    'Android',
  ];

  /// Group slug → category, for `moarch update core`, `moarch update docs`…
  ///
  /// `widgets` is handled by the update command itself, since those come from
  /// [WidgetCatalog] rather than from here.
  static const Map<String, String> groups = {
    'core': 'Core',
    'network': 'Network',
    'security': 'Security',
    'services': 'Services',
    'config': 'Config',
    'auth': 'Auth feature',
    'docs': 'Docs',
    'ai': 'AI agents',
    'workflows': 'Workflows',
    'project': 'Project',
    'ios': 'iOS',
    'android': 'Android',
  };

  /// Every non-widget file the CLI generates.
  static final List<ScaffoldSpec> all = [
    // ── Core ────────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'exception',
      title: 'AppException',
      path: 'lib/core/errors/app_exception.dart',
      category: 'Core',
      template: (c) => ErrorTemplates.appException(
        hasDio: c.hasDio,
        hasFirebase: c.hasFirebase,
        hasFirebaseAuth: c.hasFirebaseAuth,
        hasCrashlytics: c.hasCrashlytics,
      ),
      description:
          'One exception type every layer throws, mapped from Dio, Firebase and platform errors.',
    ),
    ScaffoldSpec(
      name: 'app-database',
      title: 'AppDatabase',
      path: 'lib/core/database/app_database.dart',
      category: 'Core',
      template: (c) => CacheTemplates.appDatabase(
        withSync: c.hasSync,
        featureTables: c.featureTables,
        schemaVersion: c.databaseSchemaVersion,
        encrypted: c.hasEncryptedDatabase,
      ),
      description:
          'The drift database behind the offline-first cache: records as '
          "JSON keyed by feature, plus each feature's own table.",
    ),
    ScaffoldSpec(
      name: 'database-key',
      title: 'DatabaseKey',
      path: 'lib/core/database/database_key.dart',
      category: 'Core',
      template: (_) => CacheTemplates.databaseKey(),
      description:
          'The encrypted database\'s key: made on first open, kept in the '
          'platform keystore.',
    ),
    ScaffoldSpec(
      name: 'local-cache',
      title: 'LocalCache',
      path: 'lib/core/database/local_cache.dart',
      category: 'Core',
      template: (c) => CacheTemplates.localCache(withSync: c.hasSync),
      description:
          "Read, watch and replace a feature's cached records — what every "
          "local datasource calls.",
    ),
    ScaffoldSpec(
      name: 'sync-queue',
      title: 'SyncQueue',
      path: 'lib/core/sync/sync_queue.dart',
      category: 'Core',
      template: (_) => SyncTemplates.syncQueue(),
      description:
          'Writes waiting for the server, oldest first, and the SyncRequest '
          'a datasource describes them with.',
    ),
    ScaffoldSpec(
      name: 'sync-service',
      title: 'SyncService',
      path: 'lib/core/sync/sync_service.dart',
      category: 'Core',
      template: (c) =>
          SyncTemplates.syncService(stateManagement: c.stateManagement),
      description:
          'Sends the queue on start, reconnect and resume; retries, drops '
          'refusals, refetches what it touched.',
    ),
    ScaffoldSpec(
      name: 'background-sync',
      title: 'Background sync',
      path: 'lib/core/sync/background_sync.dart',
      category: 'Core',
      template: (c) =>
          SyncTemplates.backgroundSync(withRestAuth: c.hasRestAuthFeature),
      description:
          'The workmanager task that sends the queue every ~15 minutes while '
          'the app is closed.',
    ),
    ScaffoldSpec(
      name: 'sync-status',
      title: 'SyncStatusListener / SyncStatusBanner',
      path: 'lib/shared/widgets/sync_status.dart',
      category: 'Core',
      template: (c) => c.stack.syncStatus(),
      description:
          'A toast for every write the server refused, mounted around the '
          'app, and a banner with the count of changes not yet sent.',
    ),
    ScaffoldSpec(
      name: 'extensions',
      title: 'Extensions',
      path: 'lib/core/utils/extensions.dart',
      category: 'Core',
      template: (_) => CoreTemplates.extensions(),
      description:
          'The extension set the generated code leans on — context, string, date, num, list.',
    ),
    ScaffoldSpec(
      name: 'logger',
      title: 'AppLogger',
      path: 'lib/core/utils/app_logger.dart',
      category: 'Core',
      template: (c) =>
          CoreTemplates.appLogger(withCrashlytics: c.hasCrashlytics),
      description:
          'The app-wide logger, forwarding to Crashlytics when it is installed.',
    ),
    // Riverpod only, and `generated` filters on the file being there, so a
    // bloc project never reports it: its sealed states carry what this
    // declares centrally.
    ScaffoldSpec(
      name: 'action-notifier',
      title: 'ActionNotifier',
      path: 'lib/core/utils/action_notifier.dart',
      category: 'Core',
      template: (c) => c.stack.actionBase(),
      description:
          'The notifier base that turns a one-shot action into error/success fields (Riverpod).',
    ),
    // Bloc only, for the same reason and by the same filter: a Riverpod
    // project never has the file, so it is never reported for one.
    ScaffoldSpec(
      name: 'app-status',
      title: 'AppStatus',
      path: 'lib/core/utils/app_status.dart',
      category: 'Core',
      template: (c) => c.stack.actionBase(),
      description:
          'The status enum every feature state carries, and the runAction mixin every bloc uses (bloc).',
    ),
    // Bloc only, by the same filter.
    ScaffoldSpec(
      name: 'bloc-observer',
      title: 'AppBlocObserver',
      path: 'lib/core/utils/app_bloc_observer.dart',
      category: 'Core',
      template: (c) => c.stack.appBlocObserver(),
      description:
          'Logs every error a bloc reports, so runAction\'s unexpected failures are not lost (bloc).',
    ),
    ScaffoldSpec(
      name: 'constants',
      title: 'AppConstants',
      path: 'lib/core/constants/app_constants.dart',
      category: 'Core',
      template: (c) => CoreTemplates.appConstants(withDark: c.hasDarkTheme),
      description:
          'Colors, spacing, radii and typography — the values the whole UI kit reads.',
    ),
    ScaffoldSpec(
      name: 'api-constants',
      title: 'ApiConstants',
      path: 'lib/core/constants/api_constants.dart',
      category: 'Core',
      template: (c) => CoreTemplates.apiConstants(
        withAuthFeature: c.hasRestAuthFeature,
        withAppleSignIn: c.hasRestAppleSignIn,
        withDeviceToken: c.hasRestAuthFeature && c.hasFirebaseNotifications,
        withMaintenanceGate:
            c.hasMaintenanceGate && c.hasDio && !c.hasFirestore,
        withUpdateGate: c.hasUpdateGate && c.hasDio && !c.hasFirestore,
        withFeatureFlags: c.hasFeatureFlags && !c.hasFirestore,
      ),
      description: 'Every endpoint path, and the API timeouts.',
    ),
    ScaffoldSpec(
      name: 'main',
      title: 'main.dart',
      path: 'lib/main.dart',
      category: 'Core',
      template: (c) => c.stack.mainDart(
        withRouter: c.hasRouter,
        withLocalization: c.hasLocalization,
        withEasyLocalization: c.hasEasyLocalization,
        withNotificationsService: c.hasNotifications,
        withFirebaseNotifications: c.hasFirebaseNotifications,
        withCrashlytics: c.hasCrashlytics,
        withFirebase: c.hasFirebase || c.hasCrashlytics || c.hasAnalytics,
        withMaintenanceGate: c.hasMaintenanceGate,
        withUpdateGate: c.hasUpdateGate,
        withMoAdapt: c.hasMoAdapt,
        withDarkTheme: c.hasDarkTheme,
        withThemeMode: c.hasThemeMode,
        withOfflineGate: c.hasOfflineGate,
        withAuthFeature: c.hasAuthFeature,
        withBlocObserver: c.hasBlocObserver,
        withSync: c.hasSync,
        withSyncStatus: c.hasSyncStatus,
      ),
      description:
          'The entry point: the root scope, theme, router and the services the project selected.',
    ),

    // ── Network ─────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'dio-client',
      title: 'DioClient',
      path: 'lib/core/network/dio_client.dart',
      category: 'Network',
      template: (c) => CoreTemplates.inlineMissingEndpoints(
        c.stack.dioClient(
          withAuthFeature: c.hasRestAuthFeature,
          withAppleSignIn: c.hasRestAppleSignIn,
        ),
        c.apiEndpoints,
      ),
      description:
          'REST client with retry and the secure-storage auth/refresh interceptor.',
    ),
    ScaffoldSpec(
      name: 'safe-api-call',
      title: 'safeApiCall',
      path: 'lib/core/network/safe_api_call.dart',
      category: 'Network',
      template: (_) => CoreTemplates.safeApiCall(),
      description:
          'The wrapper that turns a request into a typed AppException.',
    ),
    ScaffoldSpec(
      name: 'paginated',
      title: 'Paginated',
      path: 'lib/core/network/paginated.dart',
      category: 'Network',
      template: (_) => CoreTemplates.paginated(),
      description:
          'A page of items and the key of the next one — page number, offset or cursor.',
    ),
    ScaffoldSpec(
      name: 'paging',
      title: 'PagedList',
      path: 'lib/core/utils/paged_list.dart',
      category: 'Network',
      template: (c) => c.stack.pagedList(),
      description:
          'The paged-list state value and the mixin that loads its next page (notifier or bloc).',
    ),
    ScaffoldSpec(
      name: 'safe-firebase-call',
      title: 'safeFirebaseCall',
      path: 'lib/core/network/safe_firebase_call.dart',
      category: 'Network',
      template: (c) =>
          CoreTemplates.safeFirebaseCall(withAuth: c.hasFirebaseAuth),
      description:
          'The same contract for Firestore and Firebase Auth calls and streams.',
    ),
    ScaffoldSpec(
      name: 'timestamp-converter',
      title: 'TimestampConverter',
      path: 'lib/core/network/timestamp_converter.dart',
      category: 'Network',
      template: (_) => CoreTemplates.timestampConverter(),
      description:
          'Keeps a model DateTime stored as a Firestore Timestamp, not a string.',
    ),

    // ── Security ────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'secure-storage',
      title: 'SecureStorage',
      path: 'lib/core/security/secure_storage.dart',
      category: 'Security',
      template: (c) => SecurityTemplates.secureStorage(),
      description: 'Keychain/Keystore wrapper holding tokens and the user id.',
    ),
    ScaffoldSpec(
      name: 'validation',
      title: 'ValidationService',
      path: 'lib/core/security/validation_service.dart',
      category: 'Security',
      template: (_) => SecurityTemplates.validationService(),
      description:
          'Checks a value against an InputType and hands back the cleaned form — what AppInput calls.',
    ),
    ScaffoldSpec(
      name: 'biometric',
      title: 'BiometricService',
      path: 'lib/core/security/biometric_service.dart',
      category: 'Security',
      template: (c) => SecurityTemplates.biometricService(),
      description: 'Face ID / fingerprint via local_auth, behind one call.',
    ),

    // ── Services ────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'media-service',
      title: 'MediaService',
      path: 'lib/core/services/media_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.mediaService(),
      description:
          'Image and file pickers with the permission handling around them.',
    ),
    ScaffoldSpec(
      name: 'url-service',
      title: 'UrlLauncherService',
      path: 'lib/core/services/url_launcher_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.launchUrlService(),
      description: 'Opens external links, with the in-app web view fallback.',
    ),
    ScaffoldSpec(
      name: 'notifications-service',
      title: 'NotificationsService',
      path: 'lib/core/services/notifications_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.notificationsService(),
      description: 'Local notifications: permissions, channels and scheduling.',
    ),
    ScaffoldSpec(
      name: 'firebase-notifications',
      title: 'FirebaseNotificationsService',
      path: 'lib/core/services/firebase_notifications_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.firebaseNotificationsService(
        withLocalNotifications: c.hasNotifications,
      ),
      description:
          'FCM tokens, foreground/background handlers and topic subscriptions.',
    ),
    ScaffoldSpec(
      name: 'debouncer',
      title: 'DebouncerService',
      path: 'lib/core/services/debouncer_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.debouncerService(),
      description: 'Debounces rapid actions, e.g. a search field.',
    ),
    ScaffoldSpec(
      name: 'app-lifecycle',
      title: 'AppLifecycleService',
      path: 'lib/core/services/app_lifecycle_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.appLifecycleService(),
      description:
          'Foreground/background as streams — `resumed` says how '
          'long the app was away, for revalidating on return.',
    ),
    ScaffoldSpec(
      name: 'permission-service',
      title: 'PermissionService',
      path: 'lib/core/services/permission_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.permissionService(),
      description:
          'Reads and requests a permission as granted, denied or blocked — '
          'blocked being the one only the system settings can grant.',
    ),
    ScaffoldSpec(
      name: 'connectivity',
      title: 'ConnectivityService',
      path: 'lib/core/services/connectivity_service.dart',
      category: 'Services',
      template: (c) => ServicesTemplates.connectivityService(
        stateManagement: c.stateManagement,
        withApiProbe: c.hasDio,
      ),
      description:
          'Online / offline as a stream (with Dio, checked against the API), '
          'and onReconnect for what runs when the connection is back.',
    ),
    ScaffoldSpec(
      name: 'analytics-service',
      title: 'AnalyticsService',
      path: 'lib/core/services/analytics_service.dart',
      category: 'Services',
      template: (_) => AnalyticsTemplates.analyticsService(),
      description:
          'Events, the signed-in user and screen views through one '
          'interface, on Firebase Analytics.',
    ),
    ScaffoldSpec(
      name: 'feature-flags',
      title: 'FeatureFlags',
      path: 'lib/core/services/feature_flags.dart',
      category: 'Services',
      template: (c) => CoreTemplates.inlineMissingEndpoints(
        FeatureFlagsTemplates.featureFlags(
          stateManagement: c.stateManagement,
          withFirestore: c.hasFirestore,
        ),
        c.apiEndpoints,
      ),
      description:
          'Typed backend switches with their defaults, read from where the '
          'gates read theirs.',
    ),
    ScaffoldSpec(
      name: 'offline-gate',
      title: 'OfflineGate',
      path: 'lib/shared/widgets/offline_gate.dart',
      category: 'Services',
      template: (c) => c.stack.offlineGate(),
      description:
          'Covers the app with an offline screen while there is no '
          'connection, keeping it mounted underneath.',
    ),
    ScaffoldSpec(
      name: 'preferences',
      title: 'PreferencesService',
      path: 'lib/core/services/preferences_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.preferencesService(),
      description:
          'Small non-secret settings (shared_preferences), loaded before '
          'runApp so they read synchronously.',
    ),
    ScaffoldSpec(
      name: 'theme-mode',
      title: 'ThemeModeService',
      path: 'lib/core/services/theme_mode_service.dart',
      category: 'Services',
      template: (c) => c.stack.themeModeService(),
      description:
          'The saved light / dark / system choice — a Notifier on '
          'Riverpod, a Cubit on bloc (dark theme).',
    ),
    ScaffoldSpec(
      name: 'language-service',
      title: 'LanguageService',
      path: 'lib/core/services/language_service.dart',
      category: 'Services',
      template: (c) => c.stack.languageService(),
      description:
          'Holds the selected locale — a Notifier on Riverpod, a '
          'Cubit on bloc (flutter_localizations).',
    ),

    // ── Config ──────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'env',
      title: 'AppEnv',
      path: 'lib/config/env/app_env.dart',
      category: 'Config',
      template: (_) => ConfigTemplates.appEnv(),
      description: 'The envied-backed view of .env (needs build_runner).',
    ),
    ScaffoldSpec(
      name: 'theme',
      title: 'AppTheme',
      path: 'lib/config/theme/app_theme.dart',
      category: 'Config',
      template: (c) {
        final theme = ConfigTemplates.appTheme(
          withDark: c.hasDarkTheme,
          withStatusColors: c.hasStatusColors,
        );
        return c.hasColorRoles
            ? theme
            : CoreTemplates.inlineMissingColorRoles(theme);
      },
      description:
          'The ThemeData built from AppConstants — light, plus dark '
          'when the project took it.',
    ),
    ScaffoldSpec(
      name: 'status-colors',
      title: 'AppStatusColors',
      path: 'lib/config/theme/app_status_colors.dart',
      category: 'Config',
      template: (c) =>
          ConfigTemplates.appStatusColors(withDark: c.hasDarkTheme),
      description:
          'Success / warning / info as a ThemeExtension, so they '
          'follow the theme — read with context.statusColors.',
    ),
    ScaffoldSpec(
      name: 'router',
      title: 'AppRouter',
      path: 'lib/config/router/app_router.dart',
      category: 'Config',
      template: (c) => c.stack.appRouter(
        withAuth: c.hasAuthFeature,
        withAccountScreens: c.hasAuthAccountScreens,
        withAnalytics: c.hasAnalytics,
      ),
      description:
          'GoRouter with the auth-aware redirect and rootNavigatorKey.',
    ),
    ScaffoldSpec(
      name: 'routes',
      title: 'AppRoutes',
      path: 'lib/config/router/app_routes.dart',
      category: 'Config',
      template: (_) => ConfigTemplates.appRoutes(),
      description: 'The route name/path constants the router and views share.',
    ),
    ScaffoldSpec(
      name: 'firebase-providers',
      title: 'Firebase providers',
      path: 'lib/config/firebase/firebase_providers.dart',
      category: 'Config',
      template: (c) => c.stack.firebaseProviders(
        hasAuth: c.hasFirebaseAuth,
        hasDb: c.hasFirestore,
      ),
      description:
          'Signpost to where FirebaseAuth and Firestore are registered.',
    ),
    // ── The locator ─────────────────────────────────────────────────────────
    // Five files rather than one: `injector.dart` holds `getIt` and calls one
    // registrar per layer, and the registrations themselves live beside the
    // layer they belong to, so no single file grows with the app. A project
    // scaffolded before that split still has everything in `injector.dart`,
    // which is why the spec below asks the project which shape it is.
    ScaffoldSpec(
      name: 'injector',
      title: 'Injector',
      path: 'lib/config/di/injector.dart',
      category: 'Config',
      template: (c) => c.hasSplitDi
          ? c.stack.injector(withFeatureModule: c.hasFeatureModule)
          : c.stack.singleFileInjector(
              withDio: c.hasDio,
              withFirestore: c.hasFirestore,
              withFirebaseAuth: c.hasFirebaseAuth,
              withAuthFeature: c.hasAuthFeature,
              withFirebaseAuthFeature: c.hasFirebaseAuthFeature,
              withMedia: c.hasFile('lib/core/services/media_service.dart'),
              withUrlLauncher: c.hasFile(
                'lib/core/services/url_launcher_service.dart',
              ),
              withNotifications: c.hasNotifications,
              withFirebaseNotifications: c.hasFirebaseNotifications,
              withDebouncer: c.hasFile(
                'lib/core/services/debouncer_service.dart',
              ),
              withBiometric: c.hasBiometric,
              withLocalization: c.hasLocalization,
              withConnectivity: c.hasFile(
                'lib/core/services/connectivity_service.dart',
              ),
            ),
      description:
          'The get_it service locator: getIt, and setupInjector() calling one registrar per layer.',
    ),
    ScaffoldSpec(
      name: 'di-external',
      title: 'External module',
      path: 'lib/config/di/external_module.dart',
      category: 'Config',
      template: (c) => c.stack.externalModule(
        withDio: c.hasDio,
        withFirestore: c.hasFirestore,
        withFirebaseAuth: c.hasFirebaseAuth,
        withAuthFeature: c.hasAuthFeature,
        withFirebaseAuthFeature: c.hasFirebaseAuthFeature,
        withLocalCache: c.hasLocalCache,
      ),
      description:
          'External layer of the locator: Dio, the Firebase handles, secure storage.',
    ),
    ScaffoldSpec(
      name: 'di-core',
      title: 'Core module',
      path: 'lib/config/di/core_module.dart',
      category: 'Config',
      template: (c) => c.stack.coreModule(
        withMedia: c.hasFile('lib/core/services/media_service.dart'),
        withUrlLauncher: c.hasFile(
          'lib/core/services/url_launcher_service.dart',
        ),
        withNotifications: c.hasNotifications,
        withFirebaseNotifications: c.hasFirebaseNotifications,
        withDebouncer: c.hasFile('lib/core/services/debouncer_service.dart'),
        withBiometric: c.hasBiometric,
        withConnectivity: c.hasFile(
          'lib/core/services/connectivity_service.dart',
        ),
        withAppLifecycle: c.hasAppLifecycle,
        withPreferences: c.hasPreferences,
        withLocalCache: c.hasLocalCache,
        withSync: c.hasSync,
        withAnalytics: c.hasAnalytics,
        withFeatureFlags: c.hasFeatureFlags,
        flagsFromFirestore: c.hasFirestore,
      ),
      description: 'Core layer of the locator: the services under lib/core.',
    ),
    ScaffoldSpec(
      name: 'di-feature',
      title: 'Feature module',
      path: 'lib/config/di/feature_module.dart',
      category: 'Config',
      template: (c) => c.stack.featureModule(),
      description:
          'Feature layer of the locator: long-lived services a '
          'feature owns (sockets, engines), and scopes for one flow.',
    ),
    ScaffoldSpec(
      name: 'di-data',
      title: 'Data module',
      path: 'lib/config/di/data_module.dart',
      category: 'Config',
      template: (c) => c.stack.dataModule(
        withDio: c.hasDio,
        withFirestore: c.hasFirestore,
        withAuthFeature: c.hasAuthFeature,
        withFirebaseAuthFeature: c.hasFirebaseAuthFeature,
        withFirebaseNotifications: c.hasFirebaseNotifications,
        withLocalCache: c.hasLocalCache,
      ),
      description:
          'Data layer of the locator: datasources and repositories. `create feature` writes here.',
    ),
    ScaffoldSpec(
      name: 'di-presentation',
      title: 'Presentation module',
      path: 'lib/config/di/presentation_module.dart',
      category: 'Config',
      template: (c) => c.stack.presentationModule(
        withAuthFeature: c.hasAuthFeature,
        withLocalization: c.hasLocalization,
      ),
      description:
          'Presentation layer of the locator: the blocs. Bloc projects only.',
    ),

    // ── Auth feature ────────────────────────────────────────────────────────
    // The files below are shared by both backends: same path, same class
    // names, a template chosen by which model the project has. The
    // state holder is the one that differs by *stack* as well as by backend —
    // hence the separate notifier / bloc / event entries at the end.
    ScaffoldSpec(
      name: 'auth-model',
      title: 'AuthTokensModel',
      path: 'lib/features/auth/data/models/auth_tokens_model.dart',
      movedFrom: 'lib/features/auth/domain/models/auth_tokens_model.dart',
      category: 'Auth feature',
      template: (c) => c.stack.authModel(),
      description: 'The access/refresh token pair, as the API sends it.',
    ),
    ScaffoldSpec(
      name: 'auth-me-model',
      title: 'UserModel',
      path: 'lib/features/auth/data/models/user_model.dart',
      movedFrom: 'lib/features/auth/domain/models/user_model.dart',
      category: 'Auth feature',
      template: (c) => c.stack.authUserModel(),
      description: 'The signed-in user, as GET /auth/me returns it (REST).',
    ),
    ScaffoldSpec(
      name: 'auth-user-model',
      title: 'AuthUserModel',
      path: 'lib/features/auth/data/models/auth_user_model.dart',
      movedFrom: 'lib/features/auth/domain/models/auth_user_model.dart',
      category: 'Auth feature',
      template: (c) => c.stack.firebaseAuthModel(withFirestore: c.hasFirestore),
      description:
          'The signed-in Firebase user, plus the Firestore profile document.',
    ),
    ScaffoldSpec(
      name: 'auth-datasource',
      title: 'AuthRemoteDatasource',
      path: 'lib/features/auth/data/datasources/auth_remote_datasource.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthRemoteDatasource(
              withFirestore: c.hasFirestore,
              withPushNotifications: c.hasFirebaseNotifications,
            )
          : CoreTemplates.inlineMissingEndpoints(
              c.stack.authRemoteDatasource(
                withPushNotifications: c.hasFirebaseNotifications,
                withAppleSignIn: c.hasRestAppleSignIn,
              ),
              c.apiEndpoints,
            ),
      description:
          'The auth calls — /auth/* over Dio, or FirebaseAuth and Google sign-in.',
    ),
    ScaffoldSpec(
      name: 'auth-repository',
      title: 'AuthRepository',
      path: 'lib/features/auth/data/repositories/auth_repository.dart',
      // Before 10.0.0 this was the implementation of an interface in
      // `domain/repositories/`, which a refresh leaves behind.
      movedFrom:
          'lib/features/auth/data/repositories/auth_repository_impl.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthRepository(
              withFirestore: c.hasFirestore,
              withPushNotifications: c.hasFirebaseNotifications,
              withLocalCache: c.hasLocalCache,
            )
          : c.stack.authRepository(
              withPushNotifications: c.hasFirebaseNotifications,
              withLocalCache: c.hasLocalCache,
              withAppleSignIn: c.hasRestAppleSignIn,
            ),
      description:
          'What the state holder calls: the datasource and the session storage.',
    ),
    ScaffoldSpec(
      name: 'auth-state',
      title: 'AuthState',
      path: 'lib/features/auth/presentation/states/auth_state.dart',
      blocPath: 'lib/features/auth/presentation/blocs/auth_state.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthState()
          : c.stack.authState(
              withEmailVerification: c.hasRestEmailVerification,
            ),
      description: 'The state the auth notifier or bloc exposes.',
    ),
    ScaffoldSpec(
      name: 'auth-notifier',
      title: 'AuthNotifier',
      path: 'lib/features/auth/presentation/notifiers/auth_notifier.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthHolder(
              withPushNotifications: c.hasFirebaseNotifications,
              withConcurrency: c.hasBlocConcurrency,
            )
          : c.stack.authHolder(
              withPushNotifications: c.hasFirebaseNotifications,
              withConcurrency: c.hasBlocConcurrency,
              withAppleSignIn: c.hasRestAppleSignIn,
            ),
      description:
          'Login, register, refresh, logout, delete and session '
          'restore (Riverpod).',
    ),
    ScaffoldSpec(
      name: 'auth-bloc',
      title: 'AuthBloc',
      path: 'lib/features/auth/presentation/blocs/auth_bloc.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthHolder(
              withPushNotifications: c.hasFirebaseNotifications,
              withConcurrency: c.hasBlocConcurrency,
            )
          : c.stack.authHolder(
              withPushNotifications: c.hasFirebaseNotifications,
              withConcurrency: c.hasBlocConcurrency,
              withAppleSignIn: c.hasRestAppleSignIn,
            ),
      description:
          'Login, register, refresh, logout, delete and session '
          'restore (flutter_bloc).',
    ),
    ScaffoldSpec(
      name: 'auth-event',
      title: 'AuthEvent',
      path: 'lib/features/auth/presentation/blocs/auth_event.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthEvent()
          : c.stack.authEvent(withAppleSignIn: c.hasRestAppleSignIn),
      description: 'The sealed event family AuthBloc handles (flutter_bloc).',
    ),
    ScaffoldSpec(
      name: 'auth-login-view',
      title: 'LoginView',
      path: 'lib/features/auth/presentation/views/login_view.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthLoginView()
          : c.stack.authLoginView(),
      description: 'The login screen built from the UI kit.',
    ),
    ScaffoldSpec(
      name: 'auth-register-view',
      title: 'RegisterView',
      path: 'lib/features/auth/presentation/views/register_view.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthRegisterView()
          : c.stack.authRegisterView(),
      description: 'The register screen built from the UI kit.',
    ),
    ScaffoldSpec(
      name: 'auth-forgot-password-view',
      title: 'ForgotPasswordView',
      path: 'lib/features/auth/presentation/views/forgot_password_view.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthForgotPasswordView()
          : c.stack.authForgotPasswordView(),
      description:
          'Password reset: a Firebase reset link, or a REST code and a new '
          'password.',
    ),
    ScaffoldSpec(
      name: 'auth-verify-email-view',
      title: 'VerifyEmailView',
      path: 'lib/features/auth/presentation/views/verify_email_view.dart',
      category: 'Auth feature',
      template: (c) => c.hasFirebaseAuthFeature
          ? c.stack.firebaseAuthVerifyEmailView()
          : c.stack.authVerifyEmailView(),
      description:
          'Where the router holds a signed-in user until their email is '
          'verified.',
    ),

    // ── Docs ────────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'readme',
      title: 'Project README',
      path: 'README.md',
      category: 'Docs',
      template: (c) => ReadmeTemplates.projectReadme(c.docsOptions),
      description:
          'The front page: how to run the project, what it is built with, '
          'where things are, and a link to every guide in docs/.',
    ),
    // The topic guides, one per thing the project has. Listed from the same
    // table the README's guides section reads, so the two cannot disagree.
    for (final doc in ProjectDocsTemplates.written)
      ScaffoldSpec(
        name: doc.slug,
        title: '${doc.title} guide',
        path: doc.path,
        category: 'Docs',
        template: (c) => doc.render!(c.docsOptions),
        description: '${doc.answers}.',
      ),
    ScaffoldSpec(
      name: 'agents',
      title: 'AGENTS.md',
      path: 'AGENTS.md',
      category: 'Docs',
      template: (c) => AgentsTemplates.agentsMd(
        projectName: c.projectName,
        stateManagement: c.stateManagement,
        withDio: c.hasDio,
        withFirebase: c.hasFirebase,
        withRouter: c.hasRouter,
        withAuthFeature: c.hasAuthFeature,
        withDarkTheme: c.hasDarkTheme,
        withThemeMode: c.hasThemeMode,
        withDeepLinks: c.hasDeepLinks,
        withOfflineGate: c.hasOfflineGate,
        withLocalCache: c.hasLocalCache,
        withSync: c.hasSync,
        withStatusColors: c.hasStatusColors,
        withLocalization: c.hasLocalization,
        withEasyLocalization: c.hasEasyLocalization,
        withFeatureModule: c.hasFeatureModule,
        withSkills: c.hasAgentSkills,
        withDartMcp: c.hasDartMcp,
        withEncryptedDatabase: c.hasEncryptedDatabase,
        withAnalytics: c.hasAnalytics,
        withFeatureFlags: c.hasFeatureFlags,
      ),
      description:
          'The rules coding agents (Codex, Cursor, Copilot, Claude) '
          'read before touching the project.',
    ),
    ScaffoldSpec(
      name: 'claude-md',
      title: 'CLAUDE.md',
      path: 'CLAUDE.md',
      category: 'Docs',
      template: (_) => AgentsTemplates.claudeMd(),
      description:
          "Claude Code's import of AGENTS.md, so there is one set of "
          'instructions.',
    ),
    ScaffoldSpec(
      name: 'ui-kit',
      title: 'UI kit catalog',
      path: 'docs/UI_KIT.md',
      category: 'Docs',
      template: (_) => WidgetCatalog.markdown(),
      description:
          'The generated catalog of the widget kit — goes stale as the kit grows.',
    ),
    ScaffoldSpec(
      name: 'deploy-checklist',
      title: 'Deployment checklist',
      path: 'docs/CHECKLIST_BEFORE_DEPLOYMENT.md',
      category: 'Docs',
      template: (_) => DocsTemplates.prodChecklist(),
      description: 'What to check before shipping a build.',
    ),
    ScaffoldSpec(
      name: 'security-checklist',
      title: 'Security checklist',
      path: 'docs/SECURITY_BEFORE_DEPLOYMENT.md',
      category: 'Docs',
      template: (_) => DocsTemplates.securityChecklist(),
      description: 'The security review to run before a release.',
    ),
    ScaffoldSpec(
      name: 'jks-doc',
      title: 'Keystore guide',
      path: 'docs/GENERATE_JKS_FILE.md',
      category: 'Docs',
      template: (_) => DocsTemplates.generateJKS(),
      description: 'How to generate and wire up the Android signing key.',
    ),
    ScaffoldSpec(
      name: 'offline-doc',
      title: 'Offline-first guide',
      path: 'docs/OFFLINE_FIRST.md',
      category: 'Docs',
      template: (c) => OfflineDocsTemplates.doc(
        withSync: c.hasSync,
        bloc: c.hasBloc,
        withAuthFeature: c.hasAuthFeature,
        withApiProbe: c.hasDio,
        withEncryption: c.hasEncryptedDatabase,
      ),
      description:
          'How the cache (and the sync queue) work at runtime: the tables, '
          'the read and write paths, a full timeline.',
    ),
    ScaffoldSpec(
      name: 'sync-setup',
      title: 'Offline sync guide',
      path: 'docs/SYNC_SETUP.md',
      category: 'Docs',
      template: (c) =>
          SyncTemplates.setupDoc(androidApplicationId: c.androidApplicationId),
      description:
          'How the queue behaves, the iOS Info.plist keys, and how to see a '
          'background sync run.',
    ),
    ScaffoldSpec(
      name: 'deep-links-doc',
      title: 'Deep links guide',
      path: 'docs/DEEP_LINKS.md',
      category: 'Docs',
      template: (c) => DeepLinksTemplates.doc(
        androidApplicationId: c.androidApplicationId,
        iosBundleId: c.iosBundleId,
        withAuthFeature: c.hasAuthFeature,
      ),
      description:
          'The domain files, the iOS capability and the checks that make '
          'https links open the app.',
    ),
    ScaffoldSpec(
      name: 'firebase-doc',
      title: 'Firebase setup guide',
      path: 'docs/FIREBASE_SETUP.md',
      category: 'Docs',
      template: (c) => DocsTemplates.firebaseSetup(
        withAuth: c.hasFirebaseAuth,
        withGoogleSignIn: c.hasFirebaseAuthFeature,
        withFirestore: c.hasFirestore,
        withCrashlytics: c.hasCrashlytics,
        withMessaging: c.hasFirebaseNotifications,
      ),
      description:
          'The console and platform steps the generated Firebase code depends on.',
    ),
    ScaffoldSpec(
      name: 'workflow-doc',
      title: 'Workflow setup guide',
      path: 'docs/STEPS_FOR_WORKFLOW.md',
      category: 'Docs',
      template: (_) => DocsTemplates.stepsForWorkflow(),
      description: 'The secrets and steps the GitHub Actions workflows expect.',
    ),

    // ── AI agents ───────────────────────────────────────────────────────────
    // Each skill is two files: the body in `.agents/skills/` (Codex, Cursor,
    // Gemini CLI, Copilot) and a pointer to it in `.claude/skills/`.
    for (final skill in SkillsTemplates.all) ...[
      ScaffoldSpec(
        name: 'skill-${skill.slug}',
        title: '${skill.name} skill',
        path: skill.agentsPath,
        category: 'AI agents',
        template: (c) => SkillsTemplates.skill(skill, _skillOptions(c)),
        description: skill.summary,
      ),
      ScaffoldSpec(
        name: 'claude-skill-${skill.slug}',
        title: '${skill.name} skill (Claude Code)',
        path: skill.claudePath,
        category: 'AI agents',
        template: (_) => SkillsTemplates.claudeSkill(skill),
        description: "Claude Code's pointer to ${skill.agentsPath}.",
      ),
    ],
    ScaffoldSpec(
      name: 'claude-settings',
      title: 'Claude Code settings',
      path: '.claude/settings.json',
      category: 'AI agents',
      template: (c) => SkillsTemplates.claudeSettings(bloc: c.hasBloc),
      description:
          'Allows the checks without a prompt; denies .env and generated '
          'files.',
    ),
    ScaffoldSpec(
      name: 'gemini-settings',
      title: 'Gemini CLI settings',
      path: '.gemini/settings.json',
      category: 'AI agents',
      template: (_) => SkillsTemplates.geminiSettings(),
      description:
          'Points Gemini CLI at AGENTS.md and starts the Dart MCP server.',
    ),
    ScaffoldSpec(
      name: 'mcp',
      title: 'MCP servers',
      path: '.mcp.json',
      category: 'AI agents',
      template: (_) => SkillsTemplates.mcpJson(),
      description:
          'Starts the Dart MCP server for Claude Code: run the app, hot '
          'reload, read runtime errors.',
    ),

    // ── Workflows ───────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'workflow-ci',
      title: 'CI workflow',
      path: '.github/workflows/unified_workflow.yml',
      category: 'Workflows',
      template: (c) =>
          WorkflowTemplates.unifiedWorkflow(stateManagement: c.stateManagement),
      description: 'Analyze, test and build on every push.',
    ),
    ScaffoldSpec(
      name: 'workflow-scan',
      title: 'Code scanning workflow',
      path: '.github/workflows/csa.yml',
      category: 'Workflows',
      template: (_) => WorkflowTemplates.csaWorkflow(),
      description: 'Static/code-scanning analysis.',
    ),
    ScaffoldSpec(
      name: 'workflow-ios',
      title: 'iOS build workflow',
      path: '.github/workflows/build_ipa.yml',
      category: 'Workflows',
      template: (c) => WorkflowTemplates.buildIOS(
        withFirebase: c.hasAnyFirebase,
        // Signs with Runner.entitlements whenever it declares anything.
        withPushEntitlements:
            c.hasPushEntitlement || c.hasAppleSignInEntitlement,
      ),
      description:
          'Signs and builds the IPA (development, ad hoc or App Store), and '
          'uploads to TestFlight with an App Store Connect key.',
    ),

    // ── Project ─────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'analysis-options',
      title: 'analysis_options.yaml',
      path: 'analysis_options.yaml',
      category: 'Project',
      // The stack matters here: without it a refresh rewrites a bloc
      // project's file as the Riverpod one and drops the `bloc:` ruleset.
      template: (c) =>
          DevTemplates.analysisOptions(stateManagement: c.stateManagement),
      description: "The scaffold's lint contract.",
    ),
    ScaffoldSpec(
      name: 'splash',
      title: 'flutter_native_splash.yaml',
      path: 'flutter_native_splash.yaml',
      category: 'Project',
      template: (_) => DevTemplates.nativeSplash(),
      description: 'Splash colors for light and dark, Android 12 included.',
    ),
    ScaffoldSpec(
      name: 'launcher-icons',
      title: 'flutter_launcher_icons.yaml',
      path: 'flutter_launcher_icons.yaml',
      category: 'Project',
      template: (_) => DevTemplates.launcherIcons(),
      description:
          'The app icon on both platforms, every size made from one 1024px '
          'image.',
    ),
    ScaffoldSpec(
      name: 'build-yaml',
      title: 'build.yaml',
      path: 'build.yaml',
      category: 'Project',
      template: (c) => DevTemplates.buildYaml(withDrift: c.hasLocalCache),
      description:
          'How build_runner writes the models: nested toJson, and '
          'snake_case keys.',
    ),
    ScaffoldSpec(
      name: 'fvmrc',
      title: '.fvmrc',
      path: '.fvmrc',
      category: 'Project',
      template: (_) => DevTemplates.fvmrc(),
      description: 'The FVM Flutter channel pin.',
    ),
    ScaffoldSpec(
      name: 'widget-test',
      title: 'widget_test.dart',
      path: 'test/widget_test.dart',
      category: 'Project',
      template: (_) => DevTemplates.widgetTest(),
      description:
          "The placeholder that replaced `flutter create`'s counter test.",
    ),
    ScaffoldSpec(
      name: 'vscode-settings',
      title: '.vscode/settings.json',
      path: '.vscode/settings.json',
      category: 'Project',
      template: (_) => DevTemplates.vscodeSettings(),
      description:
          'Points the Dart/Flutter extension at the fvm SDK the .fvmrc pins.',
    ),
    ScaffoldSpec(
      name: 'vscode-launch',
      title: '.vscode/launch.json',
      path: '.vscode/launch.json',
      category: 'Project',
      template: (_) => DevTemplates.vscodeLaunch(),
      description:
          'Run & Debug configurations: debug/profile/release, flavored and not.',
    ),

    // ── iOS ─────────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'ios-entitlements',
      title: 'Runner.entitlements',
      path: 'ios/Runner/Runner.entitlements',
      category: 'iOS',
      template: (c) => IosTemplates.runnerEntitlements(
        withPush: c.hasPushEntitlement,
        withAppleSignIn: c.hasAppleSignInEntitlement,
      ),
      description: 'Push and Sign in with Apple entitlements.',
    ),
    ScaffoldSpec(
      name: 'ios-profile-entitlements',
      title: 'RunnerProfile.entitlements',
      path: 'ios/Runner/RunnerProfile.entitlements',
      category: 'iOS',
      template: (c) => IosTemplates.runnerProfileEntitlements(
        withPush: c.hasPushEntitlement,
        withAppleSignIn: c.hasAppleSignInEntitlement,
      ),
      description: 'The profile-build counterpart of Runner.entitlements.',
    ),
    ScaffoldSpec(
      name: 'xcode-script',
      title: 'add_files_to_xcode.rb',
      path: 'add_files_to_xcode.rb',
      category: 'iOS',
      template: (_) => IosTemplates.addFilesToXcodeScript(),
      description:
          'Relinks GoogleService-Info.plist into the Xcode project during CI.',
    ),

    // ── Android ─────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'proguard',
      title: 'proguard-rules.pro',
      path: 'android/app/proguard-rules.pro',
      category: 'Android',
      template: (_) => AndroidTemplates.proguardRules(),
      description:
          'R8 keep rules for the Flutter engine, Firebase, OkHttp and coroutines.',
    ),
  ];

  /// Every catalog slug.
  static List<String> get names => all.map((spec) => spec.name).toList();

  /// Looks up a spec by its CLI slug, or null if unknown.
  static ScaffoldSpec? byName(String name) {
    for (final spec in all) {
      if (spec.name == name) return spec;
    }
    return null;
  }

  /// The specs in [groups] slug [group], or an empty list when unknown.
  static List<ScaffoldSpec> byGroup(String group) {
    final category = groups[group];
    if (category == null) return const [];
    return all.where((spec) => spec.category == category).toList();
  }

  /// The specs whose file exists under [projectRoot].
  ///
  /// `update` refreshes what a project already has; a file the project chose
  /// not to generate is not missing, it is declined.
  static List<ScaffoldSpec> generated(String projectRoot) {
    final context = ScaffoldContext.detect(projectRoot);
    return all
        .where(
          (spec) =>
              File(context.resolve(spec.pathIn(context))).existsSync() ||
              (spec.movedFrom != null &&
                  File(context.resolve(spec.movedFrom!)).existsSync()),
        )
        .toList();
  }
}

/// What [c]'s skills vary with, read off the project like every other option.
SkillOptions _skillOptions(ScaffoldContext c) => SkillOptions(
  stateManagement: c.stateManagement,
  withDio: c.hasDio,
  withFirestore: c.hasFirestore,
  withRouter: c.hasRouter,
  withLocalization: c.hasLocalization,
  withEasyLocalization: c.hasEasyLocalization,
  withDarkTheme: c.hasDarkTheme,
  withStatusColors: c.hasStatusColors,
  withWorkflows: c.hasWorkflows,
  blocConcurrency: c.hasBlocConcurrency,
  withLocalCache: c.hasLocalCache,
  withSync: c.hasSync,
  withDartMcp: c.hasDartMcp,
);
