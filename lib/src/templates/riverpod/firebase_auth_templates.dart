/// Generates the auth feature scaffold backed by Firebase Auth — email /
/// password plus Google sign-in — instead of the REST client.
///
/// The layer names and provider names match [AuthTemplates] exactly, so the
/// router guard, the notifier and anything else reading `authNotifierProvider`
/// work the same whichever backend the project chose. What changes is what
/// sits behind the datasource: `FirebaseAuth` and `GoogleSignIn` rather than
/// Dio and `TokenStorage` — Firebase persists the session itself, so there
/// are no tokens for the app to store.
class FirebaseAuthTemplates {
  FirebaseAuthTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────

  /// Returns the generated auth user entity template.
  static String entity() => r'''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user_entity.freezed.dart';

/// The signed-in user as the app sees them.
///
/// Equality comes from freezed and covers every field. It used to be keyed on
/// `id` alone, which meant a session whose display name or photo had changed
/// compared equal to the one before it — and a state holder that drops an
/// equal state dropped the change with it.
@freezed
abstract class AuthUserEntity with _$AuthUserEntity {
  const factory AuthUserEntity({
    /// The Firebase Auth uid. Also the document id of the user's profile when
    /// the project stores one in Firestore.
    required String id,
    String? email,
    String? displayName,
    String? photoUrl,
    @Default(false) bool emailVerified,
  }) = _AuthUserEntity;
}
''';

  // ── Domain — Repository interface ───────────────────────────────────────────

  /// Returns the generated auth repository interface template.
  ///
  /// [withPushNotifications] adds the device-token contract the notifier calls
  /// on sign-in and when Firebase restores a session at start-up.
  static String repositoryInterface({bool withPushNotifications = false}) {
    final syncDeviceToken = withPushNotifications
        ? '''
  /// Reads this device's FCM token and saves it against the signed-in user,
  /// so a notification can be targeted at them. Safe to call repeatedly — the
  /// token only changes when the install does.
  Future<void> syncDeviceToken();

'''
        : '';

    return '''
import '../entities/auth_user_entity.dart';

abstract interface class AuthRepository {
  /// Emits the signed-in user, or null once they sign out.
  ///
  /// Firebase restores the persisted session asynchronously at start-up, so
  /// this is what says whether the app opened signed in — `currentUser` can
  /// still be null for a moment after launch.
  Stream<AuthUserEntity?> authStateChanges();

  /// True when a session was restored for this device.
  Future<bool> isLoggedIn();

  /// The signed-in user, or null.
  Future<AuthUserEntity?> currentUser();

  /// Signs in with email and password.
  Future<AuthUserEntity> login({
    required String email,
    required String password,
  });

  /// Creates the account, optionally setting a display name on it.
  Future<AuthUserEntity> register({
    required String email,
    required String password,
    String? displayName,
  });

  /// Google sign-in, exchanged for a Firebase session.
  ///
  /// Throws an [AppException] of type `cancelled` when the user dismisses the
  /// Google sheet — nothing failed, so there is nothing to report.
  Future<AuthUserEntity> signInWithGoogle();

  /// Sends the password reset email Firebase hosts.
  Future<void> sendPasswordResetEmail({required String email});

  /// Ends the session — Google's too, when that is how the user signed in.
  Future<void> logout();

  /// Deletes the account. Firebase requires a recent sign-in for this and
  /// reports `requires-recent-login` when the session is too old.
  Future<void> deleteAccount();

$syncDeviceToken  /// The signed-in user's uid.
  Future<String?> currentUserId();
}
''';
  }

  // ── Data — Model ────────────────────────────────────────────────────────────

