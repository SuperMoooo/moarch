import '../templates/core/sync_templates.dart';
import 'manifest_utils.dart';
import 'plist_utils.dart';
import 'scaffold_catalog.dart';

/// What one generated service needs declared in `AndroidManifest.xml` and
/// `Info.plist` before it can work.
///
/// Neither platform fails the build over a missing declaration — the call
/// just fails at runtime: a permission request comes back denied without
/// asking, a scheduled notification throws, `canLaunchUrl` says no. So
/// `init` declares them with the service, and `doctor` checks a project for
/// them off the same table.
class PlatformRequirement {
  /// Creates a requirement.
  const PlatformRequirement({
    required this.service,
    this.permissions = const [],
    this.maxSdkVersions = const {},
    this.applicationChild,
    this.applicationMarker,
    this.queryIntents,
    this.queriesMarker,
    this.usageDescriptions = const {},
    this.plistArrays = const {},
  });

  /// What needs it, as `doctor` names it.
  final String service;

  /// Android `<uses-permission>` names.
  final List<String> permissions;

  /// Permissions from [permissions] declared only up to an API level.
  final Map<String, int> maxSdkVersions;

  /// XML that goes inside `<application>` (receivers), and the string that
  /// says it is already there.
  final String? applicationChild;

  /// See [applicationChild].
  final String? applicationMarker;

  /// `<intent>` elements for `<queries>`, and the string that says they are
  /// already there.
  final String? queryIntents;

  /// See [queryIntents].
  final String? queriesMarker;

  /// iOS `Info.plist` usage descriptions, by key.
  final Map<String, String> usageDescriptions;

  /// iOS `Info.plist` array values, by key. Added to an existing array rather
  /// than replacing it: `UIBackgroundModes` is shared between services.
  final Map<String, List<String>> plistArrays;

  /// Dio's calls. `flutter create` declares `INTERNET` only in the debug and
  /// profile manifests, so a release build without it cannot reach the API.
  static const internet = PlatformRequirement(
    service: 'Dio',
    permissions: ['android.permission.INTERNET'],
  );

  /// `MediaService`, which asks for `Permission.camera` and
  /// `Permission.photos` through permission_handler — undeclared, both come
  /// back permanently denied without a prompt.
  static const media = PlatformRequirement(
    service: 'MediaService',
    permissions: [
      'android.permission.CAMERA',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_EXTERNAL_STORAGE',
    ],
    maxSdkVersions: {'android.permission.READ_EXTERNAL_STORAGE': 32},
    usageDescriptions: {
      'NSCameraUsageDescription':
          'This app uses the camera to take photos and record videos.',
      'NSPhotoLibraryUsageDescription':
          'This app accesses your photo library so you can pick images.',
      'NSMicrophoneUsageDescription':
          'This app uses the microphone when recording videos.',
    },
  );

  /// `NotificationsService`: the Android 13 permission prompt, and the exact
  /// alarms and receivers its scheduled notifications run on — including
  /// rescheduling them after a reboot or an update.
  static const localNotifications = PlatformRequirement(
    service: 'NotificationsService',
    permissions: [
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.SCHEDULE_EXACT_ALARM',
    ],
    applicationMarker: 'ScheduledNotificationReceiver',
    applicationChild: '''
        <!-- flutter_local_notifications: scheduled notifications, their
             rescheduling after a reboot, and action buttons. -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />''',
  );

  /// FCM: the Android 13 prompt `requestPermission()` shows.
  static const pushNotifications = PlatformRequirement(
    service: 'FirebaseNotificationsService',
    permissions: ['android.permission.POST_NOTIFICATIONS'],
  );

  /// `UrlLauncherService`: Android 11 hides other apps from `canLaunchUrl`
  /// unless the intents are declared — the counterpart of iOS's
  /// `LSApplicationQueriesSchemes`, which `init` sets.
  static const urlLauncher = PlatformRequirement(
    service: 'UrlLauncherService',
    queriesMarker: 'android:scheme="mailto"',
    queryIntents: '''
        <!-- url_launcher: the apps canLaunchUrl may ask about. -->
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO" />
            <data android:scheme="mailto" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO" />
            <data android:scheme="sms" />
        </intent>''',
  );

  /// `BiometricService` (local_auth). Its MainActivity change is separate —
  /// Kotlin, not the manifest.
  static const biometric = PlatformRequirement(
    service: 'BiometricService',
    permissions: ['android.permission.USE_BIOMETRIC'],
    usageDescriptions: {
      'NSFaceIDUsageDescription':
          'This app uses Face ID to verify your identity.',
    },
  );

  /// The background sync task: an iOS background app refresh, which only
  /// runs for an identifier `Info.plist` permits. Android's WorkManager needs
  /// no declaration.
  static const backgroundSync = PlatformRequirement(
    service: 'Background sync',
    plistArrays: {
      'UIBackgroundModes': ['fetch'],
      'BGTaskSchedulerPermittedIdentifiers': [SyncTemplates.taskId],
    },
  );

  /// The requirements of the services [context] has on disk.
  static List<PlatformRequirement> forProject(ScaffoldContext context) => [
    if (context.hasDio) internet,
    if (context.hasFile('lib/core/services/media_service.dart')) media,
    if (context.hasNotifications) localNotifications,
    if (context.hasFirebaseNotifications) pushNotifications,
    if (context.hasFile('lib/core/services/url_launcher_service.dart'))
      urlLauncher,
    if (context.hasBiometric) biometric,
    if (context.hasSync) backgroundSync,
  ];

  /// [manifest] with everything this declares on Android.
  String patchManifest(String manifest) {
    var out = ManifestUtils.ensurePermissions(
      manifest,
      permissions,
      maxSdkVersions: maxSdkVersions,
    );
    if (applicationChild != null) {
      out = ManifestUtils.ensureApplicationChild(
        out,
        block: applicationChild!,
        marker: applicationMarker!,
      );
    }
    if (queryIntents != null) {
      out = ManifestUtils.ensureQueries(
        out,
        intents: queryIntents!,
        marker: queriesMarker!,
      );
    }
    return out;
  }

  /// Whether [manifest] already declares everything this needs.
  bool isDeclaredIn(String manifest) => patchManifest(manifest) == manifest;

  /// [plist] with this requirement's usage descriptions and array values.
  String patchPlist(String plist) {
    var out = usageDescriptions.isEmpty
        ? plist
        : PlistUtils.ensureEntries(plist, usageDescriptions);
    for (final MapEntry(:key, :value) in plistArrays.entries) {
      out = PlistUtils.ensureArrayValues(out, key, value);
    }
    return out;
  }

  /// Whether [plist] already has every usage description this needs.
  bool isDescribedIn(String plist) => patchPlist(plist) == plist;
}
