import '../../utils/state_management.dart';
import 'readme_templates.dart';

/// What the generated project's documentation varies with: the stack and
/// every option that adds files a guide would describe.
///
/// `init` fills it from its checklist; the catalog fills it from
/// `ScaffoldContext`, so `moarch update` re-renders a guide for the project as
/// it is now.
class DocsOptions {
  /// Creates the options. Everything but the name and the stack is off.
  const DocsOptions({
    required this.projectName,
    required this.stateManagement,
    this.flavors = const [],
    this.withDio = false,
    this.withRouter = false,
    this.withAuthFeature = false,
    this.withFirebaseAuthFeature = false,
    this.withFirebase = false,
    this.withFirestore = false,
    this.withCrashlytics = false,
    this.withAnalytics = false,
    this.withFirebaseNotifications = false,
    this.withNotifications = false,
    this.withLocalization = false,
    this.withEasyLocalization = false,
    this.withBiometric = false,
    this.withDarkTheme = false,
    this.withThemeMode = false,
    this.withStatusColors = false,
    this.withMoAdapt = false,
    this.withWorkflows = false,
    this.withLocalCache = false,
    this.withSync = false,
    this.withOfflineGate = false,
    this.withDeepLinks = false,
    this.withMaintenanceGate = false,
    this.withUpdateGate = false,
    this.withMediaService = false,
    this.withUrlService = false,
    this.withDebouncer = false,
    this.withAppLifecycle = false,
    this.withPreferences = false,
    this.withAppleSignIn = false,
  });

  /// The project's package name.
  final String projectName;

  /// Riverpod or bloc.
  final StateManagement stateManagement;

  /// The flavors in `flavorizr.yaml`; empty until `moarch create flavors`.
  final List<String> flavors;

  /// The project talks to a REST API through Dio.
  final bool withDio;

  /// GoRouter is set up.
  final bool withRouter;

  /// The auth feature was generated, against either backend.
  final bool withAuthFeature;

  /// The auth feature is the Firebase one (email/password and Google).
  final bool withFirebaseAuthFeature;

  /// Any Firebase product is installed.
  final bool withFirebase;

  /// Cloud Firestore is installed.
  final bool withFirestore;

  /// Crashlytics is installed.
  final bool withCrashlytics;

  /// `AnalyticsService` on Firebase Analytics was generated.
  final bool withAnalytics;

  /// FCM push notifications.
  final bool withFirebaseNotifications;

  /// Local notifications.
  final bool withNotifications;

  /// flutter_localizations with `.arb` files.
  final bool withLocalization;

  /// easy_localization with JSON files.
  final bool withEasyLocalization;

  /// Face ID / fingerprint unlock.
  final bool withBiometric;

  /// The palette has a dark half.
  final bool withDarkTheme;

  /// The light / dark / system choice is saved.
  final bool withThemeMode;

  /// Success / warning / info are a ThemeExtension.
  final bool withStatusColors;

  /// The app scales with MoAdapt.
  final bool withMoAdapt;

  /// The GitHub Actions workflows.
  final bool withWorkflows;

  /// The offline-first cache.
  final bool withLocalCache;

  /// The offline write queue.
  final bool withSync;

  /// The offline screen over the app.
  final bool withOfflineGate;

  /// App Links and Universal Links.
  final bool withDeepLinks;

  /// The backend kill switch.
  final bool withMaintenanceGate;

  /// The backend minimum version.
  final bool withUpdateGate;

  /// Image and file pickers.
  final bool withMediaService;

  /// External links.
  final bool withUrlService;

  /// The debouncer.
  final bool withDebouncer;

  /// Foreground / background as streams.
  final bool withAppLifecycle;

  /// shared_preferences, loaded before runApp.
  final bool withPreferences;

  /// Sign in with Apple: always with Firebase auth, opt-in with REST.
  final bool withAppleSignIn;

  /// Whether the project is on bloc.
  bool get bloc => stateManagement.isBloc;

  /// Whether the project has any localization.
  bool get withAnyLocalization => withLocalization || withEasyLocalization;
}

/// One guide under `docs/`: where it is, what it answers, which projects get
/// it and, for the ones this file writes, how.
class ProjectDoc {
  /// Creates a guide entry.
  const ProjectDoc({
    required this.slug,
    required this.file,
    required this.title,
    required this.answers,
    required this.applies,
    this.render,
  });

  /// The catalog slug: `moarch update <slug>`.
  final String slug;

  /// The file name under `docs/`.
  final String file;

  /// The guide's title.
  final String title;

  /// One line for the README's guides table: what the guide answers.
  final String answers;

  /// Whether a project with these options has the guide.
  final bool Function(DocsOptions options) applies;

  /// The guide's source, or null for one another template writes (the
  /// checklists, the UI kit, the setup guides): those are only listed.
  final String Function(DocsOptions options)? render;

  /// Project-relative path.
  String get path => 'docs/$file';
}

