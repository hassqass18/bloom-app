# Bloom — Setup & Run

## Toolchain (already installed on this machine)
- **Flutter SDK:** `C:\Users\swozz\Documents\flutter-sdk` (add `…\flutter-sdk\bin` to PATH)
- **Android SDK:** `C:\Users\swozz\Android\sdk` (set via `flutter config --android-sdk`)
- **JDK 17:** `C:\Users\swozz\jdk17` (set via `flutter config --jdk-dir` — required because system Java 25 is too new for the Android Gradle Plugin)
- Node 24 + npm (for the Supabase CLI via `npx`)

Verify: `flutter doctor` (Android toolchain should be ✓).

## Run the app

### Local-only mode (no account, full offline capture)
```bash
cd app
flutter pub get
flutter run            # pick a device; works with zero cloud config
```

### With cloud (accounts + sync + AI)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Build the APK
```bash
cd app
flutter build apk --debug      # → build/app/outputs/flutter-apk/app-debug.apk
# release (needs a signing keystore — see Implementation Plan Stage 0.7):
flutter build apk --release
flutter build appbundle --release   # .aab for the Play Store
```
Install the debug APK on a device: `flutter install` or copy the `.apk` to the phone.

## Backend (Supabase)
See [`../backend/README.md`](../backend/README.md). Quick version:
```bash
cd backend
npx supabase start            # local stack (needs Docker)
npx supabase db reset         # apply migrations + seed
# RLS isolation test:
psql "$(npx supabase status -o json | jq -r .DB_URL)" -f supabase/tests/rls_test.sql
# deploy AI functions:
npx supabase functions deploy ask notice mirror
npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

## What works today (Phase 1 + early Phase 2/3)
- Offline-first capture of every domain (mood, 6 journal prompts, feeling, activity, money) — Today tab
- Voice dictation into any text field (on-device speech-to-text)
- Timeline of logged days
- Money tab (monthly spend/earn + category bars)
- Insights tab (local trends + AI "What I'm noticing" when signed in)
- Email one-time-passcode auth; two-way sync (push + pull) with Supabase
- First-run onboarding (identities + AI mode)
- `flutter analyze` clean · unit tests pass

## Next
Release signing + Play internal-testing track, then beta. See the AI Memory repo:
`projects/staging/Bloom/Implementation-Plan/` and `Build-Plan/`.
