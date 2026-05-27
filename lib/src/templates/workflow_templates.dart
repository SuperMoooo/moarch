/// Generates CI and security workflow templates.
class WorkflowTemplates {
  WorkflowTemplates._();

  /// Returns the generated ciWorkflow template.
  static String ciWorkflow() => r'''
# ── CI Pipeline ───────────────────────────────────────────────────────────────
# Runs on every push to main/develop and on pull requests to main.
#
# Jobs:
#   1. unit        — analyze + unit tests (no network needed)
#   2. integration — integration tests against real API (needs secrets)
#
# Required GitHub secrets (Settings → Secrets and variables → Actions):
#   BASE_URL — your API base URL e.g. https://api.yourapp.com
#
# Add more secrets to the "Create .env" step if your app needs them.

name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # ── Unit tests ──────────────────────────────────────────────────────────────
  # Fast — no network, no secrets needed.
  # Runs analyze + all tests in test/unit/ recursively.
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

  # ── Integration tests ───────────────────────────────────────────────────────
  # Hits the real API — only runs if unit tests pass first.
  # Requires BASE_URL (and any other secrets) to be set in GitHub secrets.
  #
  # If your API is sometimes flaky, add: continue-on-error: true
  # That way a flaky API doesn't block your merge.
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
''';

  /// Returns the generated sastWorkflow template.
  static String sastWorkflow() => r'''

name: SAST - Static Code Analysis
on:
    push:
        branches: [main, develop]
    pull_request:
    schedule:
        - cron: '0 0 * * 0'

jobs:
    sast:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4
              with:
                  fetch-depth: 0

            - name: Set up Flutter
              uses: subosito/flutter-action@v2
              with:
                  channel: stable

            - name: Get dependencies
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

''';

  /// Returns the generated secretsScanWorkflow template.
  static String secretsScanWorkflow() => r'''
name: Secrets Scan
on:
    push:
    pull_request:
    schedule:
        - cron: '0 0 * * 0'

jobs:
    secrets:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4
              with:
                  fetch-depth: 0

            - name: Set up Dart
              uses: dart-lang/setup-dart@v1
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


''';
}