/// The project's guides, and the topic guides this file writes.
abstract final class ProjectDocsTemplates {
  /// Every guide a generated project can have, in the order the README lists
  /// them. The ones with a `render` are written from here; the rest have their
  /// own catalog entries and are listed so the README links every guide.
  static final List<ProjectDoc> all = [
    ProjectDoc(
      slug: 'architecture-doc',
      file: 'ARCHITECTURE.md',
      title: 'Architecture',
      answers:
          'How a feature is put together, how the locator wires it, how errors '
          'reach the UI, and how to add one',
      applies: (_) => true,
      render: ReadmeTemplates.architectureDoc,
    ),
    ProjectDoc(
      slug: 'state-doc',
      file: 'STATE_MANAGEMENT.md',
      title: 'State management',
      answers: 'How a screen holds its state, step by step',
      applies: (_) => true,
      render: ReadmeTemplates.stateManagementDoc,
    ),
    ProjectDoc(
      slug: 'networking-doc',
      file: 'NETWORKING.md',
      title: 'Networking',
      answers:
          'The Dio client, endpoints, errors, the token refresh, retries and '
          'pagination',
      applies: (o) => o.withDio,
      render: networking,
    ),
    ProjectDoc(
      slug: 'auth-doc',
      file: 'AUTH.md',
      title: 'Authentication',
      answers: 'Sign-in, the session, its refresh, sign-out and the redirect',
      applies: (o) => o.withAuthFeature,
      render: auth,
    ),
    ProjectDoc(
      slug: 'routing-doc',
      file: 'ROUTING.md',
      title: 'Routing',
      answers: 'Routes, navigation, the auth redirect and adding a screen',
      applies: (o) => o.withRouter,
      render: routing,
    ),
    const ProjectDoc(
      slug: 'offline-doc',
      file: 'OFFLINE_FIRST.md',
      title: 'Offline-first',
      answers:
          'The cache, each feature\'s table, the read and write paths, and '
          'migrations',
      applies: _hasLocalCache,
    ),
    const ProjectDoc(
      slug: 'sync-setup',
      file: 'SYNC_SETUP.md',
      title: 'Offline sync setup',
      answers: 'How the write queue behaves, and the iOS background setup',
      applies: _hasSync,
    ),
    ProjectDoc(
      slug: 'theme-doc',
      file: 'THEME.md',
      title: 'Theme & UI',
      answers:
          'The palette, spacing and type, the theme, dark mode and the UI kit',
      applies: (_) => true,
      render: theme,
    ),
    ProjectDoc(
      slug: 'localization-doc',
      file: 'LOCALIZATION.md',
      title: 'Localization',
      answers: 'Where strings live, adding a key or a language',
      applies: (o) => o.withAnyLocalization,
      render: localization,
    ),
    ProjectDoc(
      slug: 'notifications-doc',
      file: 'NOTIFICATIONS.md',
      title: 'Notifications',
      answers: 'Local notifications and push: permissions, scheduling, topics',
      applies: (o) => o.withNotifications || o.withFirebaseNotifications,
      render: notifications,
    ),
    ProjectDoc(
      slug: 'services-doc',
      file: 'SERVICES.md',
      title: 'Services',
      answers: 'Every service under `lib/core/` and when to reach for it',
      applies: (_) => true,
      render: services,
    ),
    const ProjectDoc(
      slug: 'firebase-doc',
      file: 'FIREBASE_SETUP.md',
      title: 'Firebase setup',
      answers: 'The console and platform steps the Firebase code depends on',
      applies: _hasFirebase,
    ),
    const ProjectDoc(
      slug: 'deep-links-doc',
      file: 'DEEP_LINKS.md',
      title: 'Deep links',
      answers: 'The domain files and checks that make https links open the app',
      applies: _hasDeepLinks,
    ),
    ProjectDoc(
      slug: 'testing-doc',
      file: 'TESTING.md',
      title: 'Testing',
      answers: 'What to test, generating tests, mocks and running them',
      applies: (_) => true,
      render: testing,
    ),
    ProjectDoc(
      slug: 'flavors-doc',
      file: 'FLAVORS.md',
      title: 'Flavors & environments',
      answers: 'Several builds of one app, and how they differ from `.env`',
      applies: (_) => true,
      render: ReadmeTemplates.flavorsDoc,
    ),
    ProjectDoc(
      slug: 'release-doc',
      file: 'BUILD_AND_RELEASE.md',
      title: 'Build & release',
      answers: 'Building each platform, CI/CD and the GitHub secrets',
      applies: (_) => true,
      render: ReadmeTemplates.buildAndReleaseDoc,
    ),
    ProjectDoc(
      slug: 'standards-doc',
      file: 'CODE_STANDARDS.md',
      title: 'Code standards',
      answers: 'Naming, widgets, errors, and what to run before a commit',
      applies: (_) => true,
      render: ReadmeTemplates.codeStandardsDoc,
    ),
    const ProjectDoc(
      slug: 'ui-kit',
      file: 'UI_KIT.md',
      title: 'UI kit',
      answers: 'Every shared widget, what it takes and what it looks like',
      applies: _always,
    ),
    const ProjectDoc(
      slug: 'deploy-checklist',
      file: 'CHECKLIST_BEFORE_DEPLOYMENT.md',
      title: 'Deployment checklist',
      answers: 'What still needs doing before a release',
      applies: _always,
    ),
    const ProjectDoc(
      slug: 'security-checklist',
      file: 'SECURITY_BEFORE_DEPLOYMENT.md',
      title: 'Security checklist',
      answers: 'The security review, mapped to the OWASP Mobile Top 10',
      applies: _always,
    ),
    const ProjectDoc(
      slug: 'jks-doc',
      file: 'GENERATE_JKS_FILE.md',
      title: 'Android keystore',
      answers: 'Creating the Android signing keystore, and its base64',
      applies: _always,
    ),
    const ProjectDoc(
      slug: 'workflow-doc',
      file: 'STEPS_FOR_WORKFLOW.md',
      title: 'Workflow secrets',
      answers: 'Every GitHub secret the workflows need, produced step by step',
      applies: _always,
    ),
  ];

  /// The guides this file writes: what `init` and the catalog generate.
  static Iterable<ProjectDoc> get written =>
      all.where((doc) => doc.render != null);

  static bool _always(DocsOptions _) => true;
  static bool _hasLocalCache(DocsOptions o) => o.withLocalCache;
  static bool _hasSync(DocsOptions o) => o.withSync;
  static bool _hasFirebase(DocsOptions o) => o.withFirebase;
  static bool _hasDeepLinks(DocsOptions o) => o.withDeepLinks;

