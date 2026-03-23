class ConfigTemplates {
  ConfigTemplates._();

  static String appRouter() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
 
// ── Navigator key ─────────────────────────────────────────────────────────────
// Use this to navigate from anywhere without BuildContext:
//   ref.read(routerProvider).go(AppRoutes.home)
//   ref.read(routerProvider).push(AppRoutes.detail)
 
final routerProvider = Provider<GoRouter>((ref) => _router);
 
final _rootNavigatorKey = GlobalKey<NavigatorState>();
 
// ── Routes ────────────────────────────────────────────────────────────────────
 
abstract final class AppRoutes {
  static const home   = '/';
  // static const login  = '/login';
  // static const detail = '/detail/:id';
}
 
// ── Router ────────────────────────────────────────────────────────────────────
 
final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home — replace me!')),
      ),
    ),
 
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
''';

  static String appTheme() => r'''
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

abstract final class AppTheme {
 static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppConstants.primary,
      onPrimary: AppConstants.surface, 

      secondary: AppConstants.secondary,
      onSecondary: AppConstants.surface,

      tertiary: AppConstants.tertiary,
      onTertiary: AppConstants.surface,

      surface: AppConstants.surface,
      onSurface: AppConstants.onSurface, // near-black, never #000
      // Tonal container layers (no-line rule: depth via color shift)
      surfaceContainer: AppConstants.surfaceContainerLow,
      surfaceContainerLow: AppConstants.surfaceContainerLow,
      surfaceContainerLowest: AppConstants.surfaceContainerLowest,
      surfaceContainerHigh: AppConstants.surfaceContainerHighest,
      surfaceContainerHighest: AppConstants.surfaceContainerHighest,
      error: AppConstants.secondary,
      onError: AppConstants.surface,

      outline: AppConstants.outline.withValues(alpha: 0.3), // ~15% of 255
      outlineVariant: AppConstants.outline.withValues(alpha: 0.3), // ~15% of 255
    ),

    scaffoldBackgroundColor: AppConstants.surface,

    appBarTheme: AppBarTheme(
      backgroundColor: AppConstants.primary,
      foregroundColor: AppConstants.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
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
        borderSide: BorderSide(color: AppConstants.primary, width: 0.5),
      ),
      prefixIconColor: AppConstants.primary,
      suffixIconColor: AppConstants.primary,
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
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius12),
      side: BorderSide(color: AppConstants.primary, width: 1),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppConstants.primary,
      selectionColor: AppConstants.primary.withValues(alpha: 0.25),
      selectionHandleColor: AppConstants.primary,
    ),

    dividerTheme: DividerThemeData(
      color: Colors.transparent
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppConstants.secondary,
      foregroundColor: Colors.white,
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
