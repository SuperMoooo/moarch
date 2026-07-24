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

final rootNavigatorKey = GlobalKey<NavigatorState>();


final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home — replace me!')),
      ),
    ),
    GoRoute(
      path: AppRoutes.designView,
      builder: (_, _) => const DesignSystemView(),
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
 
    // Per-route redirect example (for the app-wide auth guard with a splash
    // screen — no login/home flash on startup — see the bottom of this file):
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
});

// ── Auth guard example (with splash — no wrong-screen flash) ─────────────────
// While AuthNotifier.build() restores the session, the auth state is still
// loading. If the router renders any real route during that window, the user
// sees login (or home) for a frame and is then bounced to the right screen.
// Fix: park the router on a splash route until auth resolves.
//
// 1. Uncomment `splash` and `login` in app_routes.dart.
//
// 2. Add the imports:
//    import '../../features/auth/presentation/notifiers/auth_notifier.dart';
//    import '../../shared/widgets/loadings/app_loading_data.dart';
//
// 3. Add the splash route to the routes list above:
//    GoRoute(
//      path: AppRoutes.splash,
//      builder: (_, _) => const AppLoadingData(),
//    ),
//
// 4. Update the GoRouter above:
//      initialLocation: AppRoutes.splash,
//      refreshListenable: GoRouterRefreshNotifier(ref),
//      redirect: (context, state) => _redirect(ref, state),
//
// class GoRouterRefreshNotifier extends ChangeNotifier {
//   GoRouterRefreshNotifier(Ref ref) {
//     ref.container.listen(authNotifierProvider, (previous, next) {
//       notifyListeners();
//     });
//   }
// }
//
// String? _redirect(Ref ref, GoRouterState state) {
//   final authAsync = ref.read(authNotifierProvider);
//   final onSplash = state.matchedLocation == AppRoutes.splash;
//
//   // Session restore still running: stay on splash so login/home never
//   // flash. When it completes, the refreshListenable re-runs this redirect.
//   if (authAsync.isLoading) return onSplash ? null : AppRoutes.splash;
//
//   final isAuthenticated = authAsync.value?.authenticated ?? false;
//
//   // Auth resolved: leave splash for the right destination.
//   if (onSplash) return isAuthenticated ? AppRoutes.home : AppRoutes.login;
//
//   final publicRoutes = {AppRoutes.login};
//   final onPublicRoute = publicRoutes.contains(state.matchedLocation);
//
//   if (!isAuthenticated && !onPublicRoute) return AppRoutes.login;
//   if (isAuthenticated && onPublicRoute) return AppRoutes.home;
//   return null;
// }

''';

  /// App routes
  static String appRoutes() => r'''
 
// ── Routes ────────────────────────────────────────────────────────────────────
 
abstract final class AppRoutes {
  static const home   = '/';
  // static const splash = '/splash';
  // static const login  = '/login';
  // static const detail = '/detail/:id';

  //-----Test------//
  static const designView   = '/design-system';
  //---------------//
}
 
''';

  /// Returns the generated firebaseProviders template.
  static String firebaseProviders({bool hasAuth = false, bool hasDb = false}) {
    final imports = [
      if (hasDb) "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (hasAuth) "import 'package:firebase_auth/firebase_auth.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
    ].join('\n');

    final providers = [
      if (hasAuth)
        'final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);',
      if (hasDb)
        'final firebaseDbProvider = Provider((ref) => FirebaseFirestore.instance);',
    ].join('\n\n');

    return '''
$imports

