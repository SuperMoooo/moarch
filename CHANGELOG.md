# [2.9.0]

## Features

- Firebase Auth is now a backend choice, not just a provider. Selecting it with
  the auth feature generates that feature against Firebase instead of REST:
  email/password, **Google sign-in**, password reset, account deletion, and a
  session restored from `authStateChanges()`. Same layers and provider names, no
  token storage, and Dio is no longer pulled in for it.
- `moarch create feature` follows the project's backend: in a Firestore project
  the datasource holds `_firestore` instead of `_dio`, with
  `fetchAll`/`fetchOne`/`watchAll`/`create`/`save`/`delete` over one collection
  and a `String` document id. With both backends installed, the layer checklist
  asks which one the feature talks to.
- `AppException` maps the Firebase failures an app actually hits: a
  `fromFirebaseAuthError` factory for the auth codes (`invalid-credential`,
  `email-already-in-use`, `weak-password`, `requires-recent-login`,
  `too-many-requests`…) and the Firestore codes (`permission-denied`,
  `unavailable`…) in `fromFirebaseError`. New `auth` and `cancelled` types, plus
  `AppException.cancelled()` for a dismissed sign-in sheet.
- New `core/network/safe_firebase_call.dart` — the Firebase counterpart of
  `safeApiCall`, for one-off calls and for streams.
- New `docs/FIREBASE_SETUP.md` covering the work that lives outside Dart:
  `flutterfire configure`, enabling the sign-in providers, the Android
  SHA-1/SHA-256 fingerprints, the iOS `GIDClientID` and `REVERSED_CLIENT_ID` URL
  scheme, the web client id, and a starting set of Firestore rules.
- `init` writes the two iOS Google sign-in keys into `Info.plist`, taking the
  real values from `GoogleService-Info.plist` when it is already there and
  leaving documented placeholders when it isn't. Existing URL types are kept.

## Fixes

- `main.dart` now calls `Firebase.initializeApp()` for Firestore and Firebase
  Auth, not only for Crashlytics — a project with either selected used to throw
  "No Firebase App '[DEFAULT]' has been created" on its first provider read.

## Doctor

- New checks for a half-wired Firebase project: missing `firebase_core` or
  `google_sign_in`, no `Firebase.initializeApp()` in `main.dart`, a missing
  `google-services.json` / `GoogleService-Info.plist`, and `Info.plist` still
  carrying the placeholder Google client ids — which `--fix` fills in from
  `GoogleService-Info.plist`.
