/// Generates project configuration file templates.
class ConfigTemplates {
  ConfigTemplates._();

  /// Returns the generated appRouter template.
  static String appRouter() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/design_system_view.dart';
import './app_routes.dart';
 
// ── Navigator key ─────────────────────────────────────────────────────────────
// Use this to navigate from anywhere without BuildContext:
//   ref.read(routerProvider).go(AppRoutes.home)
//   ref.read(routerProvider).push(AppRoutes.detail)
 
final routerProvider = Provider<GoRouter>((ref) => _router);
 
final rootNavigatorKey = GlobalKey<NavigatorState>();
 
 
// ── Router ────────────────────────────────────────────────────────────────────
 
final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: true,
  redirect: _redirect,
  refreshListenable: <authNotifier>,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home — replace me!')),
      ),
    ),
    GoRoute(
      path: AppRoutes.designView,
      builder: (_, __) => const DesignSystemView(),
    )
    
 
    // Example with path parameter:
    // GoRoute(
    //   path: AppRoutes.detail,
    //   builder: (context, state) {
    //     final id = state.pathParameters['id']!;
    //     return DetailView(id: id);
    //   },
    // ),

    //   GoRoute(
    //   path: '/recipe/detail',
    //    builder: (context, state) {
    //     final recipe = state.extra as RecipeEntity;
    //      return RecipeDetailView(recipe: recipe);
    //    },
    //    ),

    // navegar — passa a entidade directamente
    //   ref.read(routerProvider).go(
    //      '/recipe/detail',
    //      extra: recipe, // qualquer objeto
    //   );
 
    // Example with redirect (e.g. auth guard):
    // GoRoute(
    //   path: AppRoutes.home,
    //   redirect: (context, state) {
    //     final isLoggedIn = ...; // read from your auth notifier
    //     if (!isLoggedIn) return AppRoutes.login;
    //     return null; // null = no redirect
    //   },
    //   builder: (context, state) => const HomeView(),
    // ),
  ],
);


Future<String?> _redirect(BuildContext context, GoRouterState state) async {
  // if the user is not logged in, they need to login
  final loggedIn = <authNotifier>.isAuthenticated;
  final loggingIn = state.matchedLocation == Routes.login;
  if (!loggedIn) {
    return Routes.login;
  }

  // if the user is logged in but still on the login page, send them to
  // the home page
  if (loggingIn) {
    return Routes.home;
  }

  // no need to redirect at all
  return null;
}
''';

  /// App routes
  static String appRoutes() => r'''
 
// ── Routes ────────────────────────────────────────────────────────────────────
 
abstract final class AppRoutes {
  static const home   = '/';
  // static const login  = '/login';
  // static const detail = '/detail/:id';

  //-----Test------//
  static const designView   = '/design-system';
  //---------------//
}
 
''';

  /// Returns the generated firebaseProviders template.
  static String firebaseProviders({bool hasAuth = false, bool hasDb = false}) {
    final authImport = hasAuth
        ? '''
  import 'package:firebase_auth/firebase_auth.dart';'''
        : '';

    final dbImport = hasDb
        ? '''
  import 'package:cloud_firestore/cloud_firestore.dart';'''
        : '';

    final authProvider = hasAuth
        ? '''
      final firebaseAuthProvider = Provider((ref) {
          return FirebaseAuth.instance;
      });
      '''
        : '';

    final dbProvider = hasDb
        ? '''
       final firebaseDbProvider = Provider((ref) {
    return FirebaseFirestore.instance;
  });
      '''
        : '';

    return '''
$authImport
$dbImport
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  $authProvider

 $dbProvider

  ''';
  }

  /// Returns the generated appEnv template.
  static String appEnv() => r'''
import 'package:envied/envied.dart';

// use
//dart run build_runner build --delete-conflicting-outputs
// to generate the app_env.g.dart file.
// remember to have BASE_URL in the env file

part 'app_env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract final class AppEnv {
  @EnviedField(varName: 'BASE_URL', obfuscate: true)
  static final String baseUrl = _AppEnv.baseUrl;

  // Copy this pattern for additional environment values.
  // @EnviedField(varName: 'SOME_KEY', obfuscate: true)
  // static const String someKey = _AppEnv.someKey;
}

