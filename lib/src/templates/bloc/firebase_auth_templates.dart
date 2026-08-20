/// Generates the auth feature scaffold backed by Firebase Auth — email /
/// password plus Google sign-in — for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/firebase_auth_templates.dart`, and the
/// Firebase counterpart of `templates/bloc/auth_templates.dart`. The layer
/// names, file names and `AuthBloc` API match the REST variant exactly, so
/// the router guard and every screen work the same whichever backend the
/// project chose. What changes is what sits behind the datasource:
/// `FirebaseAuth` and `GoogleSignIn` rather than Dio and `TokenStorage` —
/// Firebase persists the session itself, so there are no tokens to store.
class FirebaseAuthTemplates {
  FirebaseAuthTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────

  /// Returns the generated auth user entity template.
  static String entity() => r'''
class AuthUserEntity {
  const AuthUserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });

  /// The Firebase Auth uid. Also the document id of the user's profile when
  /// the project stores one in Firestore.
  final String id;

  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;

  @override
  bool operator ==(Object other) => other is AuthUserEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
''';

  // ── Domain — Repository interface ───────────────────────────────────────────

  /// Returns the generated auth repository interface template.
  ///
  /// [withPushNotifications] adds the device-token contract the bloc calls on
  /// sign-in and when Firebase restores a session at start-up.
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
    const header = r'''
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_user_entity.dart';

class AuthUserModel extends AuthUserEntity {
  const AuthUserModel({
    required super.id,
    super.email,
    super.displayName,
    super.photoUrl,
    super.emailVerified,
  });

  /// The FirebaseAuth user as the rest of the app sees it.
  factory AuthUserModel.fromFirebaseUser(User user) => AuthUserModel(
        id: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
      );
''';

    const firestoreMapping = r'''

  /// The profile document at `users/{uid}` — the id is the document's name,
  /// not one of its fields.
  factory AuthUserModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    return AuthUserModel(
      id: id,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      // TODO: parse the rest of your profile fields
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      // TODO: add the rest of your profile fields
    };
  }
''';

    return '$header${withFirestore ? firestoreMapping : ''}}\n';
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
        return AuthUserModel.fromJson(data, id: doc.id);
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

  @override
  Stream<AuthUserEntity?> authStateChanges() => _remote.authStateChanges();

  @override
  Future<bool> isLoggedIn() async => _remote.currentUser != null;

  @override
  Future<AuthUserEntity?> currentUser() async => _remote.currentUser;

  @override
  Future<AuthUserEntity> login({
    required String email,
    required String password,
  }) {
    return _remote.login(email: email, password: password);
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
    return user;
  }

  @override
  Future<AuthUserEntity> signInWithGoogle() async {
    final user = await _remote.signInWithGoogle();$saveProfileOnGoogle
    return user;
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
import 'package:equatable/equatable.dart';

/// Whether this app has a session, as a sealed family.
///
/// The router reads it: [AuthInitial] is what holds it on the splash route
/// while Firebase restores the persisted session, so neither login nor home
/// flashes first.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

/// Firebase has not reported yet. Nothing has been decided.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A sign-in, sign-up or Google flow is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Signed in.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  @override
  List<Object?> get props => [userId, email, displayName, photoUrl];
}

/// Signed out, and nothing went wrong getting here.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An attempt failed.
///
/// [userId] is what the failure did *not* change: null means the app is
/// signed out and the login screen shows [message]; non-null means the
/// session survived — a delete Firebase refused, a password reset that
/// bounced — and the screen that asked for it shows [message] without the
/// user being bounced to login.
final class AuthFailure extends AuthState {
  const AuthFailure(this.message, {this.userId});

  final String message;

  /// The still-signed-in user, or null when this failure left the app
  /// signed out.
  final String? userId;

  /// Whether the session outlived the failure. The router redirect reads
  /// this — see `config/router/app_router.dart`.
  bool get authenticated => userId != null;

  @override
  List<Object?> get props => [message, userId];
}
''';

  // ── Presentation — Events ───────────────────────────────────────────────────

  /// Returns the generated auth event template.
  static String event() => r'''
import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_user_entity.dart';

/// Everything that can happen to the session, as values.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// App start: wait for Firebase to restore the persisted session, then keep
/// listening. Dispatched by the `BlocProvider` in main.dart, and nothing else.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Firebase reported a different user, or none. Private to the feature: the
/// bloc adds it to itself from its subscription.
final class AuthUserChanged extends AuthEvent {
  const AuthUserChanged(this.user);

  /// The signed-in user, or null once they are signed out.
  final AuthUserEntity? user;

  @override
  List<Object?> get props => [user];
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.displayName,
  });

  final String email;
  final String password;
  final String? displayName;

  @override
  List<Object?> get props => [email, password, displayName];
}

