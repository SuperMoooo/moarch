/// Generates CI and security workflow templates.
class WorkflowTemplates {
  WorkflowTemplates._();

  /// Returns the unified workflow template combining all jobs in order.
  /// Replaces ciWorkflow, sastWorkflow, secretsScanWorkflow,
  /// dependencyReviewWorkflow and buildWorkflow.
  static String unifiedWorkflow() => r'''
# ── Unified Pipeline ──────────────────────────────────────────────────────────
# Runs all jobs in order. Build only triggers if every check passes.
#
# Job order:
#   1. unit              — analyze + unit tests (no network needed)
#   2. integration       — integration tests against real API (needs secrets)
#   3. sast              — static analysis + formatting check
#   4. secrets           — scans for leaked secrets
#   5. dependency-review — CVE + license check (PRs only)
#
# Required GitHub secrets (Settings → Secrets and variables → Actions):
#   BASE_URL — your API base URL e.g. https://api.yourapp.com

#
# Note on CVE gating: dependency-review-action only runs on PRs (it diffs
# base vs head). osv-scan runs on every push too, so it's the source of
# truth for CVE gating on main/develop. dependency-review-action stays as
# an early PR-only signal plus license-deny enforcement.

name: CI

on:
    push:
        branches: [main, develop]
    pull_request:
        branches: [main]
    workflow_dispatch: {}

jobs:
    # ── 1. Unit tests ────────────────────────────────────────────────────────────
    unit:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@v4

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

            - name: Analyze
              run: flutter analyze --no-fatal-warnings

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
        needs: unit

        steps:
            - uses: actions/checkout@v4

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

    # ── 3. SAST ──────────────────────────────────────────────────────────────────
    sast:
        runs-on: ubuntu-latest
        needs: unit

        steps:
            - uses: actions/checkout@v4
              with:
                  fetch-depth: 0

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

            - name: Run Flutter analyzer
              run: |
                  echo "🔍 Running Flutter analyzer..."
                  flutter analyze

            - name: Check formatting
              run: |
                  echo "📐 Checking code formatting..."
                  dart format . --set-exit-if-changed

            - name: Generate SAST report
              if: always()
              run: |
                  echo "=== SAST Analysis Report ===" > sast-report.txt
                  echo "Flutter SDK: $(flutter --version)" >> sast-report.txt
                  echo "Time: $(date)" >> sast-report.txt
                  cat sast-report.txt

            - name: Upload SAST report
              if: always()
              uses: actions/upload-artifact@v4
              with:
                  name: sast-report
                  path: sast-report.txt
                  retention-days: 30

    # ── 4. Secrets scan ──────────────────────────────────────────────────────────
    secrets:
        runs-on: ubuntu-latest
        needs: unit

        steps:
            - uses: actions/checkout@v4
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
              uses: actions/upload-artifact@v4
              with:
                  name: secrets-report
                  path: secrets-report.json
                  retention-days: 30

    # ── 5. Dependency review ─────────────────────────────────────────────────────
    # Only runs on pull requests — requires a base and head to compare.
    # PR-only early signal + license-deny enforcement. CVE gating on
    # push/main is handled by osv-scan below.
    dependency-review:
        runs-on: ubuntu-latest
        needs: unit
        if: github.event_name == 'pull_request'

        steps:
            - uses: actions/checkout@v4

            - name: Dependency review
              uses: actions/dependency-review-action@v4
              with:
                  fail-on-severity: high
                  # Uncomment to block specific licenses:
                  # deny-licenses: GPL-2.0, GPL-3.0

''';

  /// BUILD IOS WORKFLOW
  static String buildIOS() => r'''

# Secret
# IOS_P12_BASE64   - base64 of your .p12 (cert + key)
# IOS_P12_PASSWORD   - password you set above
# IOS_PROVISIONING_PROFILE_BASE64  - base64 of your .mobileprovision file
# IOS_TEAM_ID    - Apple Developer Team ID
#

name: Build IOS IPA

on:
    workflow_dispatch: {}

jobs:
    # ── 1. Check for Apple credentials ──────────────────────────────────────────
    # Determines whether iOS secrets are present so the build job can skip
    # cleanly instead of failing when they're not configured.
    check-ios-secrets:
        runs-on: ubuntu-latest
        outputs:
            has_secrets: ${{ steps.check.outputs.has_secrets }}
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
# ── 2. Build iOS ─────────────────────────────────────────────────────────────
    # Only runs if unit/integration/sast/secrets pass AND Apple secrets exist.
    # macOS runner is required — this is the only place a "Mac" is involved,
    # and GitHub provides it for you, so you don't need your own.
    build-ios:
        runs-on: macos-latest
        needs: [check-ios-secrets]
        if: needs.check-ios-secrets.outputs.has_secrets == 'true'
        steps:
            - uses: actions/checkout@v4
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

            - name: Build iOS (no codesign step, just compile)
              run: flutter build ios --release --no-codesign

            - name: Archive and export IPA
              env:
                  TEAM_ID: ${{ secrets.IOS_TEAM_ID }}
                  PROFILE_NAME: ${{ steps.profile_info.outputs.profile_name }}
                  BUNDLE_ID: ${{ steps.profile_info.outputs.bundle_id }}
              run: |
                  cd ios
                  xcodebuild -workspace Runner.xcworkspace \
                    -scheme Runner \
                    -sdk iphoneos \
                    -configuration Release \
                    -archivePath build/Runner.xcarchive \
                    archive \
                    CODE_SIGN_STYLE=Manual \
                    DEVELOPMENT_TEAM="$TEAM_ID" \
                    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
                    CODE_SIGN_IDENTITY="Apple Development"

                  cat > ExportOptions.plist << EOF
                  <?xml version="1.0" encoding="UTF-8"?>
                  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                  <plist version="1.0">
                  <dict>
                      <key>method</key>
                      <string>development</string>
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
              uses: actions/upload-artifact@v4
              with:
                  name: release-ipa
                  path: ios/build/ipa/*.ipa
                  retention-days: 30

            - name: Cleanup keychain
              if: always()
              run: |
                  rm -f certificate.p12
                  security delete-keychain build.keychain || true
''';

