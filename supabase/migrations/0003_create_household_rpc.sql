-- ---------------------------------------------------------------------------
-- Pet Passport — RPC for creating a household (M1 follow-up)
-- ---------------------------------------------------------------------------
-- Symptom that prompted this: on a fresh install of the release build, the
-- first `insert into public.households` from the client came back as
-- 42501 "new row violates row-level security policy" even though the same
-- user's `insert into public.user_profiles` (identical auth path) had just
-- succeeded a moment earlier. The `households_insert` policy requires
-- `created_by = auth.uid()`, and the client dutifully sends the current
-- user's id — but under some client/network condition PostgREST evaluated
-- the check against a different value.
--
-- Rather than debug that from the outside, we route creation through a
-- SECURITY DEFINER RPC (same pattern as `redeem_invite`): the function
-- reads `auth.uid()` server-side and does both writes in one transaction
-- that bypasses RLS with a controlled scope. Client no longer has to send
-- `created_by`, and the trigger's AFTER-INSERT self-owner insert becomes
-- redundant for this path (still safe to leave in place for direct
-- inserts via the SQL editor or future admin flows).
--
-- Idempotent: `create or replace function`, `grant execute` is a no-op if
-- already granted.
-- ---------------------------------------------------------------------------

create or replace function public.create_household(p_name text)
returns table (
  id          uuid,
  name        text,
  created_at  timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_id      uuid;
  v_created timestamptz;
  v_name    text := btrim(p_name);
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_name is null or char_length(v_name) = 0 or char_length(v_name) > 80 then
    raise exception 'invalid household name (1..80 chars required)';
  end if;

  insert into public.households (name, created_by)
    values (v_name, v_user_id)
    returning households.id, households.created_at
    into v_id, v_created;

  -- The AFTER trigger already inserts the owner membership when it fires
  -- with a caller session; DEFINER context here means the trigger's
  -- `auth.uid() = user_id AND role='owner'` check on household_members
  -- runs against the DEFINER role, not the calling user. To keep the
  -- membership row correct we do it explicitly here — `on conflict` makes
  -- it safe even if a future migration flips the trigger to BEFORE INSERT
  -- and populates it too.
  insert into public.household_members (household_id, user_id, role)
    values (v_id, v_user_id, 'owner')
    on conflict (household_id, user_id) do nothing;

  return query
    select v_id, v_name, v_created;
end;
$$;

revoke all on function public.create_household(text) from public;
grant execute on function public.create_household(text) to authenticated;