  /// The line under every guide's title, pointing back at the README.
  static String header(String title, String purpose) =>
      '''
# $title

> Part of the [project guide](../README.md). $purpose
''';

  /// `docs/NETWORKING.md` — the REST stack, from the endpoint constant to the
  /// error the screen shows.
  static String networking(DocsOptions o) {
    final holder = o.bloc ? 'bloc' : 'notifier';
    final refresh = o.withAuthFeature && !o.withFirebaseAuthFeature
        ? '''
## The token refresh

Every request but the sign-in routes gets `Authorization: Bearer <access
token>`, read from `TokenStorage` (`core/security/secure_storage.dart`) as
the request leaves. When one comes back **401**:

1. the client calls `AuthRepository.refresh()`, which trades the stored
   refresh token for a new session;
2. it replays the original request once, with the new token;
3. if the refresh itself fails, the session is cleared and the error goes on
   to the caller — the router then sends the user to sign in.

Concurrent 401s share one refresh, so the refresh token is spent once. The
routes that never get a token or a retry are listed in `_kPublicEndpoints`
in `dio_client.dart`: add your API's other public routes there.
'''
        : '''
## Public routes and the Authorization header

`dio_client.dart` attaches the access token in `TokenStorage` to every
request except the routes listed in `_kPublicEndpoints`. Add your API's
sign-in routes there. There is no refresh flow without the auth feature: a
401 is a 401.
''';
    final paging =
        '''
## Lists that page

A repository returns `Paginated<T>` (`core/network/paginated.dart`): the items
and the key of the next page. Only the datasource knows whether that key is a
page number, an offset or a cursor; everything above passes it back unopened,
so switching an endpoint from pages to cursors touches one file.

```dart
Future<Paginated<OrderModel>> fetchOrders({Object? next}) => safeApiCall(
  apiCall: () async {
    final response = await _dio.get(
      ApiConstants.orders,
      queryParameters: {'page': next ?? 1, 'limit': 20},
    );
    return Paginated.fromPageJson(
      response.data as Map<String, dynamic>,
      (e) => OrderModel.fromJson(e! as Map<String, dynamic>),
    );
  },
);
```

`Paginated.fromPageJson`, `fromOffsetJson` and `fromCursorJson` read the usual
envelopes — edit their default keys to match yours. The state holds a
`PagedList<T>` (`core/utils/paged_list.dart`) and loads past the first page
through ${o.bloc ? '`PagedBlocMixin`' : '`PagedNotifierMixin`'}; the view draws it with
`AppPagedList`, `AppPagedGrid` or `AppPagedSliver`.
''';
    final offline = o.withLocalCache
        ? '''
## Offline

`ConnectivityService` (`core/services/connectivity_service.dart`) reports
online only when the API answers: once a network interface is up, it sends a
`HEAD` to `BASE_URL` with a 3-second timeout, and any response — even a 404 —
counts. Wifi behind a captive portal, or a router with no uplink, reads as
offline. Requests still handle `NetworkException`, because the connection can
drop between the check and the call. How the cache answers while offline is
`docs/OFFLINE_FIRST.md`.
'''
        : '''
## Offline

`ConnectivityService` (`core/services/connectivity_service.dart`), when the
project has it, reports online only when the API answers a `HEAD` to
`BASE_URL`, not merely when a network interface is up. A request made offline
fails with `NetworkException`; show its message.
''';
    return '''
${header('Networking', 'How the app talks to its REST API.')}
## The pieces

| File | What it does |
|---|---|
| `lib/config/env/app_env.dart` | `AppEnv.baseUrl`, compiled in from `BASE_URL` in `.env` |
| `lib/core/constants/api_constants.dart` | Every endpoint path, and the timeouts |
| `lib/core/network/dio_client.dart` | The one `Dio`: base URL, timeouts, the auth header, retries, logging |
| `lib/core/network/safe_api_call.dart` | Turns any failure into an `AppException` |
| `lib/core/errors/app_exception.dart` | The one error type the UI sees |
| `lib/core/network/paginated.dart` | A page of items and the key of the next one |

The client is registered once in `lib/config/di/external_module.dart` and
handed to each remote datasource, so nothing else builds a `Dio`.

## A request, start to finish

```dart
// data/datasources/order_remote_datasource.dart
Future<List<OrderModel>> fetchAll() => safeApiCall(
  apiCall: () async {
    final response = await _dio.get(ApiConstants.orders);
    return (response.data as List)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);
```

1. **The path is a constant.** Every endpoint lives in `ApiConstants`, never
   as a string at the call site. `moarch create feature` adds each feature's
   above the `// moarch:endpoints` comment — keep that line where it is.
2. **The datasource makes the call** and parses the JSON into the model.
3. **`safeApiCall` translates the failure.** No connection or a timeout
   becomes `NetworkException`, a 404 `NotFoundException`, and any other
   status `ServerException`, carrying the `message` the server sent when it
   sent one. Nothing above the datasource sees a `DioException`.
4. **The repository** passes the model up; the $holder shows
   `AppException.message` when it throws.

## Retries and timeouts

`dio_smart_retry` retries a request that failed on a transient error — a
dropped connection, a timeout, a 408, 429 or 5xx — a few times with a growing
delay, before `safeApiCall` sees it. Any other 4xx is not retried: the request
itself is wrong. Connect and receive timeouts are
`ApiConstants.connectTimeout` / `receiveTimeout`.
$refresh
$paging
$offline
## Adding an endpoint

1. Add the path to `ApiConstants`.
2. Add the call to the feature's remote datasource, wrapped in `safeApiCall`.
3. Add the method to the repository that the $holder calls.
4. Change `BASE_URL` per environment in `.env`, never in code. CI reads it
   from the `BASE_URL` GitHub secret.

In debug builds every request and response is logged through `AppLogger`;
release builds log nothing.
''';
  }

