#!/usr/bin/env bash
# Pet Passport — dev helper script
# Usage: ./scripts/dev.sh <command>
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
  cat <<EOF
Pet Passport dev helper

Usage: ./scripts/dev.sh <command>

Commands:
  setup       Full first-time setup: pub get + l10n + codegen
  codegen     Run build_runner once (drift, riverpod, freezed, json)
  watch       Run build_runner in watch mode
  l10n        Generate localizations from lib/l10n/*.arb
  clean       Clean build_runner cache + flutter build artefacts
  reset       Full reset: clean + remove pubspec.lock + setup
  analyze     Run flutter analyze
  test        Run flutter test (unit + widget)
  it          Run integration_test/ (needs emulator/device)
  check       CI-style: analyze + test
  format      Format lib/ and test/ with dart format
  run         flutter run (attach to first connected device)
  outdated    Show outdated packages
  help        Show this help
EOF
}

cmd="${1:-help}"

case "$cmd" in
  setup)
    flutter pub get
    flutter gen-l10n
    dart run build_runner build --delete-conflicting-outputs
    ;;
  codegen|gen)
    dart run build_runner build --delete-conflicting-outputs
    ;;
  watch)
    dart run build_runner watch --delete-conflicting-outputs
    ;;
  l10n)
    flutter gen-l10n
    ;;
  clean)
    dart run build_runner clean
    flutter clean
    ;;
  reset)
    dart run build_runner clean || true
    flutter clean
    rm -f pubspec.lock
    flutter pub get
    flutter gen-l10n
    dart run build_runner build --delete-conflicting-outputs
    ;;
  analyze)
    flutter analyze
    ;;
  test)
    flutter test
    ;;
  it)
    flutter test integration_test/
    ;;
  check)
    flutter analyze
    flutter test
    ;;
  format|fmt)
    dart format lib/ test/
    ;;
  run)
    flutter run
    ;;
  outdated)
    flutter pub outdated
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo
    usage
    exit 1
    ;;
esac