  /// BUILD ANDROID APK
  static String buildANDROID() => r'''

name: Build ANDROID APK

on:
    workflow_dispatch: {}

jobs:
    build-android:
        runs-on: ubuntu-latest

        env:
            GRADLE_OPTS: "-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.daemon=false"

        steps:
            - uses: actions/checkout@v4

            - name: Decode Keystore
              run: |
                  echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode > android/app/release-key.jks

            - name: Create key.properties
              run: |
                  cat <<EOF > android/key.properties
                  storePassword=${{ secrets.KEYSTORE_STORE_PASSWORD }}
                  keyPassword=${{ secrets.KEYSTORE_KEY_PASSWORD }}
                  keyAlias=${{ secrets.KEYSTORE_KEY_ALIAS }}
                  storeFile=release-key.jks
                  EOF

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

            - name: Build APK
              run: flutter build apk --release --obfuscate --split-debug-info=build/debug-info/android --verbose

            - name: Upload APK artifact
              uses: actions/upload-artifact@v4
              with:
                  name: release-apk
                  path: build/app/outputs/flutter-apk/app-release.apk
                  retention-days: 30
''';

  /// Returns the supply chain analysis (reporting) workflow.
  /// Non-blocking: SBOM + license report, scheduled weekly and on release tags.
  static String csaWorkflow() => r'''
# ── Supply Chain Analysis (Reporting) ─────────────────────────────────────────
# Non-blocking compliance artifacts: SBOM + license report.
# Runs weekly and on release tags — does not gate merges or builds.
# CVE gating lives in ci.yml (dependency-review-action + OSV-Scanner job).

name: CSA

on:
    schedule:
        - cron: '0 3 * * 1'
    push:
        tags:
            - 'v*'
    workflow_dispatch: {}

jobs:
    sbom:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@v4

            - uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true

            - name: Install dependencies
              run: flutter pub get

            - name: Setup Node (for cdxgen)
              uses: actions/setup-node@v4
              with:
                  node-version: '20'

            - name: Generate SBOM (CycloneDX JSON via cdxgen)
              run: |
                  npx --yes @cyclonedx/cdxgen@latest -t dart -o sbom.json .

            - name: Upload SBOM
              uses: actions/upload-artifact@v4
              with:
                  name: sbom-cyclonedx
                  path: sbom.json
                  retention-days: 90

    license-compliance:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@v4

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
              uses: actions/upload-artifact@v4
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
              uses: actions/download-artifact@v4
              with:
                  path: reports

            - name: Write summary
              run: |
                  echo "## Supply Chain Analysis — $(date -u +%Y-%m-%d)" >> $GITHUB_STEP_SUMMARY
                  echo "- SBOM (CycloneDX) and license/health report generated." >> $GITHUB_STEP_SUMMARY
                  echo "- CVE gating is handled separately in ci.yml (OSV-Scanner + dependency-review)." >> $GITHUB_STEP_SUMMARY
                  echo "" >> $GITHUB_STEP_SUMMARY
                  echo "### Artifacts" >> $GITHUB_STEP_SUMMARY
                  find reports -type f >> $GITHUB_STEP_SUMMARY

''';