$providers
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
  static const String? _fontFamily = AppConstants.fontFamily;

  // Type scale wired to the AppConstants font-size tokens and the app font
  // family. Colors are left null on purpose so each style inherits the correct
  // on-surface color per brightness and stays legible on colored surfaces.
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: _fontFamily, fontSize: 57, height: 1.12, fontWeight: FontWeight.w400, letterSpacing: -0.25),
    displayMedium: TextStyle(fontFamily: _fontFamily, fontSize: 45, height: 1.16, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(fontFamily: _fontFamily, fontSize: 36, height: 1.22, fontWeight: FontWeight.w400),
    headlineLarge: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize28 + 4, height: 1.25, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize28, height: 1.29, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontFamily: _fontFamily, fontSize: 24, height: 1.33, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize22, height: 1.27, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize16, height: 1.50, fontWeight: FontWeight.w600, letterSpacing: 0.15),
    titleSmall: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize14, height: 1.43, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize16, height: 1.50, fontWeight: FontWeight.w400, letterSpacing: 0.5),
    bodyMedium: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize14, height: 1.43, fontWeight: FontWeight.w400, letterSpacing: 0.25),
    bodySmall: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize12, height: 1.33, fontWeight: FontWeight.w400, letterSpacing: 0.4),
    labelLarge: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize14, height: 1.43, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize12, height: 1.33, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    labelSmall: TextStyle(fontFamily: _fontFamily, fontSize: AppConstants.fontSize11, height: 1.45, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    textTheme: _textTheme,
    fontFamily: AppConstants.fontFamily,
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
      outlineVariant: AppConstants.outline.withValues(alpha: 0.3),
    ),

    scaffoldBackgroundColor: AppConstants.surface,

    iconTheme: const IconThemeData(
      color: AppConstants.outline,
      size: AppConstants.iconSmall,
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(
        AppConstants.surfaceContainerLowest,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(
        AppConstants.surfaceContainerLowest,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppConstants.space12,
          vertical: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        _textTheme.bodyLarge?.copyWith(color: AppConstants.onSurface),
      ),
      hintStyle: WidgetStatePropertyAll(
        _textTheme.bodyLarge?.copyWith(
          color: AppConstants.onSurface.withValues(alpha: 0.35),
        ),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppConstants.primary,
      foregroundColor: AppConstants.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),

    cardTheme: CardThemeData(
      color: AppConstants.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: AppConstants.primary,
    ),

    tabBarTheme: TabBarThemeData(
      indicatorColor: AppConstants.accentActive,
      tabAlignment: TabAlignment.fill,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorAnimation: TabIndicatorAnimation.elastic,
      labelColor: AppConstants.onSurface,
      labelStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      unselectedLabelColor: AppConstants.onSurface.withValues(alpha: 0.5),
      unselectedLabelStyle: _textTheme.labelLarge,
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
        borderSide: const BorderSide(color: AppConstants.outline, width: 0.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppConstants.borderRadius12,
        borderSide: const BorderSide(color: AppConstants.error, width: 0.5),
      ),
      prefixIconColor: AppConstants.primary,
      suffixIconColor: AppConstants.primary,
      contentPadding: const EdgeInsets.symmetric(
        vertical: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
        horizontal: AppConstants.space12,
      ),

      hintStyle: _textTheme.bodyLarge?.copyWith(
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
      checkColor: const WidgetStatePropertyAll(AppConstants.surface),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius4),
      side: const BorderSide(color: AppConstants.primary, width: 1),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppConstants.primary,
      selectionColor: AppConstants.primary.withValues(alpha: 0.25),
      selectionHandleColor: AppConstants.primary,
    ),

    dividerTheme: const DividerThemeData(color: Colors.transparent),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
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

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppConstants.surface
            : AppConstants.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppConstants.primary
            : AppConstants.surfaceContainerHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppConstants.primary
            : AppConstants.outline,
      ),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: AppConstants.primary,
      inactiveTrackColor: AppConstants.primary.withValues(alpha: 0.15),
      thumbColor: AppConstants.primary,
      overlayColor: AppConstants.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppConstants.primary,
      linearMinHeight: 6,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppConstants.onSurface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppConstants.space16,
        vertical: AppConstants.space4,
      ),
    ),

    badgeTheme: const BadgeThemeData(
      backgroundColor: AppConstants.error,
      textColor: AppConstants.surface,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppConstants.primary
              : AppConstants.surfaceContainerLowest,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppConstants.surface
              : AppConstants.onSurface,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppConstants.borderRadius8),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppConstants.surfaceContainerHighest,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: AppConstants.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      insetPadding: AppConstants.padding16,
      elevation: 0,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: _textTheme,
    fontFamily: AppConstants.fontFamily,
    colorScheme: ColorScheme.dark(
      primary: AppConstants.primaryDark,
      onPrimary: AppConstants.surfaceDark,

      secondary: AppConstants.secondaryDark,
      onSecondary: AppConstants.surfaceDark,

      tertiary: AppConstants.tertiaryDark,
      onTertiary: AppConstants.surfaceDark,

      surface: AppConstants.surfaceDark,
      onSurface: AppConstants.onSurfaceDark,
      surfaceContainer: AppConstants.surfaceContainerLowDark,
      surfaceContainerLow: AppConstants.surfaceContainerLowDark,
      surfaceContainerLowest: AppConstants.surfaceContainerLowestDark,
      surfaceContainerHigh: AppConstants.surfaceContainerHighestDark,
      surfaceContainerHighest: AppConstants.surfaceContainerHighestDark,
      error: AppConstants.errorDark,
      onError: AppConstants.surfaceDark,

      outline: AppConstants.outlineDark.withValues(alpha: 0.3),
      outlineVariant: AppConstants.outlineDark.withValues(alpha: 0.3),
    ),

    scaffoldBackgroundColor: AppConstants.surfaceDark,

    iconTheme: const IconThemeData(
      color: AppConstants.outlineDark,
      size: AppConstants.iconSmall,
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(
        AppConstants.surfaceContainerLowestDark,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(
        AppConstants.surfaceContainerLowestDark,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppConstants.space12,
          vertical: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        _textTheme.bodyLarge?.copyWith(color: AppConstants.onSurfaceDark),
      ),
      hintStyle: WidgetStatePropertyAll(
        _textTheme.bodyLarge?.copyWith(
          color: AppConstants.onSurfaceDark.withValues(alpha: 0.35),
        ),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppConstants.surfaceContainerLowDark,
      foregroundColor: AppConstants.onSurfaceDark,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),

    cardTheme: CardThemeData(
      color: AppConstants.surfaceContainerLowDark,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: AppConstants.primaryDark,
    ),

    tabBarTheme: TabBarThemeData(
      indicatorColor: AppConstants.accentActive,
      tabAlignment: TabAlignment.fill,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorAnimation: TabIndicatorAnimation.elastic,
      labelColor: AppConstants.onSurfaceDark,
      labelStyle: _textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      unselectedLabelColor: AppConstants.onSurfaceDark.withValues(alpha: 0.5),
      unselectedLabelStyle: _textTheme.labelLarge,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppConstants.surfaceContainerLowestDark,
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
        borderSide: const BorderSide(
          color: AppConstants.outlineDark,
          width: 0.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppConstants.borderRadius12,
        borderSide: const BorderSide(color: AppConstants.errorDark, width: 0.5),
      ),
      prefixIconColor: AppConstants.primaryDark,
      suffixIconColor: AppConstants.primaryDark,
      contentPadding: const EdgeInsets.symmetric(
        vertical: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
        horizontal: AppConstants.space12,
      ),

      hintStyle: _textTheme.bodyLarge?.copyWith(
        color: AppConstants.onSurfaceDark.withValues(alpha: 0.35),
      ),
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppConstants.surfaceDark,
      headerBackgroundColor: AppConstants.primaryDark,
      headerForegroundColor: AppConstants.surfaceDark,
      rangePickerBackgroundColor: AppConstants.surfaceDark,
      rangePickerHeaderBackgroundColor: AppConstants.primaryDark,
      rangePickerHeaderForegroundColor: AppConstants.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),

    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppConstants.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      dialBackgroundColor: AppConstants.surfaceContainerLowestDark,
      dialHandColor: AppConstants.primaryDark,
      hourMinuteColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppConstants.primaryDark; // Color when selected
        }
        return AppConstants.secondaryDark.withValues(
          alpha: 0.2,
        ); // Color when not selected
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return AppConstants.primaryDark;
        }
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(AppConstants.surfaceDark),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius4),
      side: const BorderSide(color: AppConstants.primaryDark, width: 1),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppConstants.primaryDark,
      selectionColor: AppConstants.primaryDark.withValues(alpha: 0.25),
      selectionHandleColor: AppConstants.primaryDark,
    ),

    dividerTheme: const DividerThemeData(color: Colors.transparent),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppConstants.primaryDark,
      foregroundColor: AppConstants.surfaceDark,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppConstants.surfaceContainerLowDark,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppConstants.surfaceContainerLowDark,
      selectedColor: AppConstants.primaryDark.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppConstants.surfaceDark
            : AppConstants.outlineDark,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppConstants.primaryDark
            : AppConstants.surfaceContainerHighestDark,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppConstants.primaryDark
            : AppConstants.outlineDark,
      ),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: AppConstants.primaryDark,
      inactiveTrackColor: AppConstants.primaryDark.withValues(alpha: 0.15),
      thumbColor: AppConstants.primaryDark,
      overlayColor: AppConstants.primaryDark.withValues(alpha: 0.12),
      trackHeight: 4,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppConstants.primaryDark,
      linearMinHeight: 6,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppConstants.onSurfaceDark,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppConstants.space16,
        vertical: AppConstants.space4,
      ),
    ),

    badgeTheme: const BadgeThemeData(
      backgroundColor: AppConstants.errorDark,
      textColor: AppConstants.surfaceDark,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppConstants.primaryDark
              : AppConstants.surfaceContainerLowestDark,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppConstants.surfaceDark
              : AppConstants.onSurfaceDark,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppConstants.borderRadius8),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppConstants.surfaceContainerHighestDark,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: AppConstants.onSurfaceDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      insetPadding: AppConstants.padding16,
      elevation: 0,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}

''';
}