final class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

final class AuthPasswordResetRequested extends AuthEvent {
  const AuthPasswordResetRequested({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthAccountDeleted extends AuthEvent {
  const AuthAccountDeleted();
}
''';

  // ── Presentation — Bloc ─────────────────────────────────────────────────────

  /// Returns the generated auth bloc template.
  ///
  /// [withPushNotifications] registers this device with the backend at the
  /// moments a session starts: the restored session at start-up, and every
  /// sign-in or sign-up.
  static String bloc({bool withPushNotifications = false}) {
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
        ? '\n      unawaited(_repo.syncDeviceToken());'
        : '';

    return '''
import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// The session, as the whole app sees it.
///
/// Registered as a **singleton** in `config/di/injector.dart`, unlike feature
/// blocs: the router's redirect and every screen have to read the same one.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthPasswordResetRequested>(_onPasswordReset);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthAccountDeleted>(_onDeleteAccount);
  }

  final AuthRepository _repo;
  StreamSubscription<AuthUserEntity?>? _subscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    // Firebase restores the persisted session asynchronously, so the first
    // event of authStateChanges — not currentUser — is what says whether this
    // start is signed in. The router parks on a splash route until this
    // leaves AuthInitial, and never flashes the wrong screen.
    final changes = _repo.authStateChanges().asBroadcastStream();
    final restored = await changes.first;
$syncOnRestore
    emit(_stateFrom(restored));

    // Later events keep the state honest for the rest of the session: signed
    // out on another device, token revoked, account deleted. Fed back in as
    // events rather than emitted here — this handler is finished by then.
    await _subscription?.cancel();
    _subscription = changes.listen((user) => add(AuthUserChanged(user)));
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    emit(_stateFrom(event.user));
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.login(
        email: event.email,
        password: event.password,
      );$syncAfterAuth
      emit(_stateFrom(user));
    } on AppException catch (e) {
      // Still signed out, now with a reason the login screen can show.
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.register(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );$syncAfterAuth
      emit(_stateFrom(user));
    } on AppException catch (e) {
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    emit(const AuthLoading());
    try {
      final user = await _repo.signInWithGoogle();$syncAfterGoogle
      emit(_stateFrom(user));
    } on AppException catch (e) {
      // Dismissing the Google sheet is not a failure worth showing — put the
      // state back exactly as it was and say nothing.
      if (e.type == AppExceptionType.cancelled) {
        emit(current);
        return;
      }
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onPasswordReset(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Sent from the login screen, so the session does not change either way.
    // Only the failure is worth a state; the screen confirms the send itself.
    final current = state;
    try {
      await _repo.sendPasswordResetEmail(email: event.email);
    } on AppException catch (e) {
      // Carrying the session through keeps a signed-in user signed in, and
      // gives two identical failures in a row two distinct states — without
      // it the second `emit` equals the first and bloc drops it, so a
      // repeated typo in the email address would report nothing.
      emit(AuthFailure(
        e.message,
        userId: current is AuthAuthenticated ? current.userId : null,
      ));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Logout always succeeds locally, so there is no failure branch to draw.
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onDeleteAccount(
    AuthAccountDeleted event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    // No AuthLoading around this one, deliberately: the router keys on this
    // state and would read a loading state as "not signed in", bouncing a
    // user who still is. The screen showing the confirm dialog owns the
    // spinner. A failure does get reported — carrying the userId, which is
    // what tells the redirect the session is still good.
    //
    // Firebase refuses a delete on an old session with
    // `requires-recent-login`, which is the common failure here, so this
    // branch is worth drawing: it is how the screen knows to re-authenticate.
    try {
      await _repo.deleteAccount();
      emit(const AuthUnauthenticated());
    } on AppException catch (e) {
      emit(AuthFailure(e.message, userId: current.userId));
    }
  }

  AuthState _stateFrom(AuthUserEntity? user) {
    if (user == null) return const AuthUnauthenticated();
    return AuthAuthenticated(
      userId: user.id,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
''';
  }

  // ── Presentation — Views ────────────────────────────────────────────────────

  /// Returns the generated login view template.
  static String loginView() => r'''
import 'package:flutter/material.dart';

// TODO: build your login UI and dispatch
// context.read<AuthBloc>().add(AuthLoginRequested(email: ..., password: ...))
// context.read<AuthBloc>().add(const AuthGoogleSignInRequested())
// context.read<AuthBloc>().add(AuthPasswordResetRequested(email: ...))

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

// TODO: build your register UI and dispatch
// context.read<AuthBloc>().add(AuthRegisterRequested(email: ..., password: ...))

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