  /// `docs/AUTH.md` — the session, for whichever backend the auth feature
  /// was generated against.
  static String auth(DocsOptions o) {
    final holder = o.bloc ? 'AuthBloc' : 'AuthNotifier';
    final holderPath = o.bloc
        ? 'presentation/blocs/auth_bloc.dart'
        : 'presentation/notifiers/auth_notifier.dart';
    final call = o.bloc
        ? "context.read<AuthBloc>().add(AuthLoginRequested(email: email, password: password));"
        : 'ref.read(authNotifierProvider.notifier).login(email: email, password: password);';
    final cache = o.withLocalCache
        ? '\nStarting or ending a session also empties the offline cache '
              '(`LocalCache.clearAll()`), so the next account never sees the '
              'last one\'s data. Anything else that switches accounts calls it '
              'too.\n'
        : '';
    final redirect = o.withRouter
        ? '''
## The redirect

`lib/config/router/app_router.dart` re-runs its redirect whenever the auth
state changes:

- signed out, on a route that is not in `AppRoutes.publicRoutes` → the login
  screen, with `?from=` carrying where the user was going;
- signed in, on the login or register screen → `from`, or home;
- signed in with an address not verified yet → the verify-email screen, until
  it is;
- while the session is still being restored → the splash screen.

So a screen never checks the session itself, and signing out from anywhere
lands on the login screen. Add a route that needs no account to
`AppRoutes.publicRoutes`.
'''
        : '';
    final backend = o.withFirebaseAuthFeature
        ? '''
## How it works — Firebase

| File | What it does |
|---|---|
| `data/datasources/auth_remote_datasource.dart` | FirebaseAuth: email/password, Google and Apple sign-in, password reset, verification, sign-out, delete |
| `data/models/auth_user_model.dart` | The signed-in user, plus the Firestore profile document |
| `data/repositories/auth_repository.dart` | What the state holder calls |
| `$holderPath` | Every action, and the session as state |
| `presentation/views/` | Login, register, forgot password, verify email |

Firebase owns the session: it persists the user across launches and refreshes
its token on its own, so there is no token storage to manage. The state
follows `authStateChanges()`, which is why signing in on one screen updates
every other one.

Google and Apple sign-in need the console and platform steps in
`docs/FIREBASE_SETUP.md` (the SHA fingerprints, the iOS URL scheme, the Apple
provider and capability), and fail at runtime, not at build time, when one
is missing.

**Sign in with Apple** is there because App Store review requires it in an
app that offers Google sign-in. On iOS and macOS it is the native sheet; on
Android Firebase opens Apple's web flow. Deleting an account revokes the
Apple grant too (also an App Store requirement), which asks the user to
confirm with Apple once more.

**Password reset** — Firebase emails a link to its own reset page; the
forgot-password screen only asks for the address.

**Email verification** — a new account is sent the email at sign-up, and the
router holds it on the verify-email screen until the link is followed. The
verification happens in the browser and raises no auth event, so the screen's
"I've verified it" reloads the user to see it. Google and Apple accounts are
verified already.
'''
        : '''
## How it works — REST

| File | What it does |
|---|---|
| `data/datasources/auth_remote_datasource.dart` | `POST /auth/login`, `/auth/register`, `/auth/refresh`, `/auth/logout`, `/auth/password/forgot`, `/auth/password/reset`, `/auth/email/resend`${o.withAppleSignIn ? ', `/auth/apple`' : ''}, `GET` and `DELETE /auth/me` |
| `data/models/auth_tokens_model.dart` | The access/refresh token pair, as the API sends it |
| `data/models/user_model.dart` | The signed-in user, as `GET /auth/me` returns it |
| `data/repositories/auth_repository.dart` | The session: tokens saved, refreshed and cleared |
| `$holderPath` | Every action, and the session as state |
| `presentation/views/` | Login, register, forgot password, verify email |
| `core/security/secure_storage.dart` | `TokenStorage`: the tokens, in the Keychain / Keystore |

The paths are in `ApiConstants` (`authLogin`, `authRegister`, `authRefresh`,
`authLogout`, `authAccount`, `authPasswordForgot`, `authPasswordReset`,
`authEmailResend`${o.withAppleSignIn ? ', `authApple`' : ''}). Change them, and the payload keys in the
datasource and the fields of `UserModel`, to match your API.

### The session

- **Sign in / register** — the API returns a token pair; the repository saves
  it in `TokenStorage`, then loads the user from `GET /auth/me`. If that call
  fails the tokens are removed again, so a half-started session never stays.
- **App start** — `isLoggedIn()` restores the session when a refresh token is
  stored and can still be exchanged for an access token.
- **Every request** — the Dio client attaches the access token and, on a 401,
  refreshes once and replays the request (`docs/NETWORKING.md`).
- **Sign out** — revokes the session on the backend (best effort) and always
  clears it locally, online or not.
- **Delete account** — `DELETE /auth/me`, then clears the session.
- **Password reset** — `POST /auth/password/forgot` emails a code; the
  forgot-password screen then sends it with the new password to
  `/auth/password/reset`. The API should answer the first the same whether
  or not the address has an account.
- **Email verification** — `UserModel.emailVerified` is the API's
  `email_verified`, true when it sends none. A user whose address is not
  verified is held on the verify-email screen; `POST /auth/email/resend`
  sends the email again, and reloading the user (`GET /auth/me`) lets them in
  once it is done.${o.withAppleSignIn ? '''
- **Sign in with Apple** — the Apple sheet returns an identity token, which
  `POST /auth/apple` trades for a session like a login. **Your API verifies
  the token** against Apple's public keys
  (`https://appleid.apple.com/auth/keys`), checks its audience is your bundle
  id, and on the first sign-in stores the name, which Apple sends only then.
  On account deletion it has to revoke the Apple token too
  (`https://appleid.apple.com/auth/revoke`), as App Store review requires.
  iOS needs the Sign in with Apple capability (Xcode → Signing &
  Capabilities). Android has no native sheet: set `kAppleWebAuthentication`
  in the datasource to a Services ID and a redirect URL your backend serves.''' : ''}

Tokens only ever live in `TokenStorage`, never in `SharedPreferences` or in
state.
''';
    return '''
${header('Authentication', 'How a user signs in, and how the session is kept.')}
The auth feature lives in `lib/features/auth/`, built like any other feature
(`docs/ARCHITECTURE.md`). The screens call `$holder`, never the repository:

```dart
$call
```
$backend$cache$redirect
## Changing it

- **A field on the user** → add it to the model, run `build_runner`.
- **Another sign-in method** → a datasource call, a repository method that
  starts the session the same way, a ${o.bloc ? 'bloc event' : 'notifier method'} through `runAction`.
- **Who may see a screen** → the redirect${o.withRouter ? ' and `AppRoutes.publicRoutes`' : ''}, never a check
  in the screen.
''';
  }

