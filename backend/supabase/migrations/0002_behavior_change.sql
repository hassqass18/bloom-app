-- Bloom v2 — behavior-change engine schema.
-- Adds: goals + tiny if-then steps, adaptive sessions, validated measures,
-- reinforcement log, longitudinal memory profile, granular consent ledger,
-- tunable reminders, and opt-in passive signals.
-- Same conventions as 0001: user_id = auth.uid(), updated_at trigger,
-- soft-delete (deleted_at), RLS on every table. Additive & non-destructive.

-- ---------- Enums ----------
do $$ begin
  create type goal_stage as enum
    ('precontemplation','contemplation','preparation','action','maintenance');
exception when duplicate_object then null; end $$;

do $$ begin
  create type goal_status as enum ('active','paused','done','dropped');
exception when duplicate_object then null; end $$;

do $$ begin
  create type com_b_factor as enum
    ('capability','opportunity','motivation','reflection');
exception when duplicate_object then null; end $$;

do $$ begin
  create type measure_instrument as enum ('who5','phq9','gad7','custom');
exception when duplicate_object then null; end $$;

do $$ begin
  create type reinforce_kind as enum ('celebrate','nudge','replan','insight');
exception when duplicate_object then null; end $$;

do $$ begin
  create type passive_source as enum ('money','location','screen');
exception when duplicate_object then null; end $$;

do $$ begin
  create type consent_scope as enum ('ai','money','location','screen','measures');
exception when duplicate_object then null; end $$;

-- ============================================================
-- goals  (the "definite" goal — Goal-Setting Theory + WOOP + values)
-- ============================================================
create table if not exists goals (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid() references auth.users(id) on delete cascade,
  wish               text not null,                 -- broad, in the user's words
  definite_statement text not null,                 -- specific + measurable + time-bound
  domain             text,                          -- money, movement, family, reading, ...
  metric             text,                          -- what we count
  target_value       numeric(14,2),                 -- the number to reach
  unit               text,                          -- %, KES, times/week, minutes...
  cadence            text,                          -- daily, weekly, monthly
  value_anchor       text,                          -- identity/value this serves (ACT)
  obstacles          jsonb not null default '[]'::jsonb,  -- WOOP obstacles
  stage              goal_stage not null default 'preparation',
  status             goal_status not null default 'active',
  start_date         date not null default (now() at time zone 'utc')::date,
  target_date        date,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz
);
create index if not exists idx_goals_user on goals(user_id, status);
drop trigger if exists trg_goals_updated on goals;
create trigger trg_goals_updated before update on goals
  for each row execute function set_updated_at();

-- ============================================================
-- goal_steps  (tiny, Fogg-sized if-then implementation intentions)
-- ============================================================
create table if not exists goal_steps (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  goal_id        uuid not null references goals(id) on delete cascade,
  title          text not null,
  if_cue         text,                  -- "If it's 9pm and I open TikTok..."
  then_action    text,                  -- "...then I write one Bloom line"
  anchor_routine text,                  -- existing habit it's anchored to (Tiny Habits)
  bct_id         text,                  -- BCTTv1 technique id, for auditability
  order_idx      integer not null default 0,
  status         goal_status not null default 'active',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);
create index if not exists idx_steps_goal on goal_steps(user_id, goal_id);
drop trigger if exists trg_steps_updated on goal_steps;
create trigger trg_steps_updated before update on goal_steps
  for each row execute function set_updated_at();

-- ============================================================
-- step_logs  (daily adherence -> automaticity / consistency)
-- ============================================================
create table if not exists step_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  step_id     uuid not null references goal_steps(id) on delete cascade,
  day         date not null,
  done        boolean not null default true,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_steplogs_user_day on step_logs(user_id, day);
drop trigger if exists trg_steplogs_updated on step_logs;
create trigger trg_steplogs_updated before update on step_logs
  for each row execute function set_updated_at();

