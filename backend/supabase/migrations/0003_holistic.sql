-- Bloom v3 — holistic daily-logging domains.
-- Reflection/prayer, fitness, nutrition, journal, and user-chosen tracked areas.
-- Same conventions as 0001/0002. NO reserved-word column names.

do $$ begin
  create type practice_kind as enum ('prayer','meditation','reflection');
exception when duplicate_object then null; end $$;

do $$ begin
  create type nutrition_kind as enum ('meal','water','snack');
exception when duplicate_object then null; end $$;

do $$ begin
  create type journal_mode as enum ('manual','guided');
exception when duplicate_object then null; end $$;

-- prayer / meditation / reflection log
create table if not exists practice_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  kind        practice_kind not null,
  done        boolean not null default false,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_practice_user_day on practice_logs(user_id, day);
drop trigger if exists trg_practice_updated on practice_logs;
create trigger trg_practice_updated before update on practice_logs
  for each row execute function set_updated_at();

-- fitness / movement log
create table if not exists fitness_logs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day          date not null,
  activity     text not null,
  duration_min integer,
  intensity    text,
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index if not exists idx_fitness_user_day on fitness_logs(user_id, day);
drop trigger if exists trg_fitness_updated on fitness_logs;
create trigger trg_fitness_updated before update on fitness_logs
  for each row execute function set_updated_at();

-- nutrition / hydration log
create table if not exists nutrition_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  kind        nutrition_kind not null,
  label       text,
  kcal        numeric,
  water_ml    integer,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_nutrition_user_day on nutrition_logs(user_id, day);
drop trigger if exists trg_nutrition_updated on nutrition_logs;
create trigger trg_nutrition_updated before update on nutrition_logs
  for each row execute function set_updated_at();

-- journal (manual or Bloom-guided)
create table if not exists journal (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  body        text not null default '',
  mode        journal_mode not null default 'manual',
  source      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_journal_user_day on journal(user_id, day);
drop trigger if exists trg_journal2_updated on journal;
create trigger trg_journal2_updated before update on journal
  for each row execute function set_updated_at();

-- user-chosen "areas that matter" → drive dashboard progress bars
create table if not exists tracked_areas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label       text not null,
  domain      text,
  target      numeric,
  unit        text,
  cadence     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
drop trigger if exists trg_areas_updated on tracked_areas;
create trigger trg_areas_updated before update on tracked_areas
  for each row execute function set_updated_at();

-- RLS
alter table practice_logs  enable row level security;
alter table fitness_logs   enable row level security;
alter table nutrition_logs enable row level security;
alter table journal        enable row level security;
alter table tracked_areas  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['practice_logs','fitness_logs','nutrition_logs','journal','tracked_areas'] loop
    execute format('drop policy if exists %I on %I', t||'_owner', t);
    execute format(
      'create policy %I on %I for all using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t||'_owner', t);
  end loop;
end $$;
