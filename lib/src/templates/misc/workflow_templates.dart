import '../../utils/state_management.dart';

/// Generates CI and security workflow templates.
class WorkflowTemplates {
  WorkflowTemplates._();

  /// Returns the unified workflow template, combining every job in order.
  ///
  /// [stateManagement] adds the `bloc lint` step to the analyze job: the bloc
  /// rules live in `analysis_options.yaml` but are read by the bloc analysis
  /// server, not by `dart analyze`, so CI has to run that tool too or the
  /// rules only ever fire in the editor.
  static String unifiedWorkflow({
    StateManagement stateManagement = StateManagement.riverpod,
  }) {
    final blocLint = stateManagement.isBloc
        ? '''

            # The bloc rules in analysis_options.yaml are the bloc analysis
            # server's, and `flutter analyze` above does not read them.
            - name: Bloc lint
              run: |
                  dart pub global activate bloc_tools
                  dart pub global run bloc_tools:bloc lint .
'''
        : '';

    return _unifiedWorkflow.replaceFirst(_blocLintAnchor, blocLint);
  }

  /// Where [unifiedWorkflow] splices the bloc lint step in — right after the
  /// analyze step, so a lint failure stops the run before the tests.
  static const String _blocLintAnchor = '{{bloc_lint}}';

  static const String _unifiedWorkflow = r'''
# ── Unified Pipeline ──────────────────────────────────────────────────────────
# Runs all jobs in order. Build only triggers if every check passes.
#
# Job order:
#   1. unit              — format check, analyze, unit tests (no network)
#   2. integration       — integration tests against the real API
#   3. secrets           — scans for leaked secrets
#   4. dependency-review — CVE + license check (pull requests only)
#
# Required GitHub secrets (Settings → Secrets and variables → Actions):
#   BASE_URL — your API base URL e.g. https://api.yourapp.com
#
# A newer push to the same branch cancels the run still going for the old
# one, so a burst of commits costs one run, not one per commit.

name: CI

on:
    push:
        branches: [main, develop]
    pull_request:
        branches: [main]
    workflow_dispatch: {}

concurrency:
    group: ci-${{ github.ref }}
    cancel-in-progress: true

jobs:
    # ── 1. Format, analyze, unit tests ───────────────────────────────────────────
    unit:
        runs-on: ubuntu-latest
        timeout-minutes: 20

        steps:
            - uses: actions/checkout@v7

            - uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true

            - name: Install dependencies
              run: flutter pub get
            
            - name: Create .env & generate env code
              run: |
                  cat <<EOF > .env
                  BASE_URL=${{ secrets.BASE_URL }}
                  EOF
                  dart run build_runner build --delete-conflicting-outputs

            - name: Check formatting
              run: dart format --output=none --set-exit-if-changed .

            - name: Analyze
              run: flutter analyze
{{bloc_lint}}
            - name: Unit tests
              run: |
                  if [ -d test/unit ] && [ -n "$(find test/unit -name '*_test.dart')" ]; then
                    flutter test test/unit/
                  else
                    echo "No tests found in test/unit/ — skipping."
                  fi

    # ── 2. Integration tests ─────────────────────────────────────────────────────
    # Hits the real API — only runs if unit tests pass first.
    # If your API is sometimes flaky, add: continue-on-error: true
    integration:
        runs-on: ubuntu-latest
        timeout-minutes: 20
        needs: unit

        steps:
            - uses: actions/checkout@v7

            - uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true

            - name: Install dependencies
              run: flutter pub get

            - name: Create .env & generate env code
              run: |
                  cat <<EOF > .env
                  BASE_URL=${{ secrets.BASE_URL }}
                  EOF
                  dart run build_runner build --delete-conflicting-outputs

            - name: Integration tests
              run: |
                  if [ -d test/integration ] && [ -n "$(find test/integration -name '*_test.dart')" ]; then
                    flutter test test/integration/
                  else
                    echo "No tests found in test/integration/ — skipping."
                  fi
              continue-on-error: true

    # ── 3. Secrets scan ──────────────────────────────────────────────────────────
    secrets:
        runs-on: ubuntu-latest
        timeout-minutes: 10
        needs: unit

        steps:
            - uses: actions/checkout@v7
              with:
                  fetch-depth: 0

            - uses: dart-lang/setup-dart@v1
              with:
                  sdk: stable

            - name: Install dart_secrets_scanner
              run: dart pub global activate dart_secrets_scanner

            - name: Run secrets scanner
              run: |
                  export PATH="$PATH":"$HOME/.pub-cache/bin"
                  dart_secrets_scanner scan \
                    --path . \
                    --output json > secrets-report.json || true

            - name: Parse and report secrets
              run: |
                  echo "=== Secret Scan Results ==="
                  cat secrets-report.json | jq .findings 2>/dev/null || echo "No findings"

                  FOUND=$(cat secrets-report.json | jq '.findings | length' 2>/dev/null || echo 0)
                  if [ "$FOUND" -gt 0 ]; then
                    echo "❌ Found $FOUND potential secrets"
                    exit 1
                  else
                    echo "✅ No secrets detected"
                  fi

            - name: Upload secrets report
              if: always()
              uses: actions/upload-artifact@v7
              with:
                  name: secrets-report
                  path: secrets-report.json
                  retention-days: 30

    # ── 4. Dependency review ─────────────────────────────────────────────────────
    # Only runs on pull requests — it compares the base with the head, and
    # fails a PR that adds a dependency with a known high-severity CVE.
    dependency-review:
        runs-on: ubuntu-latest
        timeout-minutes: 10
        needs: unit
        if: github.event_name == 'pull_request'

        steps:
            - uses: actions/checkout@v7

            - name: Dependency review
              uses: actions/dependency-review-action@v5
              with:
                  fail-on-severity: high
                  # Uncomment to block specific licenses:
                  # deny-licenses: GPL-2.0, GPL-3.0

''';