// Code generation commands (commented in generated code):
// fvm flutter pub add envied
// fvm flutter pub add --dev build_runner envied_generator
// dart run build_runner build --delete-conflicting-outputs
// Access values in app: final baseUrl = AppEnv.baseUrl;

''';

  /// Returns the generated appTheme template.
  static String appTheme() => r'''
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppConstants.primary,
      onPrimary: AppConstants.surface,

      secondary: AppConstants.secondary,
      onSecondary: AppConstants.surface,

      tertiary: AppConstants.tertiary,
      onTertiary: AppConstants.surface,

      surface: AppConstants.surface,
      onSurface: AppConstants.onSurface, 
      surfaceContainer: AppConstants.surfaceContainerLow,
      surfaceContainerLow: AppConstants.surfaceContainerLow,
      surfaceContainerLowest: AppConstants.surfaceContainerLowest,
      surfaceContainerHigh: AppConstants.surfaceContainerHighest,
      surfaceContainerHighest: AppConstants.surfaceContainerHighest,
      error: AppConstants.error,
      onError: AppConstants.surface,

      outline: AppConstants.outline.withValues(alpha: 0.3), 
      outlineVariant: AppConstants.outline.withValues(
        alpha: 0.3,
      ), 
    ),

    scaffoldBackgroundColor: AppConstants.surface,

    iconTheme: IconThemeData(
      color: AppConstants.outline,
      size: AppConstants.iconSmall,
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        AppConstants.surfaceContainerLowest,
      ),
      surfaceTintColor: WidgetStatePropertyAll(
        AppConstants.surfaceContainerLowest,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      ),
      side: WidgetStatePropertyAll(BorderSide.none),
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(Colors.transparent),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppConstants.space12,
          vertical: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: AppConstants.fontSize16,
          color: AppConstants.onSurface,
        ),
      ),
      hintStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: AppConstants.fontSize16,
          color: AppConstants.onSurface.withValues(alpha: 0.35),
        ),
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppConstants.primary,
      foregroundColor: AppConstants.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),

    cardTheme: CardThemeData(
      color: AppConstants.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: AppConstants.primary,
    ),

    tabBarTheme: TabBarThemeData(
      indicatorColor: AppConstants.accentActive,
      tabAlignment: TabAlignment.fill,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorAnimation: TabIndicatorAnimation.elastic,
      labelStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelColor: Colors.grey,
      unselectedLabelStyle: TextStyle(
        color: Colors.blueGrey,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppConstants.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: AppConstants.borderRadius12,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppConstants.borderRadius12,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppConstants.borderRadius12,
        borderSide: BorderSide(color: AppConstants.outline, width: 0.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppConstants.borderRadius12,
        borderSide: BorderSide(color: AppConstants.error, width: 0.5),
      ),
      prefixIconColor: AppConstants.primary,
      suffixIconColor: AppConstants.primary,
      contentPadding: EdgeInsets.symmetric(
        vertical: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
        horizontal: AppConstants.space12,
      ),

      hintStyle: TextStyle(
        fontSize: AppConstants.fontSize16,
        color: AppConstants.onSurface.withValues(alpha: 0.35),
      ),
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppConstants.surface,
      headerBackgroundColor: AppConstants.primary,
      headerForegroundColor: AppConstants.surface,
      rangePickerBackgroundColor: AppConstants.surface,
      rangePickerHeaderBackgroundColor: AppConstants.primary,
      rangePickerHeaderForegroundColor: AppConstants.surface,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),

    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppConstants.surface,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      dialBackgroundColor: AppConstants.surfaceContainerLowest,
      dialHandColor: AppConstants.primary,
      hourMinuteColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppConstants.primary; // Color when selected
        }
        return AppConstants.secondary.withValues(
          alpha: 0.2,
        ); // Color when not selected
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return AppConstants.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(AppConstants.surface),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius4),
      side: BorderSide(color: AppConstants.primary, width: 1),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppConstants.primary,
      selectionColor: AppConstants.primary.withValues(alpha: 0.25),
      selectionHandleColor: AppConstants.primary,
    ),

    dividerTheme: DividerThemeData(color: Colors.transparent),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppConstants.primary,
      foregroundColor: Colors.white,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppConstants.surface,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppConstants.surfaceContainerLow,
      selectedColor: AppConstants.primary.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        // TODO: add your dark theme
      );
}
''';
}
