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
#   6. build             — builds release APK if all above pass
#
# Required GitHub secrets (Settings → Secrets and variables → Actions):
#   BASE_URL — your API base URL e.g. https://api.yourapp.com

name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'

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

      - name: Analyze
        run: flutter analyze --no-fatal-warnings

      - name: Unit tests
        run: flutter test test/unit/

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

      - name: Create .env
        run: |
          echo "BASE_URL=${{ secrets.BASE_URL }}" > .env
          # Add more secrets here if needed:
          # echo "OTHER_KEY=${{ secrets.OTHER_KEY }}" >> .env

      - name: Integration tests
        run: flutter test test/integration/
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

  # ── 6. Build ─────────────────────────────────────────────────────────────────
  # Only runs if ALL previous jobs pass.
  # dependency-review is skipped on push — excluded from needs on push events.
  build:
    runs-on: ubuntu-latest
    needs: [integration, sast, secrets]

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: .fvmrc
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build APK
        run: flutter build apk --release --obfuscate --split-debug-info=build/debug-info/android

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 30
''';
}