  /// Returns the generated auth user model template.
  ///
  /// [withFirestore] adds the JSON mapping for the `users/{uid}` profile
  /// document — Firebase Auth holds the credentials, everything else about a
  /// user belongs in Firestore.
  static String model({bool withFirestore = false}) {
    // json_serializable only enters the picture when there is a profile
    // document to parse; without Firestore the model is freezed alone, and
    // asking for a `.g.dart` part nothing generates would fail the build.
    final jsonPart = withFirestore ? "part 'auth_user_model.g.dart';\n" : '';

    // The id is the profile document's name rather than one of its fields, so
    // it is kept out of the body — the datasource folds `doc.id` back in
    // before parsing.
    final idParam = withFirestore
        ? '    @JsonKey(includeToJson: false) required String id,'
        : '    required String id,';

    final firestoreMapping = withFirestore
        ? r'''

  /// The profile document at `users/{uid}`.
  ///
  /// Add the rest of your profile fields to the constructor above — a key that
  /// differs from the Dart name gets an `@JsonKey(name: 'created_at')`, and a
  /// DateTime an `@TimestampConverter()`.
  factory AuthUserModel.fromJson(Map<String, dynamic> json) =>
      _$AuthUserModelFromJson(json);
'''
        : '';

    return '''
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_user_entity.dart';

part 'auth_user_model.freezed.dart';
$jsonPart
/// The wire shape of a signed-in user.
///
/// It does not extend the entity — freezed generates the concrete class, so
/// there is no constructor to inherit. [toEntity] is what crosses the line
/// instead, and the repository calls it on the way out of `data/`.
@freezed
abstract class AuthUserModel with _\$AuthUserModel {
  /// Freezed needs a private constructor before a class may declare members
  /// of its own — [toEntity] below is one.
  const AuthUserModel._();

  const factory AuthUserModel({
$idParam
    String? email,
    String? displayName,
    String? photoUrl,
    @Default(false) bool emailVerified,
  }) = _AuthUserModel;

  /// The FirebaseAuth user as the rest of the app sees it.
  factory AuthUserModel.fromFirebaseUser(User user) => AuthUserModel(
        id: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
      );

  factory AuthUserModel.fromEntity(AuthUserEntity entity) => AuthUserModel(
        id: entity.id,
        email: entity.email,
        displayName: entity.displayName,
        photoUrl: entity.photoUrl,
        emailVerified: entity.emailVerified,
      );

  AuthUserEntity toEntity() => AuthUserEntity(
        id: id,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        emailVerified: emailVerified,
      );
$firestoreMapping}
''';
  }

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated auth remote datasource template.
  ///
  /// [withFirestore] adds the user-profile document calls, so the datasource
  /// holds `_firestore` alongside `_auth`.
  static String remoteDatasource({
    bool withFirestore = false,
    bool withPushNotifications = false,
  }) {
    final firestoreImport = withFirestore
        ? "import 'package:cloud_firestore/cloud_firestore.dart';\n"
        : '';

    final firestoreField = withFirestore
        ? r'''
  final FirebaseFirestore _firestore;

  /// Where the user profile documents live.
  static const String usersCollection = 'users';
'''
        : '';

    final firestoreCtorParam = withFirestore ? ', this._firestore' : '';

    final firestoreMethods = withFirestore
        ? r'''

  // ── Profile document ──────────────────────────────────────────────────────
  // Firebase Auth stores the credentials; anything else you know about a user
  // goes here. Lock it down in your Firestore rules to
  // `request.auth.uid == userId`.

  DocumentReference<Map<String, dynamic>> _profileRef(String id) =>
      _firestore.collection(usersCollection).doc(id);

  /// `merge: true` so signing in again never blanks fields the profile has
  /// but FirebaseAuth doesn't know about.
  Future<void> saveProfile(AuthUserModel user) {
    return safeFirebaseCall<void>(
      call: () => _profileRef(user.id).set(
        user.toJson(),
        SetOptions(merge: true),
      ),
    );
  }

  Future<AuthUserModel?> fetchProfile(String id) {
    return safeFirebaseCall<AuthUserModel?>(
      call: () async {
        final doc = await _profileRef(id).get();
        final data = doc.data();
        if (data == null) return null;
        // The id is the document's name, not a field of its data.
        return AuthUserModel.fromJson({...data, 'id': doc.id});
      },
    );
  }

  Future<void> deleteProfile(String id) {
    return safeFirebaseCall<void>(call: () => _profileRef(id).delete());
  }
'''
        : '';

    // Where a device token goes depends on what the project has: the profile
    // document when Firestore is in, otherwise wherever the developer keeps
    // their devices — Firebase Auth alone has nowhere to put it.
    final deviceTokenMethod = !withPushNotifications
        ? ''
        : withFirestore
            ? '''

  // ── Push notifications ────────────────────────────────────────────────────

  /// Registers this device's FCM token on the user's profile document, so a
  /// backend function can target them.
  ///
  /// `arrayUnion` keeps one entry per device and ignores a token that is
  /// already there, so calling this on every sign-in costs nothing. Clear the
  /// stale ones from the send side: FCM reports the tokens it rejected.
  Future<void> saveDeviceToken({
    required String userId,
    required String token,
  }) {
    return safeFirebaseCall<void>(
      call: () => _profileRef(userId).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      ),
    );
  }
'''
            : '''

  // ── Push notifications ────────────────────────────────────────────────────

  /// Registers this device's FCM token against the signed-in user.
  ///
  /// This project has no database for it, so nothing is stored yet — point
  /// this at wherever your devices live: an HTTPS callable, your own API, the
  /// Realtime Database.
  Future<void> saveDeviceToken({
    required String userId,
    required String token,
  }) async {
    // TODO: save userId + token.
  }
''';

    return '''
${firestoreImport}import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/safe_firebase_call.dart';
import '../models/auth_user_model.dart';

/// The **web** client id from Firebase console → Authentication → Sign-in
/// method → Google → Web SDK configuration.
///
/// Android and iOS normally read their client id from google-services.json /
/// GoogleService-Info.plist and this can stay null. Set it when sign-in comes
/// back without an ID token, or when you target web or desktop.
const String? kGoogleServerClientId = null;

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._auth, this._googleSignIn$firestoreCtorParam);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
$firestoreField
  bool _googleReady = false;

  /// Fires on sign-in, sign-out, token refresh and account deletion — and
  /// once at start-up with the session Firebase restored from disk.
  Stream<AuthUserModel?> authStateChanges() => _auth.authStateChanges().map(
        (user) => user == null ? null : AuthUserModel.fromFirebaseUser(user),
      );

  AuthUserModel? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AuthUserModel.fromFirebaseUser(user);
  }

  Future<AuthUserModel> login({
    required String email,
    required String password,
  }) {
    return safeFirebaseCall<AuthUserModel>(
      call: () async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return AuthUserModel.fromFirebaseUser(credential.user!);
      },
    );
  }

  Future<AuthUserModel> register({
    required String email,
    required String password,
    String? displayName,
  }) {
    return safeFirebaseCall<AuthUserModel>(
      call: () async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user!;
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
          // updateDisplayName does not touch the cached user object.
          await user.reload();
        }
        return AuthUserModel.fromFirebaseUser(_auth.currentUser ?? user);
      },
    );
  }

  /// Interactive Google sign-in, exchanged for a Firebase session.
  Future<AuthUserModel> signInWithGoogle() {
    return safeFirebaseCall<AuthUserModel>(
      call: () async {
        await _ensureGoogleInitialized();

        // google_sign_in has no interactive call on the web: render its own
        // button there (see the package's web documentation) and pass the
        // credential you get back to _auth.signInWithCredential.
        if (!_googleSignIn.supportsAuthenticate()) {
          throw AppException.fromError(
            'Google sign-in needs the platform button on this target',
            StackTrace.current,
          );
        }

        final GoogleSignInAccount account;
        try {
          account = await _googleSignIn.authenticate();
        } on GoogleSignInException catch (error) {
          if (error.code == GoogleSignInExceptionCode.canceled) {
            throw AppException.cancelled();
          }
          rethrow;
        }

        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw AppException.fromError(
            'Google returned no ID token — set kGoogleServerClientId',
            StackTrace.current,
          );
        }

        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final userCredential = await _auth.signInWithCredential(credential);
        return AuthUserModel.fromFirebaseUser(userCredential.user!);
      },
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return safeFirebaseCall<void>(
      call: () => _auth.sendPasswordResetEmail(email: email),
    );
  }

  Future<void> logout() {
    return safeFirebaseCall<void>(
      call: () async {
        // Harmless when the session did not come from Google, and required
        // when it did — otherwise the next sign-in reuses the same account
        // without asking.
        await _googleSignIn.signOut();
        await _auth.signOut();
      },
    );
  }

  Future<void> delete() {
    return safeFirebaseCall<void>(
      call: () async {
        final user = _auth.currentUser;
        if (user == null) return;

        final linkedToGoogle = user.providerData.any(
          (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID,
        );
        // Revokes the grant as well as the session, so deleting the account
        // really does undo the connection.
        if (linkedToGoogle) await _googleSignIn.disconnect();

        // Throws requires-recent-login when the session is old — the message
        // tells the user to sign in again.
        await user.delete();
      },
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    await _googleSignIn.initialize(serverClientId: kGoogleServerClientId);
    _googleReady = true;
  }
$firestoreMethods$deviceTokenMethod}
''';
  }

