-- Bloom — initial schema (multi-tenant, RLS on every table)
-- Generated 2026-06-26. Idempotent-ish: safe to run on a fresh Supabase project.
--
-- Design notes:
--  * Every user-owned row carries user_id = auth.uid(); RLS enforces strict isolation.
--  * Append-mostly + soft-delete (deleted_at) so offline clients reconcile without losing data.
--  * updated_at maintained by trigger for last-write-wins sync.
--  * "days" is one soft container per calendar day per user; domain rows reference (user_id, day).

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ---------- Enums ----------
do $$ begin
  create type journal_kind as enum ('read','watched','word','proud','improve','thoughts');
exception when duplicate_object then null; end $$;

do $$ begin
  create type money_direction as enum ('spent','earned');
exception when duplicate_object then null; end $$;

do $$ begin
  create type ai_kind as enum ('followup','insight','mirror');
exception when duplicate_object then null; end $$;

do $$ begin
  create type sub_status as enum ('none','trialing','active','grace','expired','canceled');
exception when duplicate_object then null; end $$;

-- ---------- Shared trigger: keep updated_at fresh ----------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ============================================================
-- profiles  (1:1 with auth.users)
-- ============================================================
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  display_name    text,
  locale          text not null default 'en',
  tz              text not null default 'UTC',
  onboarding_done boolean not null default false,
  ai_mode         text not null default 'deep',          -- 'quick' | 'deep'
  plan            text not null default 'free',           -- 'free' | 'premium'
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
drop trigger if exists trg_profiles_updated on profiles;
create trigger trg_profiles_updated before update on profiles
  for each row execute function set_updated_at();

-- Auto-create a profile when a new auth user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- identities  ("Reader", "Saver", ... — votes per save)
-- ============================================================
create table if not exists identities (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label       text not null,
  emoji       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
drop trigger if exists trg_identities_updated on identities;
create trigger trg_identities_updated before update on identities
  for each row execute function set_updated_at();

-- ============================================================
-- days  (one soft container per calendar day per user)
-- ============================================================
create table if not exists days (
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  mood        smallint,            -- 1..5 (Tough..Glowing); null = skipped
  mood_note   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (user_id, day)
);
drop trigger if exists trg_days_updated on days;
create trigger trg_days_updated before update on days
  for each row execute function set_updated_at();

-- ============================================================
-- journal_entries  (the six prompts: read/watched/word/proud/improve/thoughts)
-- ============================================================
create table if not exists journal_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  kind        journal_kind not null,
  payload     jsonb not null default '{}'::jsonb,   -- {source, takeaway} / {word, meaning, sentence} / {body}
  words       integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_journal_user_day on journal_entries(user_id, day);
drop trigger if exists trg_journal_updated on journal_entries;
create trigger trg_journal_updated before update on journal_entries
  for each row execute function set_updated_at();

-- ============================================================
-- thoughts  (free-form)
-- ============================================================
create table if not exists thoughts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  body        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_thoughts_user_day on thoughts(user_id, day);
drop trigger if exists trg_thoughts_updated on thoughts;
create trigger trg_thoughts_updated before update on thoughts
  for each row execute function set_updated_at();

-- ============================================================
-- emotions  (granular feelings)
-- ============================================================
create table if not exists emotions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  emotion     text not null,
  valence     smallint,            -- -2..2 (unpleasant..pleasant)
  energy      smallint,            -- -2..2 (low..high)
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_emotions_user_day on emotions(user_id, day);
drop trigger if exists trg_emotions_updated on emotions;
create trigger trg_emotions_updated before update on emotions
  for each row execute function set_updated_at();

-- ============================================================
-- activities  (lightweight, taggable)
-- ============================================================
create table if not exists activities (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day          date not null,
  title        text not null,
  tags         text[] not null default '{}',
  duration_min integer,
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index if not exists idx_activities_user_day on activities(user_id, day);
drop trigger if exists trg_activities_updated on activities;
create trigger trg_activities_updated before update on activities
  for each row execute function set_updated_at();

-- ============================================================
-- money_entries  (simple manual money log)
-- ============================================================
create table if not exists money_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  direction   money_direction not null,
  amount      numeric(14,2) not null check (amount >= 0),
  currency    text not null default 'KES',
  category    text,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_money_user_day on money_entries(user_id, day);
drop trigger if exists trg_money_updated on money_entries;
create trigger trg_money_updated before update on money_entries
  for each row execute function set_updated_at();

-- ============================================================
-- budgets  (soft monthly limits per category)
-- ============================================================
create table if not exists budgets (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  month        date not null,           -- first day of month
  category     text not null,
  limit_amount numeric(14,2) not null check (limit_amount >= 0),
  currency     text not null default 'KES',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, month, category)
);
drop trigger if exists trg_budgets_updated on budgets;
create trigger trg_budgets_updated before update on budgets
  for each row execute function set_updated_at();

-- ============================================================
-- ai_outputs  (cached AI artifacts, per user)
-- ============================================================
create table if not exists ai_outputs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind        ai_kind not null,
  period      text,                  -- e.g. '2026-W26' or '2026-06' or a day for followups
  content     jsonb not null,
  model       text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_ai_user_kind on ai_outputs(user_id, kind, period);

-- ============================================================
-- subscriptions  (mirrored from store webhooks)
-- ============================================================
create table if not exists subscriptions (
  user_id            uuid primary key references auth.users(id) on delete cascade,
  store              text,            -- 'play' | 'appstore'
  product_id         text,
  status             sub_status not null default 'none',
  current_period_end timestamptz,
  updated_at         timestamptz not null default now()
);
drop trigger if exists trg_subscriptions_updated on subscriptions;
create trigger trg_subscriptions_updated before update on subscriptions
  for each row execute function set_updated_at();

-- ============================================================
-- ROW-LEVEL SECURITY  (enable + owner-only policies on every table)
-- ============================================================
alter table profiles       enable row level security;
alter table identities     enable row level security;
alter table days           enable row level security;
alter table journal_entries enable row level security;
alter table thoughts       enable row level security;
alter table emotions       enable row level security;
alter table activities     enable row level security;
alter table money_entries  enable row level security;
alter table budgets        enable row level security;
alter table ai_outputs     enable row level security;
alter table subscriptions  enable row level security;

-- profiles: keyed by id = auth.uid()
drop policy if exists "profiles_self" on profiles;
create policy "profiles_self" on profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- Helper to apply the standard owner policy to a user_id table.
do $$
declare t text;
begin
  foreach t in array array[
    'identities','days','journal_entries','thoughts','emotions',
    'activities','money_entries','budgets','ai_outputs','subscriptions'
  ] loop
    execute format('drop policy if exists %I on %I', t||'_owner', t);
    execute format(
      'create policy %I on %I for all using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t||'_owner', t
    );
  end loop;
end $$;

-- ============================================================
-- Convenience view: per-user activity heartbeat (for ops/debug; RLS-scoped)
-- ============================================================
create or replace view entries_activity as
select
  d.user_id,
  count(*)                          as days_logged,
  min(d.day)                        as first_day,
  max(d.day)                        as last_day,
  max(d.updated_at)                 as last_activity_at
from days d
group by d.user_id;
