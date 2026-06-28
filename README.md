# Bloom 🌸

> *"Your days, growing into something you can see."*

Bloom is a warm, offline-first personal life-log — one calm app for journaling, thoughts, feelings, daily activities, and a simple budget — with an optional, privacy-first AI companion. Android-first (Flutter), backed by Supabase, launching on the Play Store.

This is the commercial product spun out of the `Daily-Learning-Journal` prototype. Planning docs live in the AI Memory repo under `projects/staging/Bloom/`.

## Monorepo layout
```
bloom/
├── app/        Flutter client (Android · iOS · web) — offline-first capture + sync
├── backend/    Supabase: Postgres + RLS schema, AI Edge Functions (Deno)
├── docs/       Setup + engineering notes
└── .github/    CI (analyze + test; APK build)
```

## Status (Phase 1 — Capture Core)
- ✅ Multi-tenant Postgres schema with **RLS on every table** (`backend/supabase/migrations/0001_init.sql`)
- ✅ AI Edge Functions: `/ask` (follow-up), `/notice` (weekly insight), `/mirror` (monthly) — fail-closed, key server-side
- ✅ Flutter app: offline-first local store (sqflite), capture surface for **all domains** (mood, 6 journal prompts, feeling, activity, money), timeline, email-OTP auth, outbound sync engine
- ✅ `flutter analyze` clean · unit tests pass
- ⏭️ Next: pull-sync + onboarding, voice capture, Money/Insights tabs, billing, then first Play internal-testing APK

## Quick start
See [docs/SETUP.md](docs/SETUP.md). TL;DR:
```bash
# App (runs in local-only mode with no creds — full offline capture works)
cd app && flutter pub get && flutter run

# With cloud (accounts + sync):
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Design principles (carried from the prototype)
Warm, slow, permission-giving. **No streaks, no guilt, no nags.** Identity over metric. AI is optional and never blocks a save. Privacy by construction (RLS; no entry content in telemetry).
