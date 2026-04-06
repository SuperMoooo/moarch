class CiTemplates {
  CiTemplates._();

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
}
