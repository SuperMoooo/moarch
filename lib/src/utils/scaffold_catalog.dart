import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/core/error_templates.dart';
import '../templates/core/security_templates.dart';
import '../templates/core/services_templates.dart';
import '../templates/misc/dev_templates.dart';
import '../templates/misc/docs_templates.dart';
import '../templates/misc/ios_templates.dart';
import '../templates/misc/workflow_templates.dart';
import '../templates/ui/auth_templates.dart';
import 'widget_catalog.dart';

/// The options a generated file's template varies with, read back off a
/// project that was scaffolded earlier.
///
/// `moarch init` picks these from a checklist; `moarch update` has to work out
/// the same answers from what is on disk, because that is the only record that
/// stays true when the project is edited afterwards. A file that was never
/// generated answers "no" to its own option, which is exactly the question
/// each template asks.
class ScaffoldContext {
  /// Creates a context. Prefer [detect] — this exists for tests.
  const ScaffoldContext({
    required this.projectRoot,
    required this.pubspec,
  });

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
  bool hasPackage(String package) =>
      RegExp('^\\s+${RegExp.escape(package)}:', multiLine: true)
          .hasMatch(pubspec);

  /// The project talks to a REST API through Dio.
  bool get hasDio =>
      hasFile('lib/core/network/dio_client.dart') || hasPackage('dio');

  /// Firestore or Firebase Auth is installed — either brings in
  /// `firebase_core`, and with it `FirebaseException`.
  bool get hasFirebase =>
      hasPackage('cloud_firestore') || hasPackage('firebase_auth');

  /// Any Firebase package at all, which is what the iOS build workflow keys
  /// off: it has to relink `GoogleService-Info.plist` for all of them.
  bool get hasAnyFirebase => hasPackage('firebase_core') || hasFirebase;

  /// Crash reporting is wired into the error handlers.
  bool get hasCrashlytics => hasPackage('firebase_crashlytics');

  /// The GoRouter setup was generated.
  bool get hasRouter => hasFile('lib/config/router/app_router.dart');

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

  /// Firestore is installed.
  bool get hasFirestore => hasPackage('cloud_firestore');