  /// BUILD IOS WORKFLOW
  ///
  /// [withFirebase] adds a step that links GoogleService-Info.plist into the
  /// Xcode project via add_files_to_xcode.rb.
  /// [withPushEntitlements] signs the archive with Runner.entitlements so
  /// the APNs (push) capability is embedded in the IPA.
  ///
  /// The app is compiled once: `flutter build ios --config-only` writes the
  /// Xcode configuration (build number, obfuscation) and installs the pods,
  /// and `xcodebuild archive` does the only build. A macOS runner costs ten
  /// times a Linux one, so a second compile is the expensive part to avoid.
  static String buildIOS({
    bool withFirebase = false,
    bool withPushEntitlements = false,
  }) {
    final firebaseStep = withFirebase
        ? '''            - name: Install xcodeproj gem
              run: gem install xcodeproj

            - name: Register files in Xcode
              run: ruby add_files_to_xcode.rb

'''
        : '';

    final entitlementsArg = withPushEntitlements
        ? '\n                    CODE_SIGN_ENTITLEMENTS="Runner/Runner.entitlements" \\'
        : '';

    const head = r'''
# Builds a signed IPA on a GitHub macOS runner, on demand
# (Actions → Build IOS IPA → Run workflow).
#
# Secrets — docs/STEPS_FOR_WORKFLOW.md produces each one:
#   BASE_URL                         the API the build talks to
#   IOS_P12_BASE64                   base64 of your .p12 (certificate + key)
#   IOS_P12_PASSWORD                 the password you set exporting it
#   IOS_PROVISIONING_PROFILE_BASE64  base64 of your .mobileprovision
#   IOS_TEAM_ID                      your Apple Developer Team ID
# For TestFlight (export method app-store), also:
#   APP_STORE_CONNECT_KEY_ID         the App Store Connect API key's id
#   APP_STORE_CONNECT_ISSUER_ID      its issuer id
#   APP_STORE_CONNECT_KEY_BASE64     base64 of its AuthKey_<id>.p8
#
# The certificate and the profile must match the export method you pick:
#   development — an Apple Development certificate + a development profile
#   ad-hoc      — an Apple Distribution certificate + an ad hoc profile
#   app-store   — an Apple Distribution certificate + an App Store profile

name: Build IOS IPA

on:
    workflow_dispatch:
        inputs:
            export_method:
                description: development (your devices), ad-hoc (registered testers) or app-store (TestFlight)
                type: choice
                options: [development, ad-hoc, app-store]
                default: development

concurrency:
    group: build-ipa-${{ github.ref }}
    cancel-in-progress: true

jobs:
    # ── 1. Check for Apple credentials ──────────────────────────────────────────
    # On a Linux runner, so a fork or a fresh clone without the secrets skips
    # the build without paying for a macOS one.
    check-ios-secrets:
        runs-on: ubuntu-latest
        outputs:
            has_secrets: ${{ steps.check.outputs.has_secrets }}
            has_app_store_key: ${{ steps.check.outputs.has_app_store_key }}
        steps:
            - name: Check required secrets
              id: check
              run: |
                  if [ -n "${{ secrets.IOS_P12_BASE64 }}" ] && \
                     [ -n "${{ secrets.IOS_P12_PASSWORD }}" ] && \
                     [ -n "${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}" ] && \
                     [ -n "${{ secrets.IOS_TEAM_ID }}" ]; then
                    echo "has_secrets=true" >> "$GITHUB_OUTPUT"
                  else
                    echo "has_secrets=false" >> "$GITHUB_OUTPUT"
                    echo "⚠️ iOS signing secrets not fully configured — iOS build will be skipped."
                  fi
                  if [ -n "${{ secrets.APP_STORE_CONNECT_KEY_ID }}" ] && \
                     [ -n "${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}" ] && \
                     [ -n "${{ secrets.APP_STORE_CONNECT_KEY_BASE64 }}" ]; then
                    echo "has_app_store_key=true" >> "$GITHUB_OUTPUT"
                  else
                    echo "has_app_store_key=false" >> "$GITHUB_OUTPUT"
                  fi

    # ── 2. Build iOS ─────────────────────────────────────────────────────────────
    # The macOS runner is the only "Mac" involved, and GitHub provides it.
    build-ios:
        runs-on: macos-latest
        timeout-minutes: 45
        needs: [check-ios-secrets]
        if: needs.check-ios-secrets.outputs.has_secrets == 'true'
        steps:
            - uses: actions/checkout@v7
            # App Store Connect refuses an upload not built with Xcode 26 and
            # the iOS 26 SDK (since April 28, 2026); the runner image's
            # default Xcode is not promised to be that, so pick it.
            - uses: maxim-lobanov/setup-xcode@v1
              with:
                  xcode-version: latest-stable
            - uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true
            - name: Install dependencies
              run: flutter pub get

            - name: Create .env & generate env code
              run: |
                  cat <<EOF > .env
                  BASE_URL=${{ secrets.BASE_URL }}
                  EOF
                  dart run build_runner build --delete-conflicting-outputs

            - name: Import signing certificate
              env:
                  P12_BASE64: ${{ secrets.IOS_P12_BASE64 }}
                  P12_PASSWORD: ${{ secrets.IOS_P12_PASSWORD }}
                  KEYCHAIN_PASSWORD: ${{ secrets.IOS_P12_PASSWORD }}
              run: |
                  echo "$P12_BASE64" | base64 --decode > certificate.p12
                  security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
                  security default-keychain -s build.keychain
                  security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
                  security set-keychain-settings -t 3600 -u build.keychain
                  security list-keychains -d user -s build.keychain login.keychain
                  security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
                  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain

            - name: Install provisioning profile
              env:
                  PROFILE_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
              run: |
                  mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
                  echo "$PROFILE_BASE64" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

            - name: Extract provisioning profile info
              id: profile_info
              run: |
                  PROFILE_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/profile.mobileprovision"
                  PROFILE_NAME=$(security cms -D -i "$PROFILE_PATH" | plutil -extract Name xml1 -o - - | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
                  BUNDLE_ID=$(security cms -D -i "$PROFILE_PATH" | plutil -extract Entitlements.application-identifier xml1 -o - - | sed -n 's/.*<string>[A-Z0-9]*\.\(.*\)<\/string>.*/\1/p')
                  echo "profile_name=$PROFILE_NAME" >> "$GITHUB_OUTPUT"
                  echo "bundle_id=$BUNDLE_ID" >> "$GITHUB_OUTPUT"
                  echo "Profile name: $PROFILE_NAME"
                  echo "Bundle ID: $BUNDLE_ID"

''';

    const mid =
        r'''            # Writes Generated.xcconfig (obfuscation, and the version and
            # build number from pubspec.yaml — raise them with
            # `moarch release bump`) and installs the pods, without
            # compiling. The archive below is the one build.
            - name: Configure the Xcode project
              run: |
                  flutter build ios --config-only --release \
                    --obfuscate --split-debug-info=${{ github.workspace }}/build/debug-info/ios

            - name: Archive and export IPA
              env:
                  TEAM_ID: ${{ secrets.IOS_TEAM_ID }}
                  PROFILE_NAME: ${{ steps.profile_info.outputs.profile_name }}
                  BUNDLE_ID: ${{ steps.profile_info.outputs.bundle_id }}
                  METHOD: ${{ inputs.export_method }}
              run: |
                  case "$METHOD" in
                    development) IDENTITY="Apple Development";  EXPORT_METHOD=debugging ;;
                    ad-hoc)      IDENTITY="Apple Distribution"; EXPORT_METHOD=release-testing ;;
                    *)           IDENTITY="Apple Distribution"; EXPORT_METHOD=app-store-connect ;;
                  esac

                  cd ios
                  xcodebuild -workspace Runner.xcworkspace \
                    -scheme Runner \
                    -sdk iphoneos \
                    -configuration Release \
                    -archivePath build/Runner.xcarchive \
                    archive \
                    CODE_SIGN_STYLE=Manual \
                    DEVELOPMENT_TEAM="$TEAM_ID" \
                    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \''';

    const tail = r'''                    CODE_SIGN_IDENTITY="$IDENTITY"

                  cat > ExportOptions.plist << EOF
                  <?xml version="1.0" encoding="UTF-8"?>
                  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                  <plist version="1.0">
                  <dict>
                      <key>method</key>
                      <string>$EXPORT_METHOD</string>
                      <key>teamID</key>
                      <string>$TEAM_ID</string>
                      <key>signingStyle</key>
                      <string>manual</string>
                      <key>provisioningProfiles</key>
                      <dict>
                          <key>$BUNDLE_ID</key>
                          <string>$PROFILE_NAME</string>
                      </dict>
                  </dict>
                  </plist>
                  EOF

                  xcodebuild -exportArchive \
                    -archivePath build/Runner.xcarchive \
                    -exportPath build/ipa \
                    -exportOptionsPlist ExportOptions.plist

            - name: Upload IPA artifact
              uses: actions/upload-artifact@v7
              with:
                  name: release-ipa-${{ inputs.export_method }}-${{ github.run_number }}
                  path: ios/build/ipa/*.ipa
                  retention-days: 30

            # The symbols for this exact build: without them its crash stack
            # traces stay unreadable, and they cannot be regenerated later.
            - name: Upload debug symbols
              uses: actions/upload-artifact@v7
              with:
                  name: debug-info-ios-${{ github.run_number }}
                  path: build/debug-info/ios/
                  retention-days: 90

            - name: Upload to TestFlight
              if: inputs.export_method == 'app-store' && needs.check-ios-secrets.outputs.has_app_store_key == 'true'
              env:
                  KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
                  ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
                  KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_KEY_BASE64 }}
              run: |
                  mkdir -p ~/.appstoreconnect/private_keys
                  echo "$KEY_BASE64" | base64 --decode > ~/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8
                  IPA=$(ls ios/build/ipa/*.ipa | head -n 1)
                  xcrun altool --upload-app --type ios --file "$IPA" \
                    --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
                  VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
                  echo "Uploaded $VERSION — it shows in TestFlight once Apple has processed it." >> $GITHUB_STEP_SUMMARY

            - name: Cleanup keychain
              if: always()
              run: |
                  rm -f certificate.p12
                  rm -rf ~/.appstoreconnect/private_keys
                  security delete-keychain build.keychain || true
''';

    // Dart eats the newline right after an opening ''', so tail supplies its
    // own indentation and the \n before it lives here instead.
    return '$head$firebaseStep$mid$entitlementsArg\n$tail';
  }

  /// Returns the supply chain analysis (reporting) workflow.
  /// Non-blocking: SBOM + license report, scheduled weekly and on release tags.
  static String csaWorkflow() => r'''
# ── Supply Chain Analysis (Reporting) ─────────────────────────────────────────
# Non-blocking compliance artifacts: SBOM + license report.
# Runs on release tags and by hand — never on a schedule, so a repository
# nobody touched for a week does not fail on its own and email you about it.
# It does not gate merges or builds; CVE checks on pull requests live in
# unified_workflow.yml (dependency-review).

name: CSA

on:
    push:
        tags:
            - 'v*'
    workflow_dispatch: {}

jobs:
    sbom:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@v7

            - uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true

            - name: Install dependencies
              run: flutter pub get

            - name: Setup Node (for cdxgen)
              uses: actions/setup-node@v7
              with:
                  node-version: '20'

            - name: Generate SBOM (CycloneDX JSON via cdxgen)
              run: |
                  npx --yes @cyclonedx/cdxgen@latest -t dart -o sbom.json .

            - name: Upload SBOM
              uses: actions/upload-artifact@v7
              with:
                  name: sbom-cyclonedx
                  path: sbom.json
                  retention-days: 90

    license-compliance:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@v7

            - uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true

            - name: Install dependencies
              run: flutter pub get

            # pana compiles the package, so the gitignored env code must exist.
            - name: Create .env & generate env code
              run: |
                  cat <<EOF > .env
                  BASE_URL=${{ secrets.BASE_URL }}
                  EOF
                  dart run build_runner build --delete-conflicting-outputs

            - name: Run pana license/health report
              run: |
                  dart pub global activate pana
                  export PATH="$PATH":"$HOME/.pub-cache/bin"
                  pana --json . > pana-report.json || true

            - name: Upload license report
              uses: actions/upload-artifact@v7
              with:
                  name: license-report
                  path: pana-report.json
                  retention-days: 90

    summary:
        runs-on: ubuntu-latest
        needs: [sbom, license-compliance]
        if: always()

        steps:
            - name: Download all reports
              uses: actions/download-artifact@v8
              with:
                  path: reports

            - name: Write summary
              run: |
                  echo "## Supply Chain Analysis — $(date -u +%Y-%m-%d)" >> $GITHUB_STEP_SUMMARY
                  echo "- SBOM (CycloneDX) and license/health report generated." >> $GITHUB_STEP_SUMMARY
                  echo "- CVE checks on pull requests run in unified_workflow.yml (dependency-review)." >> $GITHUB_STEP_SUMMARY
                  echo "" >> $GITHUB_STEP_SUMMARY
                  echo "### Artifacts" >> $GITHUB_STEP_SUMMARY
                  find reports -type f >> $GITHUB_STEP_SUMMARY

''';
}
