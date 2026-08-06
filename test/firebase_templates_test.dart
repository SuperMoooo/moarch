import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/docs_templates.dart';
import 'package:moarch/src/templates/ui/feature_templates.dart';
import 'package:moarch/src/templates/ui/firebase_auth_templates.dart';
import 'package:test/test.dart';

void main() {
  group('AppException', () {
    test('maps the FirebaseAuth codes a sign-in flow actually hits', () {
      final output = ErrorTemplates.appException(
        hasDio: false,
        hasFirebase: true,
        hasFirebaseAuth: true,
      );

      expect(output,
          contains("import 'package:firebase_auth/firebase_auth.dart';"));
      expect(
          output,
          contains(
              'factory AppException.fromFirebaseAuthError(FirebaseAuthException error)'));
      // Recent Firebase collapses user-not-found/wrong-password into this one.
      expect(output, contains("case 'invalid-credential':"));
      expect(output, contains("case 'email-already-in-use':"));
      expect(output, contains("case 'weak-password':"));
      expect(output, contains("case 'requires-recent-login':"));
      expect(
          output, contains("case 'account-exists-with-different-credential':"));
      // A dropped connection is a network problem, not a credentials problem.
      expect(
          output,
          contains(
              "case 'network-request-failed':\n        return AppException.noInternet();"));
    });

    test('keeps the Firestore codes out of the auth factory', () {
      final output = ErrorTemplates.appException(
        hasDio: false,
        hasFirebase: true,
        hasFirebaseAuth: true,
      );

      final authFactory =
          output.substring(output.indexOf('fromFirebaseAuthError'));
      final firebaseFactory = output.substring(
        output.indexOf('fromFirebaseError'),
        output.indexOf('fromFirebaseAuthError'),
      );

      expect(firebaseFactory, contains("case 'permission-denied':"));
      expect(firebaseFactory, contains("case 'unavailable':"));
      expect(firebaseFactory, isNot(contains("case 'weak-password':")));
      expect(authFactory, isNot(contains("case 'permission-denied':")));
    });

    test('omits the auth factory and its import without Firebase Auth', () {
      final output = ErrorTemplates.appException(hasFirebase: true);

      expect(output, isNot(contains('firebase_auth')));
      expect(output, isNot(contains('fromFirebaseAuthError')));
      expect(output, contains('factory AppException.fromFirebaseError'));
    });

    test('has the cancelled type and factory a dismissed sheet needs', () {
      final output = ErrorTemplates.appException();

      expect(output, contains('cancelled'));
      expect(output, contains('factory AppException.cancelled()'));
    });
  });

  group('safeFirebaseCall', () {
    test('catches FirebaseAuthException before its supertype', () {
      final output = CoreTemplates.safeFirebaseCall(withAuth: true);

      expect(
        output.indexOf('on FirebaseAuthException'),
        lessThan(output.indexOf('on FirebaseException')),
      );
      // An AppException raised inside must not be re-wrapped as unknown.
      expect(
        output.indexOf('on AppException'),
        lessThan(output.indexOf('on FirebaseAuthException')),
      );
    });

    test('drops the auth arm and import for a Firestore-only project', () {
      final output = CoreTemplates.safeFirebaseCall();

      expect(output, isNot(contains('firebase_auth')));
      expect(output, contains('on FirebaseException catch (e)'));
      expect(output,
          contains("import 'package:firebase_core/firebase_core.dart';"));
    });

    test('maps stream errors the same way', () {
      final output = CoreTemplates.safeFirebaseCall(withAuth: true);

      expect(output, contains('Stream<T> safeFirebaseStream<T>'));
      expect(output, contains('error is FirebaseAuthException'));
      expect(output, contains('error is FirebaseException'));
    });
  });

  group('main.dart', () {
    test('initializes Firebase for Firestore/Auth, not only Crashlytics', () {
      final output = CoreTemplates.mainDart(withFirebase: true);

      expect(output,
          contains("import 'package:firebase_core/firebase_core.dart';"));
      expect(output, contains('await Firebase.initializeApp();'));
      // No Crashlytics selected — no Crashlytics calls.
      expect(output, isNot(contains('FirebaseCrashlytics')));
    });

    test('initializes Firebase exactly once when both are selected', () {
      final output = CoreTemplates.mainDart(
        withFirebase: true,
        withCrashlytics: true,
      );

      // Once, not once per Firebase service — the second call would throw.
      expect(
        'await Firebase.initializeApp();'.allMatches(output).length,
        equals(1),
      );
      expect(
        "import 'package:firebase_core/firebase_core.dart';"
            .allMatches(output)
            .length,
        equals(1),
      );
      expect(output, contains('setCrashlyticsCollectionEnabled(!kDebugMode)'));
    });

    test('leaves a project without Firebase untouched', () {
      final output = CoreTemplates.mainDart();

      expect(output, isNot(contains('firebase_core')));
      expect(output, isNot(contains('Firebase.initializeApp')));
    });
  });

  group('feature templates against Firestore', () {
    test('the datasource holds _firestore instead of _dio', () {
      final output = FeatureTemplates.remoteDatasource(
        'order',
        'Order',
        'order',
        useFirestore: true,
      );

      expect(output, contains('final FirebaseFirestore _firestore;'));
      expect(output, contains('OrderRemoteDataSource(this._firestore)'));
      expect(output, isNot(contains('_dio')));
      expect(output, isNot(contains('package:dio/dio.dart')));

      // Reads, writes and the live query, all through the Firebase wrapper.
      expect(output, contains('ref.watch(firebaseDbProvider)'));
      expect(output, contains('safeFirebaseCall<List<OrderModel>>'));
      expect(output, contains('Stream<List<OrderModel>> watchAll()'));
      expect(output, contains('safeFirebaseStream('));
      expect(output, contains("static const String collectionPath = 'order';"));
    });

    test('the Dio datasource is unchanged', () {
      final output =
          FeatureTemplates.remoteDatasource('order', 'Order', 'order');

      expect(output, contains('final Dio _dio;'));
      expect(output, contains('safeApiCall<OrderModel>'));
      expect(output, isNot(contains('firestore')));
    });

    test('the id is the document id, not a numeric column', () {
      final entity =
          FeatureTemplates.entity('order', 'Order', useFirestore: true);
      final model =
          FeatureTemplates.model('order', 'Order', useFirestore: true);

      expect(entity, contains('final String id;'));
      expect(model, contains('factory OrderModel.fromDoc(DocumentSnapshot'));
      expect(model, contains('id: doc.id'));
      // Writing the id back as a field would store it twice.
      expect(model, isNot(contains("'id': id,")));
    });

    test('the repository exposes the live query, the Dio one does not', () {
      final firestore = FeatureTemplates.repositoryInterface('order', 'Order',
          useFirestore: true);

      expect(firestore, contains('Stream<List<OrderEntity>> watchAll();'));
      expect(firestore, contains('Future<List<OrderEntity>> getAll();'));
      expect(
        FeatureTemplates.repositoryInterface('order', 'Order'),
        isNot(contains('watchAll')),
      );
    });

    test('the repository impl maps the datasource, TODO left to the Dio one',
        () {
      final output = FeatureTemplates.repositoryImpl(
        'order',
        'Order',
        'order',
        hasRemote: true,
        hasLocal: false,
        useFirestore: true,
      );

      expect(output, contains('await _remote.fetchAll()'));
      expect(output, contains('_remote.watchAll().map('));
      expect(output, contains('models.map((model) => model.toEntity())'));
      expect(output, isNot(contains('UnimplementedError')));

      expect(
        FeatureTemplates.repositoryImpl('order', 'Order', 'order',
            hasRemote: true, hasLocal: false),
        contains('throw UnimplementedError()'),
      );
    });

    test('the layer the user declined is not invented for them', () {
      // No remote datasource selected — there is nothing to map, so both
      // methods stay TODOs rather than calling a field that does not exist.
      final output = FeatureTemplates.repositoryImpl(
        'order',
        'Order',
        'order',
        hasRemote: false,
        hasLocal: true,
        useFirestore: true,
      );

      expect(output, isNot(contains('_remote')));
      expect(output, contains('Stream<List<OrderEntity>> watchAll()'));
      expect('UnimplementedError'.allMatches(output).length, 2);
    });

    test('the state holds what the query emits', () {
      final output =
          FeatureTemplates.state('order', 'Order', useFirestore: true);

      expect(output,
          contains("import '../../domain/entities/order_entity.dart';"));
      expect(output, contains('final List<OrderEntity> items;'));
      expect(output, contains('this.items = const [],'));
      expect(output, contains('items: items ?? this.items,'));

      expect(
          FeatureTemplates.state('order', 'Order'), isNot(contains('items')));
    });

    test('the state carries the fake data its skeleton is traced from', () {
      final output =
          FeatureTemplates.state('order', 'Order', useFirestore: true);

      // Rows that exist only to be the right size — an empty list traces to a
      // blank screen. BoneMock sets that size, so the package comes along.
      expect(
        output,
        contains("import 'package:skeletonizer/skeletonizer.dart';"),
      );
      expect(output, contains('static final placeholder = OrderState('));
      expect(
        output,
        contains('items: List.filled(3, OrderEntity(id: BoneMock.name)),'),
      );

      // The REST state has no fields to fake yet, so it gets the hook and a
      // TODO rather than an import it would not use.
      final rest = FeatureTemplates.state('order', 'Order');
      expect(rest, contains('static const placeholder = OrderState();'));
      expect(rest, isNot(contains('package:skeletonizer/skeletonizer.dart')));
    });

    test('the notifier subscribes once and hands the subscription to Riverpod',
        () {
      final output = FeatureTemplates.notifier(
        'order',
        'Order',
        'order',
        hasUseCase: false,
        useFirestore: true,
      );

      expect(output, contains('_repo.watchAll().listen('));
      expect(output, contains('final firstSnapshot = Completer<OrderState>()'));
      expect(output, contains('ref.onDispose(subscription.cancel)'));
      expect(output, contains('return firstSnapshot.future;'));
      // The query is opened exactly once: awaiting `.first` for the initial
      // load on top of this would register it a second time.
      expect('watchAll()'.allMatches(output), hasLength(1));
      // Errors reach AppAsyncView as the AsyncValue it already renders.
      expect(output, contains('state = AsyncError(error, stackTrace)'));

      // The REST notifier still starts from nothing.
      expect(
        FeatureTemplates.notifier('order', 'Order', 'order', hasUseCase: false),
        contains('return const OrderState();'),
      );
    });

    test('the view renders the live items', () {
      final output = FeatureTemplates.view(
        'order',
        'Order',
        'order',
        hasNotifier: true,
        useFirestore: true,
      );

      expect(output, contains('itemCount: state.items.length'));
      expect(output, contains('final order = state.items[index];'));
      expect(output, contains('isEmpty: (state) => state.items.isEmpty,'));
      // Skeletonizer traces the real layout, so the rows need a size to
      // shimmer — the fake ones live on the state, not inline here.
      expect(
        output,
        contains('skeleton: (context) => _body(context, OrderState.placeholder),'),
      );
      // Which is why the view no longer names the entity at all.
      expect(output, isNot(contains('OrderEntity')));

      expect(
        FeatureTemplates.view('order', 'Order', 'order', hasNotifier: true),
        contains('return const SizedBox.shrink();'),
      );
    });

    test('the Dio entity and model keep the int id', () {
      expect(
          FeatureTemplates.entity('order', 'Order'), contains('final int id;'));
      expect(
        FeatureTemplates.model('order', 'Order'),
        contains("id: json['id'] as int"),
      );
    });
  });

  group('Firebase auth feature', () {
    test('signs in with Google through the current google_sign_in API', () {
      final output = FirebaseAuthTemplates.remoteDatasource();

      expect(output,
          contains("import 'package:google_sign_in/google_sign_in.dart';"));
      expect(output, contains('GoogleSignIn.instance'));
      expect(output, contains('_googleSignIn.initialize(serverClientId:'));
      expect(output, contains('await _googleSignIn.authenticate()'));
      expect(output, contains('account.authentication.idToken'));
      expect(
          output, contains('GoogleAuthProvider.credential(idToken: idToken)'));
      expect(output, contains('_auth.signInWithCredential(credential)'));
      // A dismissed sheet is a cancellation, not a failure.
      expect(output, contains('GoogleSignInExceptionCode.canceled'));
      expect(output, contains('throw AppException.cancelled()'));
    });

    test('covers the email/password flow and account deletion', () {
      final output = FirebaseAuthTemplates.remoteDatasource();

      expect(output, contains('signInWithEmailAndPassword'));
      expect(output, contains('createUserWithEmailAndPassword'));
      expect(output, contains('sendPasswordResetEmail'));
      expect(output, contains('_auth.authStateChanges()'));
      expect(output, contains('await _googleSignIn.signOut();'));
      // Deleting a Google-linked account must revoke the grant too.
      expect(output, contains('_googleSignIn.disconnect()'));
      expect(output, contains('await user.delete();'));
    });

    test('keeps a Firestore profile document only when Firestore is on', () {
      final withDb =
          FirebaseAuthTemplates.remoteDatasource(withFirestore: true);
      final withoutDb = FirebaseAuthTemplates.remoteDatasource();

      expect(withDb, contains('final FirebaseFirestore _firestore;'));
      expect(
          withDb, contains("static const String usersCollection = 'users';"));
      expect(withDb, contains('Future<void> saveProfile(AuthUserModel user)'));
      expect(withDb, contains('SetOptions(merge: true)'));

      expect(withoutDb, isNot(contains('_firestore')));
      expect(withoutDb, isNot(contains('cloud_firestore')));
      expect(withoutDb, isNot(contains('saveProfile')));
    });

    test('the repository writes the profile on register and Google sign-in',
        () {
      final withDb = FirebaseAuthTemplates.repositoryImpl(withFirestore: true);
      final withoutDb = FirebaseAuthTemplates.repositoryImpl();

      expect(withDb, contains('await _remote.saveProfile(user);'));
      expect(withDb, contains('await _remote.deleteProfile(id);'));
      expect(withoutDb, isNot(contains('saveProfile')));
      // Both variants satisfy the same contract.
      for (final output in [withDb, withoutDb]) {
        expect(output,
            contains('class AuthRepositoryImpl implements AuthRepository'));
        expect(output, contains('Future<AuthUserEntity> signInWithGoogle()'));
        expect(output, contains('final authRepositoryProvider'));
      }
    });

    test('the model maps a FirebaseAuth user, no tokens involved', () {
      final output = FirebaseAuthTemplates.model();

      expect(output,
          contains('factory AuthUserModel.fromFirebaseUser(User user)'));
      expect(output, contains('id: user.uid'));
      expect(output, isNot(contains('accessToken')));
      // The profile JSON only comes with Firestore.
      expect(output, isNot(contains('toJson')));
      expect(
        FirebaseAuthTemplates.model(withFirestore: true),
        contains('Map<String, dynamic> toJson()'),
      );
    });

    test('the notifier restores the session from the auth stream', () {
      final output = FirebaseAuthTemplates.notifier();

      expect(output, contains('FutureOr<AuthState> build() async'));
      // currentUser can still be null right after launch — the first stream
      // event is what says whether the app opened signed in.
      expect(output, contains('final restored = await changes.first;'));
      expect(output, contains('ref.onDispose(subscription.cancel);'));
      expect(output, contains('with ActionNotifierMixin<AuthState>'));
      expect(output, contains('Future<void> signInWithGoogle()'));
      // A cancelled sign-in leaves the state alone.
      expect(
          output,
          contains(
              'if (e.type == AppExceptionType.cancelled) return current;'));
    });

    test('exposes the same provider names as the REST auth feature', () {
      expect(FirebaseAuthTemplates.notifier(),
          contains('final authNotifierProvider ='));
      expect(FirebaseAuthTemplates.repositoryImpl(),
          contains('final authRepositoryProvider ='));
      expect(FirebaseAuthTemplates.remoteDatasource(),
          contains('final authRemoteDataSourceProvider ='));
      expect(FirebaseAuthTemplates.state(),
          contains('implements ActionState<AuthState>'));
    });
  });

  group('FCM notifications service', () {
    test('waits for the APNs token before asking FCM on Apple platforms', () {
      final output = ServicesTemplates.firebaseNotificationsService();

      expect(output, contains('Future<String?> getDeviceToken({'));
      expect(output, contains('Future<String?> getApnsToken({'));
      // FCM cannot mint a token before APNs handed the app its own.
      expect(
        output.indexOf('await getApnsToken('),
        lessThan(output.indexOf('await _messaging.getToken()')),
      );
      // Android has no APNs step to wait for.
      expect(output, contains('if (!_isApplePlatform) return null;'));
      expect(output, contains('defaultTargetPlatform == TargetPlatform.iOS'));
      expect(output, contains("import 'package:flutter/foundation.dart';"));
    });

    test('retries both tokens with a growing delay', () {
      final output = ServicesTemplates.firebaseNotificationsService();

      expect(output, contains('static const int _tokenRetries ='));
      expect(
        'for (var attempt = 1; attempt <= retries; attempt++)'
            .allMatches(output)
            .length,
        equals(2),
      );
      expect(
        'await Future<void>.delayed(retryDelay * attempt);'
            .allMatches(output)
            .length,
        equals(2),
      );
      // A failed lookup must not take the caller down with it.
      expect(output, contains('} catch (error, stackTrace) {'));
      expect(output, contains('return null;'));
    });

    test('leaves the moment to fetch the token to the caller', () {
      final output = ServicesTemplates.firebaseNotificationsService();

      // init() only asks for permission — on iOS there is no token before the
      // user accepts, and the auth feature is what registers it afterwards.
      expect(output, contains('await requestPermissions();'));
      expect(output, isNot(contains('getDeviceToken()\n')));
    });

    test('the auth feature registers the device on sign-in and on restore', () {
      final notifier =
          FirebaseAuthTemplates.notifier(withPushNotifications: true);
      final interface = FirebaseAuthTemplates.repositoryInterface(
        withPushNotifications: true,
      );
      final impl =
          FirebaseAuthTemplates.repositoryImpl(withPushNotifications: true);

      // Login, register, Google, and the session Firebase restored at start-up.
      expect(
        'unawaited(_repo.syncDeviceToken());'.allMatches(notifier).length,
        equals(4),
      );
      // Nothing to register when the app opened signed out.
      expect(
          notifier,
          contains(
              'if (restored != null) unawaited(_repo.syncDeviceToken());'));

      expect(interface, contains('Future<void> syncDeviceToken();'));
      expect(impl, contains('ref.watch(firebaseNotificationsServiceProvider)'));
      expect(impl, contains('final id = await currentUserId();'));
      expect(impl, contains('await _push.getDeviceToken();'));
      expect(
        impl,
        contains('_remote.saveDeviceToken(userId: id, token: deviceToken)'),
      );
    });

    test('the token lands on the profile document only with Firestore', () {
      final withDb = FirebaseAuthTemplates.remoteDatasource(
        withFirestore: true,
        withPushNotifications: true,
      );
      final withoutDb =
          FirebaseAuthTemplates.remoteDatasource(withPushNotifications: true);

      expect(withDb, contains('Future<void> saveDeviceToken({'));
      // arrayUnion, so signing in twice on one device stores one token.
      expect(withDb, contains("'fcmTokens': FieldValue.arrayUnion([token]),"));
      expect(withDb, contains('_profileRef(userId).set('));

      // No database in the project — the method is left for the developer.
      expect(withoutDb, contains('Future<void> saveDeviceToken({'));
      expect(withoutDb, isNot(contains('FieldValue')));
      expect(withoutDb, contains('// TODO: save userId + token.'));
    });

    test('a Firebase auth project without FCM is left alone', () {
      for (final output in [
        FirebaseAuthTemplates.repositoryInterface(),
        FirebaseAuthTemplates.repositoryImpl(withFirestore: true),
        FirebaseAuthTemplates.remoteDatasource(withFirestore: true),
        FirebaseAuthTemplates.notifier(),
      ]) {
        expect(output, isNot(contains('syncDeviceToken')));
        expect(output, isNot(contains('saveDeviceToken')));
        expect(output, isNot(contains('firebase_notifications_service')));
      }
    });
  });

  group('Firebase setup doc', () {
    test('covers the iOS keys and Android fingerprints for Google sign-in', () {
      final output = DocsTemplates.firebaseSetup(
        withAuth: true,
        withGoogleSignIn: true,
        withFirestore: true,
      );

      expect(output, contains('flutterfire configure'));
      expect(output, contains('GIDClientID'));
      expect(output, contains('REVERSED_CLIENT_ID'));
      expect(output, contains('SHA-1 and SHA-256'));
      expect(output, contains('kGoogleServerClientId'));
      expect(output, contains('rules_version'));
    });

    test('leaves out the sections the project did not select', () {
      final output = DocsTemplates.firebaseSetup(withCrashlytics: true);

      expect(output, contains('Crashlytics'));
      expect(output, isNot(contains('GIDClientID')));
      expect(output, isNot(contains('rules_version')));
    });
  });
}