  /// `docs/ROUTING.md` — GoRouter as the project sets it up.
  static String routing(DocsOptions o) {
    final target = o.bloc
        ? 'the feature\'s **page** (`presentation/pages/<x>_page.dart`), which provides its bloc'
        : 'the feature\'s **view** (`presentation/views/<x>_view.dart`)';
    final router = o.bloc
        ? '`appRouter`, built once, with `rootNavigatorKey`'
        : '`routerProvider`, so the redirect can read the auth state';
    final noContext = o.bloc
        ? '`appRouter.go(...)`'
        : '`ref.read(routerProvider).go(...)`';
    final auth = o.withAuthFeature
        ? '''
## The auth redirect

The router re-runs its redirect whenever the auth state changes. Signed out
on a route outside `AppRoutes.publicRoutes` sends the user to the login
screen with `?from=` set; signing in sends them back there. A screen never
checks the session itself. `docs/AUTH.md` has the full rules.
'''
        : '';
    final links = o.withDeepLinks
        ? '''
## Deep links

Any route can be opened from an https link, on a cold start. So a screen
loads from its path and query (`/orders/42`), never from `extra` or from
state the previous screen left behind. The platform setup is
`docs/DEEP_LINKS.md`.
'''
        : '''
## Passing data to a screen

Pass an id in the path (`/orders/:id`) and let the screen load it, rather
than handing it a whole object through `extra`. It keeps every screen
reachable from its URL — which is what a deep link or a web build needs —
and survives the app being restored by the OS.
''';
    return '''
${header('Routing', 'How screens are reached and how navigation works.')}
Routing is [go_router](https://pub.dev/packages/go_router), in
`lib/config/router/`:

| File | What it holds |
|---|---|
| `app_routes.dart` | `AppRoutes`: every path as a constant, and `publicRoutes` |
| `app_router.dart` | $router, the route table and the redirect |

## Navigating

```dart
context.go(AppRoutes.orders);            // replace the stack: tabs, after sign-in
context.push(AppRoutes.orderDetail);     // on top: a detail, a form
context.pop();                           // back
```

Always use the `AppRoutes` constant, never a string. Outside the widget tree
(a notification tap, a service), navigate with $noContext.

## The account screens

`AppRoutes.forgotPassword` is public, so it opens signed out.
`AppRoutes.verifyEmail` is where the redirect holds a signed-in user whose
address is not verified, and it leaves by itself once it is. Neither needs a
check in the screen.

## Adding a screen

`moarch create feature <name>` adds `AppRoutes.<name>` and its `GoRoute` for
you, above the `// moarch:routes` comment in each file — keep those lines
where they are. By hand:

1. Add the path to `AppRoutes`.
2. Add a `GoRoute` to `app_router.dart` pointing at $target.
3. A route with a parameter reads it from `state.pathParameters['id']`.
$auth$links''';
  }