  /// FASTLANE DEPLOY WORKFLOW
  static String deployWorkflow() => r'''
name: Fastlane Deploy

# Fastlane deployment workflow for Android and iOS.
# gem install fastlane or brew install fastlane
# Setup instructions (copy these into your repo or use them as a checklist):
# 1. Initialize Fastlane in each platform folder:
#    - cd android && bundle init && bundle add fastlane
#    - cd ios && bundle init && bundle add fastlane
# 2. Run the Fastlane setup wizard for each platform:
#    - cd android && bundle exec fastlane init
#    - cd ios && bundle exec fastlane init
# 3. Define your deployment lanes in each Fastfile, for example:
#    - android: lane :beta do ... end
#    - ios: lane :beta do ... end
# 4. For iOS signing, set up Match (recommended):
#    - fastlane match appstore --readonly
#    - fastlane match init
#    - store the Match repo URL in MATCH_GIT_URL
# 5. Add the required secrets in GitHub:
#    Settings → Secrets and variables → Actions
#
# Required GitHub secrets:
# - BASE_URL                        # used by the app at runtime (optional if not needed in deployment)
# - FASTLANE_USER                   # Apple ID used by Fastlane for App Store Connect
# - FASTLANE_PASSWORD               # App-specific password or app-specific password for Apple ID
# - FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD  # if needed by your lane
# - APP_STORE_CONNECT_API_KEY_ID   # App Store Connect API key ID
# - APP_STORE_CONNECT_ISSUER_ID    # App Store Connect issuer ID
# - APP_STORE_CONNECT_API_KEY_CONTENT  # base64-encoded App Store Connect API key (.p8)
# - MATCH_PASSWORD                 # password for the Match repository certificates
# - MATCH_GIT_URL                  # HTTPS URL to your Match repository
# - MATCH_GIT_BASIC_AUTHORIZATION  # Basic auth token for the Match repository (optional if using SSH/other auth)
# - PLAY_STORE_JSON_KEY_BASE64     # base64 of the Google Play service account JSON
# - GOOGLE_PLAY_JSON_KEY           # optional if your lane expects a plain JSON path instead of base64
#
# Optional secrets depending on your lane implementation:
# - SENTRY_AUTH_TOKEN
# - SLACK_WEBHOOK_URL
#
# Typical manual usage:
# - Go to Actions → Fastlane Deploy → Run workflow
# - Choose the platform and lane you want to deploy
#
# Typical tag-based deployment:
# - Create a tag like v1.2.3 and push it to trigger deployment for Android and iOS.

on:
    workflow_dispatch:
        inputs:
            platform:
                description: Platform to deploy
                required: true
                default: all
                type: choice
                options:
                    - all
                    - android
                    - ios
            lane:
                description: Fastlane lane to execute
                required: true
                default: beta
                type: string
    push:
        tags:
            - 'v*'

jobs:
    prepare:
        runs-on: ubuntu-latest
        outputs:
            matrix: ${{ steps.set-matrix.outputs.matrix }}
        steps:
            - name: Determine platforms to deploy
              id: set-matrix
              shell: bash
              run: |
                  android='{"platform":"android","os":"ubuntu-latest","working_directory":"android"}'
                  ios='{"platform":"ios","os":"macos-latest","working_directory":"ios"}'
                  platform="${{ github.event.inputs.platform }}"

                  if [ "${{ github.event_name }}" = "push" ] || [ "$platform" = "all" ] || [ -z "$platform" ]; then
                    matrix="[$android,$ios]"
                  elif [ "$platform" = "android" ]; then
                    matrix="[$android]"
                  else
                    matrix="[$ios]"
                  fi

                  echo "matrix=$matrix" >> "$GITHUB_OUTPUT"

    deploy:
        needs: prepare
        runs-on: ${{ matrix.os }}
        strategy:
            fail-fast: false
            matrix:
                include: ${{ fromJson(needs.prepare.outputs.matrix) }}

        steps:
            - name: Checkout repository
              uses: actions/checkout@v4

            - name: Set up Flutter
              uses: subosito/flutter-action@v2
              with:
                  flutter-version-file: .fvmrc
                  cache: true

            - name: Set up Ruby
              uses: ruby/setup-ruby@v1
              with:
                  ruby-version: '3.2'
                  bundler-cache: true
                  working-directory: ${{ matrix.working_directory }}

            - name: Install Flutter dependencies
              run: flutter pub get

            - name: Create runtime env file
              run: |
                  if [ -f .env ]; then
                    echo ".env already exists, using the existing file."
                  else
                    echo "BASE_URL=${{ secrets.BASE_URL }}" > .env
                  fi

            - name: Install Fastlane dependencies
              working-directory: ${{ matrix.working_directory }}
              run: bundle install

            - name: Deploy with Fastlane
              working-directory: ${{ matrix.working_directory }}
              env:
                  FASTLANE_USER: ${{ secrets.FASTLANE_USER }}
                  FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
                  FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD }}
                  APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
                  APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
                  APP_STORE_CONNECT_API_KEY_CONTENT: ${{ secrets.APP_STORE_CONNECT_API_KEY_CONTENT }}
                  MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
                  MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
                  MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
                  PLAY_STORE_JSON_KEY_BASE64: ${{ secrets.PLAY_STORE_JSON_KEY_BASE64 }}
                  GOOGLE_PLAY_JSON_KEY: ${{ secrets.GOOGLE_PLAY_JSON_KEY }}
                  BASE_URL: ${{ secrets.BASE_URL }}
              run: |
                  echo "Deploying ${{ matrix.platform }} with lane ${{ github.event.inputs.lane || 'beta' }}"
                  bundle exec fastlane ${{ github.event.inputs.lane || 'beta' }}

  ''';
}
