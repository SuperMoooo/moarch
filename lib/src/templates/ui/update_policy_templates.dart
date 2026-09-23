/// The stack-neutral half of the update gate: the policy the backend sends,
/// the version comparison, and the screen shown in place of the app.
///
/// `templates/riverpod/update_gate_templates.dart` and
/// `templates/bloc/update_gate_templates.dart` wrap these in a provider or a
/// cubit. Nothing here holds state, so unlike the maintenance gate's status
/// class it is written once rather than kept in step twice.
abstract final class UpdatePolicyTemplates {
  /// `UpdatePolicy`, and the `compareVersions` it runs on.
  static const policy = r'''

/// What the backend says about the oldest version it still supports.
///
/// Shared keys apply everywhere; a platform object overrides them for that
/// platform, since a store review can put one platform a release behind:
///
/// ```json
/// {
///   "min_version": "2.4.0",
///   "title": "Time to update",
///   "message": "This version is no longer supported.",
///   "android": { "store_url": "https://play.google.com/store/apps/details?id=com.example.app" },
///   "ios": { "min_version": "2.3.0", "store_url": "https://apps.apple.com/app/id0000000000" }
/// }
/// ```
///
/// The copy lives on the backend for the same reason the maintenance message
/// does: whoever raises the floor can say why without waiting for a release.
@immutable
class UpdatePolicy {
  const UpdatePolicy({
    this.minVersion,
    this.storeUrl,
    this.title,
    this.message,
  });

  /// No minimum — every installed version may run. Also what an unreadable
  /// policy resolves to: see [UpdateGate] on why this fails open.
  const UpdatePolicy.none()
      : minVersion = null,
        storeUrl = null,
        title = null,
        message = null;

  /// Reads the policy for the platform the app is running on, defaulting
  /// every field. Anything unparseable reads as "no minimum", so a malformed
  /// payload cannot lock anyone out.
  factory UpdatePolicy.fromMap(Map<String, dynamic> map) {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
      _ => 'android',
    };
    final specific = map[platform];
    final merged = <String, dynamic>{
      ...map,
      if (specific is Map) ...specific.cast<String, dynamic>(),
    };
    return UpdatePolicy(
      minVersion: _text(merged['min_version']),
      storeUrl: _text(merged['store_url']),
      title: _text(merged['title']),
      message: _text(merged['message']),
    );
  }

  /// The value as text, or null if it is missing, not a string, or blank.
  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The oldest version allowed to run, e.g. `2.4.0`, or null for none.
  final String? minVersion;

  /// Where the update button sends the user, or null to show no button.
  final String? storeUrl;

  /// Heading on the blocking screen, or null for the default.
  final String? title;

  /// Body text on the blocking screen, or null for the default.
  final String? message;

  /// Whether [installed] is older than [minVersion].
  ///
  /// False when either side is not a version — the same fail-open rule: a
  /// typo in the backend must not block every user.
  bool requiresUpdate(String installed) {
    final minimum = minVersion;
    if (minimum == null) return false;
    final order = compareVersions(installed, minimum);
    return order != null && order < 0;
  }
}

/// Orders two `major.minor.patch` versions: negative when [a] is older, zero
/// when equal, positive when newer — or null when either is not a version.
///
/// A build number (`+42`) or pre-release tag (`-beta`) is ignored, and a
/// missing part counts as zero, so `2.4` equals `2.4.0`.
int? compareVersions(String a, String b) {
  List<int>? parse(String version) {
    final core = version.trim().split(RegExp('[+-]')).first;
    final parts = <int>[];
    for (final part in core.split('.')) {
      final number = int.tryParse(part);
      if (number == null) return null;
      parts.add(number);
    }
    return parts;
  }

  final left = parse(a);
  final right = parse(b);
  if (left == null || right == null) return null;

  for (var i = 0; i < left.length || i < right.length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}
''';

  /// `UpdateRequiredView` — the screen that replaces the app.
  static const view = r'''

/// The screen shown in place of the app while it is below the minimum.
///
/// Public so a route of your own can reuse it. There is no way past it but
/// the store: no back button to pop, no route under it to reach — the gate
/// has replaced the Navigator — which is the point of a minimum version.
class UpdateRequiredView extends StatelessWidget {
  /// Renders [policy] full-screen.
  const UpdateRequiredView({required this.policy, super.key});

  /// The policy that closed the gate, for its copy and store link.
  final UpdatePolicy policy;

  Future<void> _openStore() async {
    final uri = Uri.tryParse(policy.storeUrl ?? '');
    if (uri == null) return;
    // Out of the app: the store has to be in front for the update to start.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppConstants.padding24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_outlined,
                  size: AppConstants.iconLarge * 2,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppConstants.space24),
                Text(
                  policy.title ?? 'Update required',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.space8),
                Text(
                  policy.message ??
                      'This version of the app is no longer supported. '
                          'Update it to keep going.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (policy.storeUrl != null) ...[
                  const SizedBox(height: AppConstants.space32),
                  FilledButton(
                    onPressed: _openStore,
                    child: const Text('Update'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
''';
}