  /// `docs/THEME.md` — the palette, the theme built from it, and the kit.
  static String theme(DocsOptions o) {
    final dark = o.withDarkTheme
        ? '''
## Dark mode

`AppConstants` has a dark half of every role, and `AppTheme` builds a dark
`ThemeData` from it. A literal `Color` in a widget is a bug in one of the two
themes, so colors always come from the theme.${o.withThemeMode ? '''

Light / dark / system is the user's choice, saved across launches in
`core/services/theme_mode_service.dart`:

```dart
${o.bloc ? 'context.read<ThemeModeCubit>().setMode(ThemeMode.dark);' : 'ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);'}
```

Never set `themeMode` on `MaterialApp` by hand.''' : ''}
'''
        : '''
## Dark mode

This project has one theme. Add the dark half later with:

```bash
moarch create theme --dark
```
''';
    final status = o.withStatusColors
        ? '''
Success, warning and info have no slot in `ColorScheme`, so they are a
`ThemeExtension` (`config/theme/app_status_colors.dart`) that follows the
theme:

```dart
final color = context.statusColors.success;
```
'''
        : '';
    final adapt = o.withMoAdapt
        ? '''
## Scaling: MoAdapt

The root widget is wrapped in `MoAdapt` (`shared/widgets/mo_adapt.dart`):
every logical size in the app scales to the screen relative to the design's
reference size, so a layout drawn at the design's width looks the same on a
small phone and a large one. There are no `.w` / `.h` / `.sp` helpers to call
— write the sizes from the design. Change the reference size (and whether it
scales by width, height or the smaller of the two) where `MoAdapt` wraps the
app in `main.dart`.
'''
        : '';
    return '''
${header('Theme & UI', 'Where the look of the app is defined, and how screens use it.')}
## One source for every value

`lib/core/constants/app_constants.dart` (`AppConstants`) holds the design
tokens:

- **Color roles** — `primary`, `secondary`, `surface`, `onSurface`,
  `outline`, `error` and the surface containers. Set them to the brand
  palette; every widget reads the roles, never a hex value.
- **Spacing and padding** — `space4` … `space48`, `padding16`,
  `paddingPage`.
- **Radii, icon sizes, durations, curves and shadows** — `borderRadius12`,
  `iconMedium`, `duration300`, `curveStandard`, `shadowCard`.
- **Typography** — the font family and the size of each text role.

`lib/config/theme/app_theme.dart` (`AppTheme`) builds the `ThemeData` from
those values: the `ColorScheme`, the text theme and every component theme
(buttons, inputs, cards, dialogs). Change a value in `AppConstants` and the
whole app follows.

## Corners

One line in `AppConstants` sets how round the whole app is:

```dart
static const AppCorners corners = AppCorners.rounded;   // or .soft, or .square
```

Every radius token follows it (`radius12`, `borderRadius16`, `radiusFull`…),
so the theme and every widget of the kit — cards, sheets, dialogs, inputs,
buttons, chips, tabs, toasts, menus, pills — change together. Icon buttons,
which are round by default, go square in a square app. True circles stay
round: avatars, radios, and anything given `shape: …circle` on purpose.
A single widget still overrides it: every shape option of the kit has a
`square` value (`AppButtonShape.square`, `AppInputShape.square`…).

## Rules for screens

- **No magic numbers.** Spacing, radii, durations come from `AppConstants`;
  text sizes from `Theme.of(context).textTheme` roles (`bodyMedium`,
  `titleLarge`), never a `fontSize`.
- **No hard-coded colors.** Read `Theme.of(context).colorScheme`.
- **One accent.** `primary` marks the screen's main action and selected or
  focused states — nothing decorative. Other actions use the secondary
  (tonal) or tertiary (outlined) button variants.
$status$dark
## The UI kit

`lib/shared/widgets/` is the kit: `AppButton`, `AppInput`, `AppAppBar`,
`AppToast`, `ErrorView`, `EmptyView` and the rest, all drawn from the theme.
Build screens from it before reaching for raw Material widgets.
`docs/UI_KIT.md` lists every widget; one the list has and the project does
not is added with:

```bash
moarch create widget <name>
```

A loading state is the screen itself, skeletonized: each screen has a
`<x>_skeleton.dart` drawing the same rows over placeholder data, and
`skeletonizer` turns it into bones.
$adapt''';
  }

  /// `docs/LOCALIZATION.md` — whichever of the two localization setups the
  /// project has.
  static String localization(DocsOptions o) {
    final language = o.bloc
        ? "context.read<LanguageCubit>().changeLanguage('pt');"
        : "ref.read(languageProvider.notifier).changeLanguage('pt');";
    final body = o.withEasyLocalization
        ? '''
## Where strings live

User-facing text lives in `assets/translations/<language>.json`
([easy_localization](https://pub.dev/packages/easy_localization)), one file
per language, and is read by key:

```dart
Text('login.title'.tr())
Text('orders.count'.plural(count))
Text('greeting'.tr(namedArgs: {'name': user.name}))
```

## Adding a key

Add it to **every** language file, with the same nesting. A key missing from
one file shows the raw key in that language — easy to miss in review.

## Adding a language

1. Add `assets/translations/<code>.json` with every key.
2. Add the `Locale` to `supportedLocales` in `main.dart`.
3. On iOS, add the language to `CFBundleLocalizations` in `Info.plist`.
'''
        : '''
## Where strings live

User-facing text lives in `lib/l10n/app_<language>.arb`
([flutter_localizations](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)),
one file per language. Flutter generates `AppLocalizations` from them:

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.loginTitle);
Text(l10n.ordersCount(count));   // plurals and placeholders are declared in the .arb
```

## Adding a key

1. Add it to **every** `.arb` file (the English one carries the `@key`
   description and placeholders).
2. Regenerate the accessors:

   ```bash
   fvm flutter gen-l10n
   ```

A key missing from one file falls back to the template language, which is
easy to miss in review.

## Adding a language

1. Add `lib/l10n/app_<code>.arb` with every key.
2. Run `fvm flutter gen-l10n`; `supportedLocales` picks it up.
3. On iOS, add the language to `CFBundleLocalizations` in `Info.plist`.
''';
    return '''
${header('Localization', 'How the app is translated.')}$body
## Moving hard-coded strings

```bash
moarch l10n extract --dry-run   # what would move
moarch l10n extract
```

It finds the strings in the screens (`Text(...)`, and `title:`, `label:`,
`hintText:`, `tooltip:` and the like) under each feature's `presentation/`
and `lib/shared/views/`, adds a key for each to every translation file — the
source language gets the text, the others the same text to translate — and
rewrites the screen to read it, removing a `const` that would no longer
compile. A string it cannot move safely (one that interpolates a value, has
braces, or has no `BuildContext` near it) is listed instead. The UI kit in
`lib/shared/widgets/` is left alone.${o.withLocalization ? ' Run `fvm flutter gen-l10n` afterwards.' : ''}

## Switching language

The selected locale is held by `core/services/language_service.dart` and
survives a restart:

```dart
$language
```

Dates, numbers and currencies go through `intl` with the current locale,
never a hand-written format.
''';
  }

