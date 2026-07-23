# Pet Passport — Local Setup

## Requirements
- Flutter 3.44+ (Dart 3.12+)
- Android SDK + Emulator (or a physical Android device with USB debugging)

## Quick reference: dev helper

All common tasks are wrapped in `scripts/dev.sh`:

```bash
./scripts/dev.sh setup       # first-time / fresh clone
./scripts/dev.sh codegen     # rebuild drift / freezed / riverpod / json after schema edits
./scripts/dev.sh watch       # keep codegen running while editing
./scripts/dev.sh l10n        # regenerate localizations only
./scripts/dev.sh clean       # clear build_runner + flutter caches
./scripts/dev.sh reset       # full nuclear reset (removes lockfile, rebuilds everything)
./scripts/dev.sh analyze     # flutter analyze
./scripts/dev.sh test        # unit + widget tests
./scripts/dev.sh it          # integration tests (needs emulator/device)
./scripts/dev.sh check       # analyze + test (pre-commit)
./scripts/dev.sh format      # dart format lib/ test/
./scripts/dev.sh run         # flutter run
./scripts/dev.sh outdated    # list outdated deps
./scripts/dev.sh help        # show all commands
```

## First-time setup

```bash
./scripts/dev.sh setup
```

Under the hood this runs:
- `flutter pub get`
- `flutter gen-l10n` (generates `lib/l10n/generated/app_l10n.dart` from `lib/l10n/*.arb`)
- `dart run build_runner build --delete-conflicting-outputs` (generates `.g.dart` files for Drift, DAOs, and any Freezed/JSON models added later)

## Running the app

```bash
./scripts/dev.sh run
# or plain: flutter run
```

First launch shows the onboarding flow. Complete it to reach the pet list.

### Cloud mode (M1+, optional)

The app runs in pure-local mode by default. To activate cloud features
(household sharing, sync), pass the Supabase project credentials at build
time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-id>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Both values come from the Supabase dashboard under
**Project Settings → API**. Use the **Publishable key** (safe for client
use, respects RLS), never the **Secret key**. When both env vars are
empty at build time, the app boots exactly like before — no cloud client
is initialized. Same command for `flutter build apk` / `flutter build
appbundle`.

## Common edit-cycles

- **Changed a Drift table** → `./scripts/dev.sh codegen`
- **Added/edited an ARB key** → `./scripts/dev.sh l10n`
- **Actively editing generated code** → run `./scripts/dev.sh watch` in one terminal, keep editing

## Troubleshooting

- **`AppL10n` not found / `lib/l10n/generated/app_l10n.dart` missing** → `./scripts/dev.sh l10n`
- **`Target of URI hasn't been generated: '*.g.dart'`** → `./scripts/dev.sh codegen`
- **Drift schema mismatch after table change** → `./scripts/dev.sh codegen`
- **Photo picker crashes on Android emulator** → use gallery source; the emulator's camera often needs manual setup
- **Codegen loops / stuck / wrong output** → `./scripts/dev.sh reset`

## Pre-commit checklist

```bash
./scripts/dev.sh format
./scripts/dev.sh check
```