-- ============================================================
-- sessions  (one adaptive daily check-in instance)
-- ============================================================
create table if not exists sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  mode        text not null default 'adaptive',   -- adaptive | quick
  summary     text,
  mood        smallint,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_sessions_user_day on sessions(user_id, day);
drop trigger if exists trg_sessions_updated on sessions;
create trigger trg_sessions_updated before update on sessions
  for each row execute function set_updated_at();

-- ============================================================
-- session_turns  (the calibrated Q&A trail — MI/OARS + Socratic)
-- ============================================================
create table if not exists session_turns (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_id   uuid not null references sessions(id) on delete cascade,
  q_id         text,
  question     text not null,
  answer       text,
  com_b_factor com_b_factor,
  change_talk  boolean not null default false,
  order_idx    integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index if not exists idx_turns_session on session_turns(user_id, session_id);
drop trigger if exists trg_turns_updated on session_turns;
create trigger trg_turns_updated before update on session_turns
  for each row execute function set_updated_at();

-- ============================================================
-- questions  (adaptive question bank — seeded; shared, read-only to clients)
-- ============================================================
create table if not exists questions (
  id            uuid primary key default gen_random_uuid(),
  key           text unique not null,
  domain        text,
  com_b_factor  com_b_factor,
  stage         goal_stage,
  scale_ref     text,
  text          text not null,
  follow_up_hint text,
  weight        numeric not null default 1.0,
  created_at    timestamptz not null default now()
);

-- ============================================================
-- measures  (validated wellbeing check-ins — MBC/ROM)
-- ============================================================
create table if not exists measures (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  instrument  measure_instrument not null,
  day         date not null,
  score       numeric,
  items       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_measures_user_day on measures(user_id, instrument, day);
drop trigger if exists trg_measures_updated on measures;
create trigger trg_measures_updated before update on measures
  for each row execute function set_updated_at();

-- ============================================================
-- reinforcements  (the ethical "push" — celebrate / nudge / replan)
-- ============================================================
create table if not exists reinforcements (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day          date not null,
  kind         reinforce_kind not null,
  text         text not null,
  goal_id      uuid references goals(id) on delete set null,
  source       text,                  -- 'ai' | 'rules'
  delivered_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index if not exists idx_reinf_user_day on reinforcements(user_id, day);
drop trigger if exists trg_reinf_updated on reinforcements;
create trigger trg_reinf_updated before update on reinforcements
  for each row execute function set_updated_at();

-- ============================================================
-- memory_profile  (longitudinal "pocket therapist" memory — one row per user)
-- ============================================================
create table if not exists memory_profile (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  summary     jsonb not null default '{}'::jsonb,
  core_values jsonb not null default '[]'::jsonb,
  patterns    jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  unique (user_id)
);
drop trigger if exists trg_memory_updated on memory_profile;
create trigger trg_memory_updated before update on memory_profile
  for each row execute function set_updated_at();

-- ============================================================
-- consents  (granular, revocable consent ledger — privacy by design)
-- ============================================================
create table if not exists consents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  scope       consent_scope not null,
  granted     boolean not null default false,
  granted_at  timestamptz,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  unique (user_id, scope)
);
drop trigger if exists trg_consents_updated on consents;
create trigger trg_consents_updated before update on consents
  for each row execute function set_updated_at();

-- ============================================================
-- reminders  (tunable, skippable nudges — no streaks, no coercion)
-- ============================================================
create table if not exists reminders (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind          text not null,         -- daily_session | step | measure
  schedule      text,                  -- HH:mm or cron-ish
  enabled       boolean not null default true,
  last_fired_at timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);
drop trigger if exists trg_reminders_updated on reminders;
create trigger trg_reminders_updated before update on reminders
  for each row execute function set_updated_at();

-- ============================================================
-- passive_signals  (opt-in money/location/screen — off by default)
-- ============================================================
create table if not exists passive_signals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source      passive_source not null,
  kind        text,
  value       jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now(),
  reconciled  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_passive_user on passive_signals(user_id, source);
drop trigger if exists trg_passive_updated on passive_signals;
create trigger trg_passive_updated before update on passive_signals
  for each row execute function set_updated_at();

-- ============================================================
-- ROW-LEVEL SECURITY
-- ============================================================
alter table goals           enable row level security;
alter table goal_steps      enable row level security;
alter table step_logs       enable row level security;
alter table sessions        enable row level security;
alter table session_turns   enable row level security;
alter table measures        enable row level security;
alter table reinforcements  enable row level security;
alter table memory_profile  enable row level security;
alter table consents        enable row level security;
alter table reminders       enable row level security;
alter table passive_signals enable row level security;
alter table questions       enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'goals','goal_steps','step_logs','sessions','session_turns','measures',
    'reinforcements','memory_profile','consents','reminders','passive_signals'
  ] loop
    execute format('drop policy if exists %I on %I', t||'_owner', t);
    execute format(
      'create policy %I on %I for all using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t||'_owner', t
    );
  end loop;
end $$;

-- questions are shared reference data: any authenticated user may read.
drop policy if exists questions_read on questions;
create policy questions_read on questions
  for select using (auth.role() = 'authenticated');

-- ============================================================
-- Seed the adaptive question bank (idempotent on key)
-- ============================================================
insert into questions (key, domain, com_b_factor, stage, scale_ref, text, follow_up_hint, weight) values
  ('open_today',      null,        'reflection',  'action',        null, 'How did today actually go for you?', 'reflect their feeling back warmly', 1.0),
  ('goal_progress',   null,        'reflection',  'action',        null, 'Thinking about your goal, what did you actually do toward it today?', 'name the concrete action', 1.2),
  ('cap_blocker',     null,        'capability',  'preparation',   null, 'What part of this feels hard to actually do?', 'is the step too big? shrink it', 1.1),
  ('opp_context',     null,        'opportunity', 'preparation',   null, 'When in your day would this realistically fit?', 'anchor to an existing routine', 1.1),
  ('mot_why',         null,        'motivation',  'contemplation', null, 'What would it mean for you if this changed?', 'evoke their own reason (change talk)', 1.3),
  ('obstacle',        null,        'reflection',  'preparation',   null, 'What got in the way, if anything?', 'turn it into an if-then plan', 1.1),
  ('money_spend',     'money',     'reflection',  'action',        null, 'How did spending feel today — aligned with what you want, or not quite?', 'no judgment', 0.9),
  ('movement',        'movement',  'opportunity', 'action',        null, 'Did your body get to move today?', 'gentle', 0.8),
  ('family',          'family',    'reflection',  'action',        null, 'Did you get any time with the people who matter to you?', 'warm', 0.8),
  ('reading',         'reading',   'capability',  'action',        null, 'Did you read or learn anything today, even a little?', 'celebrate small', 0.8),
  ('screen',          'screen',    'reflection',  'action',        null, 'Was your screen time more constructive or more numbing today?', 'curious not shaming', 0.8),
  ('rest',            'rest',      'reflection',  'action',        null, 'Did you give yourself any kind of break or rest?', 'permission to rest', 0.8),
  ('outburst',        'emotions',  'reflection',  'action',        null, 'Were there moments today where your emotions ran ahead of you?', 'gentle, opens a thought-record', 0.9),
  ('win',             null,        'motivation',  'maintenance',   null, 'What is one small thing you are a little proud of today?', 'reinforce identity', 1.0),
  ('tomorrow_plan',   null,        'opportunity', 'preparation',   null, 'What is the one tiny step you want to set up for tomorrow?', 'make it if-then and tiny', 1.1),
  ('values_check',    null,        'motivation',  'contemplation', null, 'Did today move you closer to the person you want to become?', 'identity-based', 1.0)
on conflict (key) do nothing;