  static const _foregroundShown = '''
- **Foreground messages** are shown through the local `NotificationService`:
  with the app open, Android shows no system notification at all, and iOS
  only for a message with a `notification` block.''';

  static const _foregroundLogged = '''
- **Foreground messages** are only logged: with the app open, Android shows
  no system notification. Show one yourself with
  `flutter_local_notifications` if foreground messages matter.''';

  /// `docs/NOTIFICATIONS.md` — local notifications, push, or both.
  static String notifications(DocsOptions o) {
    final local = o.withNotifications
        ? '''
## Local notifications

`NotificationService` (`core/services/notifications_service.dart`) wraps
`flutter_local_notifications`: the Android channels, the permission prompt
and scheduling.

```dart
final notifications = getIt<NotificationService>();
await notifications.requestPermissions();          // once, at a sensible moment
await notifications.show(id: 1, title: 'Saved', body: 'Your order is in.');
await notifications.scheduleAt(id: 2, title: 'Reminder', body: '…', scheduledDate: when);
await notifications.scheduleDailyAt(id: 3, title: '…', body: '…', hour: 9, minute: 0);
await notifications.cancel(2);
```

`init()` runs at startup in `main.dart`. Scheduled times are time-zone aware
(`timezone`), so a reminder at 09:00 stays at 09:00 across a daylight-saving
change. Give every notification a stable `id`: it is how one is replaced or
cancelled.

Ask for the permission when the user does something that needs it — not on
first launch, where it is most often refused.
'''
        : '';
    final push = o.withFirebaseNotifications
        ? '''
## Push notifications (FCM)

`FirebaseNotificationsService`
(`core/services/firebase_notifications_service.dart`) wraps
`firebase_messaging`:

- **The device token** — `getDeviceToken()`. Send it to your backend after
  sign-in, and again when it changes; it is what the backend targets.
${o.withNotifications ? _foregroundShown : _foregroundLogged}
- **Background and terminated messages** go to a top-level handler
  (`FirebaseMessaging.onBackgroundMessage`). It runs in its own isolate, with
  none of the app's state: keep it to logging or a local write.
- **A tap that opens the app** arrives in `_onMessageOpened`, also for a cold
  start (`getInitialMessage`).
- **Topics** — `subscribeToTopic('news')` / `unsubscribeFromTopic`.

The console and platform side — the APNs key, the Push Notifications
capability, `Runner.entitlements` — is `docs/FIREBASE_SETUP.md`. Enable the
capability on the App ID **before** generating the provisioning profile, or
codesigning fails on a missing `aps-environment` entitlement.

When a notification tap opens the app, route to the screen by its path
(`docs/ROUTING.md`), so it works from a cold start.
'''
        : '';
    return '''
${header('Notifications', 'How the app notifies the user.')}$local$push
## Testing them

- Android: a notification needs the POST_NOTIFICATIONS permission from
  Android 13; deny it once and the app has to send the user to the settings.
- iOS: push does not reach the simulator from FCM — use a device. Local
  notifications work on both.
''';
  }