  // ── Data — Repository impl ──────────────────────────────────────────────────

  /// Returns the generated auth repository implementation template.
  ///
  /// [withPushNotifications] hands the FCM service to the repository, so a
  /// signed-in session can register the device.
  static String repositoryImpl({
    bool withFirestore = false,
    bool withPushNotifications = false,
  }) {
    final pushImports = withPushNotifications
        ? "import '../../../../core/errors/app_exception.dart';\n"
            "import '../../../../core/services/firebase_notifications_service.dart';\n"
            "import '../../../../core/utils/app_logger.dart';\n"
        : '';

    final pushCtorParam = withPushNotifications ? ', this._push' : '';

    final pushField = withPushNotifications
        ? '\n  final FirebaseNotificationsService _push;'
        : '';

    final syncDeviceToken = withPushNotifications
        ? '''

  @override
  Future<void> syncDeviceToken() async {
    final id = await currentUserId();
    if (id == null) return;

    final deviceToken = await _push.getDeviceToken();
    if (deviceToken == null) return;

    try {
      await _remote.saveDeviceToken(userId: id, token: deviceToken);
    } on AppException catch (e) {
      // Best effort: the session is valid either way, this device just goes
      // without push until the next sign-in or app start.
      appLogger.w('Device token not registered', error: e);
    }
  }
'''
        : '';

    final saveProfileOnRegister =
        withFirestore ? '\n    await _remote.saveProfile(user);' : '';

    final saveProfileOnGoogle = withFirestore
        ? '\n    // First Google sign-in — create the profile document.\n    await _remote.saveProfile(user);'
        : '';

    final deleteProfile = withFirestore
        ? '''
    // Deleted first: once the account is gone the rules that granted access
    // to its own document no longer match.
    final id = await currentUserId();
    if (id != null) await _remote.deleteProfile(id);
'''
        : '';

    return '''
${pushImports}import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote$pushCtorParam);

  final AuthRemoteDataSource _remote;$pushField

  // Every method below crosses out of `data/`: the datasource answers with
  // models, and a model is no longer an entity — freezed generates the
  // concrete class, so the `extends` that used to make this implicit is gone.
  @override
  Stream<AuthUserEntity?> authStateChanges() =>
      _remote.authStateChanges().map((user) => user?.toEntity());

  @override
  Future<bool> isLoggedIn() async => _remote.currentUser != null;

  @override
  Future<AuthUserEntity?> currentUser() async =>
      _remote.currentUser?.toEntity();

  @override
  Future<AuthUserEntity> login({
    required String email,
    required String password,
  }) async {
    final user = await _remote.login(email: email, password: password);
    return user.toEntity();
  }

  @override
  Future<AuthUserEntity> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = await _remote.register(
      email: email,
      password: password,
      displayName: displayName,
    );$saveProfileOnRegister
    return user.toEntity();
  }

  @override
  Future<AuthUserEntity> signInWithGoogle() async {
    final user = await _remote.signInWithGoogle();$saveProfileOnGoogle
    return user.toEntity();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      _remote.sendPasswordResetEmail(email: email);

  @override
  Future<void> logout() => _remote.logout();

  @override
  Future<void> deleteAccount() async {
$deleteProfile    await _remote.delete();
  }
$syncDeviceToken
  @override
  Future<String?> currentUserId() async => _remote.currentUser?.id;
}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated auth state template.
  static String state() => r'''
import '../../../../core/utils/action_notifier.dart';

class AuthState implements ActionState<AuthState> {
  const AuthState({
    this.authenticated = false,
    this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isLoadingAction = false,
    this.error,
    this.success,
  });

  final bool authenticated;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isLoadingAction;

  /// One-shot UI event fields: any copyWith call that omits them clears
  /// them, so a message is only surfaced once.
  final String? error;
  final String? success;

  AuthState copyWith({
    bool? authenticated,
    String? userId,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isLoadingAction: isLoadingAction ?? this.isLoadingAction,
      error: error,
      success: success,
    );
  }

  @override
  AuthState copyWithLoading() => copyWith(isLoadingAction: true);

  @override
  AuthState copyWithError(String message) => copyWith(error: message);
}
''';

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  /// Returns the generated auth notifier template.
  ///
  /// [withPushNotifications] registers this device with the backend at the
  /// moments a session starts: the restored session at start-up, and every
  /// sign-in or sign-up.
  static String notifier({bool withPushNotifications = false}) {
    final syncOnRestore = withPushNotifications
        ? '''

    // Opened on a session Firebase restored — the FCM token can have changed
    // since (reinstall, restore, token rotation), so register it again.
    if (restored != null) unawaited(_repo.syncDeviceToken());
'''
        : '';

    final syncAfterAuth = withPushNotifications
        ? '\n      // Not awaited: registering the device must not hold up the UI.'
            '\n      unawaited(_repo.syncDeviceToken());'
        : '';

    // Same call one level deeper, inside the try of the Google flow.
    final syncAfterGoogle = withPushNotifications
        ? '\n        unawaited(_repo.syncDeviceToken());'
        : '';

    return '''
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injector.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/action_notifier.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/auth_state.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState>
    with ActionNotifierMixin<AuthState> {
  // Out of the locator, not off another provider: the data layer is wired in
  // `config/di/injector.dart`, and this notifier is the seam between it and
  // Riverpod.
  AuthRepository get _repo => getIt<AuthRepository>();

  @override
  FutureOr<AuthState> build() async {
    // Firebase restores the persisted session asynchronously, so the first
    // event of authStateChanges — not currentUser — is what says whether this
    // start is signed in. The router can park on a splash route until this
    // resolves, and never flashes the wrong screen.
    final changes = _repo.authStateChanges();
    final restored = await changes.first;

    // Later events keep the state honest for the rest of the session: signed
    // out on another device, token revoked, account deleted.
    final subscription = changes.listen(
      (user) => state = AsyncData(_stateFrom(user)),
    );
    ref.onDispose(subscription.cancel);
$syncOnRestore
    return _stateFrom(restored);
  }

  Future<void> login({required String email, required String password}) {
    return runAction((_) async {
      final user = await _repo.login(email: email, password: password);$syncAfterAuth
      return _stateFrom(user);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) {
    return runAction((_) async {
      final user = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
      );$syncAfterAuth
      return _stateFrom(user);
    });
  }

  Future<void> signInWithGoogle() {
    return runAction((current) async {
      try {
        final user = await _repo.signInWithGoogle();$syncAfterGoogle
        return _stateFrom(user);
      } on CancelledException {
        // Dismissing the Google sheet is not a failure worth showing. Every
        // other AppException falls through to runAction, which shows it.
        return current;
      }
    });
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return runAction((current) async {
      await _repo.sendPasswordResetEmail(email: email);
      return current.copyWith(success: 'Password reset email sent');
    });
  }

  Future<void> logout() {
    return runAction((_) async {
      await _repo.logout();
      return const AuthState();
    });
  }

  Future<void> deleteAccount() {
    return runAction((_) async {
      await _repo.deleteAccount();
      return const AuthState(success: 'Account deleted');
    });
  }

  AuthState _stateFrom(AuthUserEntity? user) {
    if (user == null) return const AuthState();
    return AuthState(
      authenticated: true,
      userId: user.id,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
    );
  }
}
''';
  }

  // ── Presentation — Views ────────────────────────────────────────────────────

  /// Returns the generated login view template.
  static String loginView() => r'''
import 'package:flutter/material.dart';

// TODO: build your login UI and call
// ref.read(authNotifierProvider.notifier).login(email: ..., password: ...)
// ref.read(authNotifierProvider.notifier).signInWithGoogle()
// ref.read(authNotifierProvider.notifier).sendPasswordResetEmail(email: ...)

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const SizedBox.shrink(),
    );
  }
}
''';

  /// Returns the generated register view template.
  static String registerView() => r'''
import 'package:flutter/material.dart';

// TODO: build your register UI and call
// ref.read(authNotifierProvider.notifier).register(email: ..., password: ...)

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const SizedBox.shrink(),
    );
  }
}
''';
}
