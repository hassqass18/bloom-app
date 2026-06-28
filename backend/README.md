# Bloom — Backend (Supabase)

Multi-tenant Postgres + Auth + Edge Functions for the Bloom app. **Row-Level Security is enabled on every user table** — a user can only ever read/write their own rows.

## Layout
```
backend/supabase/
├── config.toml              # local CLI config
├── migrations/
│   └── 0001_init.sql        # full schema + RLS + triggers
├── tests/
│   └── rls_test.sql         # proves cross-user isolation
├── seed.sql                 # (placeholder)
└── functions/               # Deno Edge Functions (AI layer)
    ├── _shared/anthropic.ts # Claude client + Bloom voice + CORS
    ├── ask/                 # one warm follow-up (Haiku)
    ├── notice/              # weekly "What I'm noticing" (Sonnet)
    └── mirror/              # monthly private mirror (Sonnet)
```

## Run locally
Prereqs: [Supabase CLI](https://supabase.com/docs/guides/cli) (`npm i -g supabase` or `npx supabase`), Docker.

```bash
cd backend
npx supabase start                 # boots local Postgres + Auth + Studio
npx supabase db reset              # applies migrations/0001_init.sql + seed
# verify RLS isolation:
psql "$(npx supabase status -o json | jq -r .DB_URL)" -f supabase/tests/rls_test.sql
```

## Edge Functions
Each function needs `ANTHROPIC_API_KEY` (and `SUPABASE_URL` / `SUPABASE_ANON_KEY` for notice & mirror) in its env.

```bash
npx supabase functions serve ask --env-file ./.env.local
# deploy:
npx supabase functions deploy ask notice mirror
npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

`.env.local` (DO NOT COMMIT):
```
ANTHROPIC_API_KEY=sk-ant-...
SUPABASE_URL=https://<ref>.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

## Cloud setup (staging/prod)
1. Create a Supabase project (region nearest users: `af-south-1` / `eu-central-1`).
2. `npx supabase link --project-ref <ref>` then `npx supabase db push`.
3. Configure Auth providers (email + Google now; Apple for iOS later) in the dashboard.
4. `npx supabase functions deploy ask notice mirror` and set the `ANTHROPIC_API_KEY` secret.

## Privacy note
AI functions send the user's own entries to Anthropic **only when the user has AI enabled (Deep mode)**. Quick mode performs zero third-party processing. Functions fail closed (return empty) so AI can never block the core experience.