  /// `docs/SERVICES.md` — every service the project has, one row each.
  static String services(DocsOptions o) {
    final rows = <String>[
      '| `TokenStorage` | `core/security/secure_storage.dart` | The auth tokens, in the Keychain / Keystore. Never put a token anywhere else. |',
      '| `ValidationService` | `core/security/validation_service.dart` | Checks a value against an `InputType` (email, phone, password…) and returns it cleaned up. `AppInput` calls it. |',
      '| `PermissionService` | `core/services/permission_service.dart` | A permission as granted, denied or **blocked** — blocked being the one only the system settings can grant (`openSettings()`). |',
      if (o.withLocalCache || o.withOfflineGate || o.withSync || o.withDio)
        '| `ConnectivityService` | `core/services/connectivity_service.dart` | Online / offline as a stream${o.withDio ? ', checked against the API' : ''}, and `onReconnect` for what runs when the connection is back. |',
      if (o.withPreferences)
        '| `PreferencesService` | `core/services/preferences_service.dart` | Small non-secret settings (shared_preferences), loaded before `runApp` so they read synchronously. |',
      if (o.withThemeMode)
        '| Theme mode | `core/services/theme_mode_service.dart` | The saved light / dark / system choice (`docs/THEME.md`). |',
      if (o.withAnyLocalization)
        '| Language | `core/services/language_service.dart` | The selected locale (`docs/LOCALIZATION.md`). |',
      if (o.withMediaService)
        '| `MediaService` | `core/services/media_service.dart` | `pickImage`, `pickMultiImage`, `pickVideo`, `pickFiles`, with the permission handling around them. |',
      if (o.withUrlService)
        '| `UrlLauncherService` | `core/services/url_launcher_service.dart` | Opens a link externally or in an in-app web view. |',
      if (o.withDebouncer)
        '| `DebouncerService` | `core/services/debouncer_service.dart` | `run(action)` fires only once input pauses — a search field, a slider. Dispose it with the screen. |',
      if (o.withAppLifecycle)
        '| `AppLifecycleService` | `core/services/app_lifecycle_service.dart` | Foreground / background as streams. `resumed` carries how long the app was away, for refreshing stale data on return. |',
      if (o.withBiometric)
        '| `BiometricService` | `core/security/biometric_service.dart` | Face ID / fingerprint: `canAuthenticate()`, then `authenticate()`. |',
      if (o.withNotifications)
        '| `NotificationService` | `core/services/notifications_service.dart` | Local notifications (`docs/NOTIFICATIONS.md`). |',
      if (o.withFirebaseNotifications)
        '| `FirebaseNotificationsService` | `core/services/firebase_notifications_service.dart` | Push notifications (`docs/NOTIFICATIONS.md`). |',
    ];
    final gates = [
      if (o.withOfflineGate)
        '- **Offline screen** — `OfflineGate` (`shared/widgets/offline_gate.dart`) '
            'covers the app while there is no connection and keeps it mounted '
            'underneath, so nothing reloads when it comes back. Screens never '
            'check the connection to show one themselves.',
      if (o.withMaintenanceGate)
        '- **Maintenance gate** — `MaintenanceGate` replaces the app with a '
            'maintenance screen while the backend says so${o.withDio
                ? ' (`ApiConstants.configMaintenance`)'
                : o.withFirestore
                ? ' (a Firestore document, live)'
                : ''}. '
            'The message comes from the backend, so whoever turns the app off '
            'can say why without a release.',
      if (o.withUpdateGate)
        '- **Update gate** — `UpdateGate` compares the installed version with '
            'the backend\'s minimum, at launch and on every return to the '
            'foreground, and points at the store when it is too old.',
    ];
    return '''
${header('Services', 'The shared services under `lib/core/` and when to use each.')}
A service is one job that several features need — storage, permissions, the
connection. It holds no screen state, lives under `lib/core/`, and is
registered in `lib/config/di/core_module.dart`, so any repository or state
holder reads it with `getIt<T>()`. ${o.bloc ? 'A bloc gets it through its constructor, from `presentation_module.dart`.' : 'A notifier reads it in `build()`.'}

| Service | File | What it is for |
|---|---|---|
${rows.join('\n')}
${gates.isEmpty ? '' : '\n## App-wide gates\n\nWrapped around the app in `main.dart`:\n\n${gates.join('\n')}\n'}
## Adding a service

1. Write it in `lib/core/services/` (or `core/security/` for anything
   holding a secret). No Flutter widgets, no feature imports.
2. Register it in `core_module.dart` with `registerLazySingleton`.
3. Read it with `getIt<YourService>()`. A test replaces it with a mock in
   the locator.

Logging goes through `AppLogger` (`core/utils/app_logger.dart`)${o.withCrashlytics ? ', which also\nforwards errors to Crashlytics' : ''}; never `print`.
''';
  }

  /// `docs/TESTING.md` — what is tested, and how to generate the bulk of it.
  static String testing(DocsOptions o) {
    final holder = o.bloc ? 'bloc' : 'notifier';
    final unitExample = o.bloc
        ? '''
```dart
blocTest<OrdersBloc, OrdersState>(
  'loads the orders',
  build: () {
    when(() => repository.fetchAll()).thenAnswer((_) async => [order]);
    return OrdersBloc(repository);
  },
  act: (bloc) => bloc.add(const OrdersStarted()),
  expect: () => [
    isA<OrdersState>().having((s) => s.status, 'status', AppStatus.loading),
    isA<OrdersState>().having((s) => s.items, 'items', [order]),
  ],
);
```
'''
        : '''
```dart
test('loads the orders', () async {
  when(() => repository.fetchAll()).thenAnswer((_) async => [order]);
  getIt.registerSingleton<OrderRepository>(repository);

  final container = ProviderContainer();
  addTearDown(container.dispose);

  final state = await container.read(ordersNotifierProvider.future);
  expect(state.items, [order]);
});
```
''';
    return '''
${header('Testing', 'What is tested, and how to write and run the tests.')}
```bash
fvm flutter test                       # everything
fvm flutter test test/unit             # the fast ones
fvm flutter test --coverage            # writes coverage/lcov.info
```

## What to test

| Layer | Test | Mocks |
|---|---|---|
| The $holder | Every action: the loading state, the success state, the `AppException` path | the repository |
| The repository | The decisions it makes${o.withLocalCache ? ' — remote or cache, what it saves' : ''} | the datasources |
| A remote datasource | Integration: the real endpoint answers with what the model parses | nothing |
| A widget | What it draws for each state | the $holder's state |

`data/` imports no Flutter, so most of it runs as plain Dart tests. Mocks are
[mocktail](https://pub.dev/packages/mocktail): no code generation, a class is
mocked as readily as an interface.

## Generating them

Once a feature has real methods:

```bash
moarch create tests            # every feature
moarch create tests orders     # one feature
```

This reads the code and writes:

- a unit test per $holder under `test/unit/features/` — every dependency
  mocked, a success and an error test per ${o.bloc ? 'event' : 'method'};
- an integration test per GET endpoint a remote datasource calls, under
  `test/integration/features/`, against the real API (`BASE_URL` in `.env`).

Re-run it as the code grows. A generated file starts with a
`GENERATED BY moarch` line; delete that line and the generator leaves the file
to you.

## A unit test by hand
$unitExample${o.withLocalCache ? '''
## The database

Drift runs in memory in a test, so a local datasource is tested against the
real SQL:

```dart
final db = AppDatabase(NativeDatabase.memory());   // package:drift/native.dart
addTearDown(db.close);
```

`fvm dart run drift_dev make-migrations` also writes a test per schema
version under `test/drift/`, checking each migration step
(`docs/OFFLINE_FIRST.md`).
''' : ''}
${o.withWorkflows ? '''## In CI

The CI workflow (`.github/workflows/unified_workflow.yml`) runs
`test/unit/` on every push and pull request and fails the build on a
failure. The integration tests run after it, against the API in the
`BASE_URL` secret, and are allowed to fail (`continue-on-error`), since a
flaky backend should not block a merge. Remove that line once the API is
reliable enough to gate on.
''' : '''## In CI

There are no workflows in this project yet. When you add one, run
`test/unit/` as a gate and the integration tests separately, against a
reachable `BASE_URL`.
'''}''';
  }
}
