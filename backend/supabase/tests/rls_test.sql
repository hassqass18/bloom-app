-- Bloom — RLS isolation test (run against a local `supabase start` DB)
-- Verifies a user can only see their own rows. Run with:
--   psql "$DATABASE_URL" -f backend/supabase/tests/rls_test.sql
-- Expects to RAISE EXCEPTION (test fails loudly) if isolation is broken.

begin;

-- Create two fake auth users (local only; in prod these come from Supabase Auth).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','a@test.dev'),
  ('22222222-2222-2222-2222-222222222222','b@test.dev')
on conflict do nothing;

-- Act as user A and write a row.
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
insert into days (user_id, day, mood) values
  ('11111111-1111-1111-1111-111111111111', current_date, 4);

-- Act as user B and try to read A's rows — must see ZERO.
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
do $$
declare leaked int;
begin
  select count(*) into leaked from days
   where user_id = '11111111-1111-1111-1111-111111111111';
  if leaked <> 0 then
    raise exception 'RLS FAIL: user B saw % of user A''s rows', leaked;
  end if;
  raise notice 'RLS OK: user B cannot see user A rows';
end $$;

rollback;  -- never persist test data