  /// Firebase Auth is installed.
  bool get hasFirebaseAuth => hasPackage('firebase_auth');
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
  });

  /// CLI slug, e.g. `validation` → `moarch update validation`.
  final String name;

  /// Human-facing name of what the file holds, e.g. `ValidationService`.
  final String title;

  /// Project-relative path with forward slashes, e.g.
  /// `lib/core/security/validation_service.dart`.
  final String path;

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
    'Workflows',
    'Project',
    'iOS',
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
    'workflows': 'Workflows',
    'project': 'Project',
    'ios': 'iOS',
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
        hasCrashlytics: c.hasCrashlytics,
      ),
      description:
          'One exception type every layer throws, mapped from Dio, Firebase and platform errors.',
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
    ScaffoldSpec(
      name: 'action-notifier',
      title: 'ActionNotifier',
      path: 'lib/core/utils/action_notifier.dart',
      category: 'Core',
      template: (_) => CoreTemplates.actionNotifier(),
      description:
          'The notifier base that turns a one-shot action into error/success fields.',
    ),
    ScaffoldSpec(
      name: 'constants',
      title: 'AppConstants',
      path: 'lib/core/constants/app_constants.dart',
      category: 'Core',
      template: (_) => CoreTemplates.appConstants(),
      description:
          'Colors, spacing, radii and typography — the values the whole UI kit reads.',
    ),
    ScaffoldSpec(
      name: 'api-constants',
      title: 'ApiConstants',
      path: 'lib/core/constants/api_constants.dart',
      category: 'Core',
      template: (_) => CoreTemplates.apiConstants(),
      description: 'Endpoint paths and API timeouts.',
    ),
    ScaffoldSpec(
      name: 'main',
      title: 'main.dart',
      path: 'lib/main.dart',
      category: 'Core',
      template: (c) => CoreTemplates.mainDart(
        withRouter: c.hasRouter,
        withLocalization: c.hasLocalization,
        withEasyLocalization: c.hasEasyLocalization,
        withNotificationsService: c.hasNotifications,
        withFirebaseNotifications: c.hasFirebaseNotifications,
        withCrashlytics: c.hasCrashlytics,
      ),
      description:
          'The entry point: ProviderScope, theme, router and the services the project selected.',
    ),

    // ── Network ─────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'dio-client',
      title: 'DioClient',
      path: 'lib/core/network/dio_client.dart',
      category: 'Network',
      template: (_) => CoreTemplates.dioClient(),
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

    // ── Security ────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'secure-storage',
      title: 'SecureStorage',
      path: 'lib/core/security/secure_storage.dart',
      category: 'Security',
      template: (_) => SecurityTemplates.secureStorage(),
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
      template: (_) => SecurityTemplates.biometricService(),
      description: 'Face ID / fingerprint via local_auth, behind one call.',
    ),

    // ── Services ────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'media-service',
      title: 'MediaService',
      path: 'lib/core/services/media_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.mediaService(),
      description:
          'Image and file pickers with the permission handling around them.',
    ),
    ScaffoldSpec(
      name: 'url-service',
      title: 'UrlLauncherService',
      path: 'lib/core/services/url_launcher_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.launchUrlService(),
      description: 'Opens external links, with the in-app web view fallback.',
    ),
    ScaffoldSpec(
      name: 'notifications-service',
      title: 'NotificationsService',
      path: 'lib/core/services/notifications_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.notificationsService(),
      description: 'Local notifications: permissions, channels and scheduling.',
    ),
    ScaffoldSpec(
      name: 'firebase-notifications',
      title: 'FirebaseNotificationsService',
      path: 'lib/core/services/firebase_notifications_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.firebaseNotificationsService(),
      description:
          'FCM tokens, foreground/background handlers and topic subscriptions.',
    ),
    ScaffoldSpec(
      name: 'debouncer',
      title: 'DebouncerService',
      path: 'lib/core/services/debouncer_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.debouncerService(),
      description: 'Debounces rapid actions, e.g. a search field.',
    ),
    ScaffoldSpec(
      name: 'permission-service',
      title: 'PermissionService',
      path: 'lib/core/services/permission_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.permissionService(),
      description:
          'One place to request a permission and handle the permanently-denied case.',
    ),
    ScaffoldSpec(
      name: 'language-service',
      title: 'LanguageService',
      path: 'lib/core/services/language_service.dart',
      category: 'Services',
      template: (_) => ServicesTemplates.languageService(),
      description:
          'Holds and persists the selected locale (flutter_localizations).',
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
      template: (_) => ConfigTemplates.appTheme(),
      description: 'Light and dark ThemeData built from AppConstants.',
    ),
    ScaffoldSpec(
      name: 'router',
      title: 'AppRouter',
      path: 'lib/config/router/app_router.dart',
      category: 'Config',
      template: (_) => ConfigTemplates.appRouter(),
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
      template: (c) => ConfigTemplates.firebaseProviders(
        hasAuth: c.hasFirebaseAuth,
        hasDb: c.hasFirestore,
      ),
      description: 'Riverpod providers for FirebaseAuth and Firestore.',
    ),

    // ── Auth feature ────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'auth-entity',
      title: 'AuthTokensEntity',
      path: 'lib/features/auth/domain/entities/auth_tokens_entity.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.entity(),
      description: 'The domain view of an access/refresh token pair.',
    ),
    ScaffoldSpec(
      name: 'auth-repository',
      title: 'AuthRepository',
      path: 'lib/features/auth/domain/repositories/auth_repository.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.repositoryInterface(),
      description: 'The repository contract the notifier depends on.',
    ),
    ScaffoldSpec(
      name: 'auth-model',
      title: 'AuthTokensModel',
      path: 'lib/features/auth/data/models/auth_tokens_model.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.model(),
      description: 'JSON ↔ entity mapping for the token pair.',
    ),
    ScaffoldSpec(
      name: 'auth-datasource',
      title: 'AuthRemoteDatasource',
      path: 'lib/features/auth/data/datasources/auth_remote_datasource.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.remoteDatasource(),
      description: 'The /auth/* calls — adjust these to your API contract.',
    ),
    ScaffoldSpec(
      name: 'auth-repository-impl',
      title: 'AuthRepositoryImpl',
      path: 'lib/features/auth/data/repositories/auth_repository_impl.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.repositoryImpl(),
      description:
          'Datasource + secure storage behind the repository contract.',
    ),
    ScaffoldSpec(
      name: 'auth-state',
      title: 'AuthState',
      path: 'lib/features/auth/presentation/states/auth_state.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.state(),
      description: 'The state the auth notifier exposes.',
    ),
    ScaffoldSpec(
      name: 'auth-notifier',
      title: 'AuthNotifier',
      path: 'lib/features/auth/presentation/notifiers/auth_notifier.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.notifier(),
      description:
          'Login, register, refresh, logout, delete and session restore.',
    ),
    ScaffoldSpec(
      name: 'auth-login-view',
      title: 'LoginView',
      path: 'lib/features/auth/presentation/views/login_view.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.loginView(),
      description: 'The login screen built from the UI kit.',
    ),
    ScaffoldSpec(
      name: 'auth-register-view',
      title: 'RegisterView',
      path: 'lib/features/auth/presentation/views/register_view.dart',
      category: 'Auth feature',
      template: (_) => AuthTemplates.registerView(),
      description: 'The register screen built from the UI kit.',
    ),

    // ── Docs ────────────────────────────────────────────────────────────────
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
      name: 'workflow-doc',
      title: 'Workflow setup guide',
      path: 'docs/STEPS_FOR_WORKFLOW.md',
      category: 'Docs',
      template: (_) => DocsTemplates.stepsForWorkflow(),
      description: 'The secrets and steps the GitHub Actions workflows expect.',
    ),

    // ── Workflows ───────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'workflow-ci',
      title: 'CI workflow',
      path: '.github/workflows/unified_workflow.yml',
      category: 'Workflows',
      template: (_) => WorkflowTemplates.unifiedWorkflow(),
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
        withPushEntitlements: c.hasFirebaseNotifications,
      ),
      description: 'Signs and builds the IPA.',
    ),
    ScaffoldSpec(
      name: 'workflow-android',
      title: 'Android build workflow',
      path: '.github/workflows/build_apk.yml',
      category: 'Workflows',
      template: (_) => WorkflowTemplates.buildANDROID(),
      description: 'Signs and builds the APK/AAB.',
    ),
    ScaffoldSpec(
      name: 'workflow-deploy',
      title: 'Store deploy workflow',
      path: '.github/workflows/deploy_stores.yml',
      category: 'Workflows',
      template: (_) => WorkflowTemplates.deployWorkflow(),
      description: 'Uploads a build to App Store Connect / Play Console.',
    ),

    // ── Project ─────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'analysis-options',
      title: 'analysis_options.yaml',
      path: 'analysis_options.yaml',
      category: 'Project',
      template: (_) => DevTemplates.analysisOptions(),
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

    // ── iOS ─────────────────────────────────────────────────────────────────
    ScaffoldSpec(
      name: 'ios-entitlements',
      title: 'Runner.entitlements',
      path: 'ios/Runner/Runner.entitlements',
      category: 'iOS',
      template: (_) => IosTemplates.runnerEntitlements(),
      description: 'APNs entitlements for remote push.',
    ),
    ScaffoldSpec(
      name: 'ios-profile-entitlements',
      title: 'RunnerProfile.entitlements',
      path: 'ios/Runner/RunnerProfile.entitlements',
      category: 'iOS',
      template: (_) => IosTemplates.runnerProfileEntitlements(),
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
    final root = p.absolute(projectRoot);
    return all
        .where((spec) =>
            File(p.joinAll([root, ...p.posix.split(spec.path)])).existsSync())
        .toList();
  }
}
