-- ---------------------------------------------------------------------------
-- Pet Passport — Fix column-ambiguity in redeem_invite (M1 follow-up)
-- ---------------------------------------------------------------------------
-- The RPC declares `RETURNS TABLE (household_id uuid, ...)`, which
-- makes `household_id` an OUT parameter inside the function body.
-- Line `on conflict (household_id, user_id)` then trips
-- Postgres 15+'s stricter plpgsql resolver:
--
--   42702: column reference "household_id" is ambiguous
--   could refer to either a PL/pgSQL variable or a table column
--
-- The join flow died with this error the moment a second user tried
-- to redeem an invite.
--
-- Fix: `#variable_conflict use_column` directive inside the function.
-- Tells plpgsql "when a name matches both a variable and a column,
-- prefer the column". We have no bare `household_id` references that
-- should refer to the OUT parameter — the return-query at the bottom
-- populates it implicitly via the SELECT column list — so the
-- directive is safe.
--
-- Idempotent: `create or replace function` overwrites the previous
-- definition.
-- ---------------------------------------------------------------------------

create or replace function public.redeem_invite(p_token text)
returns table (household_id uuid, household_name text, member_count int)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_user_id uuid := auth.uid();
  v_invite  record;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select id, invite_codes.household_id, expires_at, used_at
    into v_invite
    from public.invite_codes
   where token = p_token
   for update;

  if not found then
    raise exception 'invalid invite';
  end if;

  if v_invite.used_at is not null then
    raise exception 'invite already used';
  end if;

  if v_invite.expires_at < now() then
    raise exception 'invite expired';
  end if;

  insert into public.household_members (household_id, user_id, role)
  values (v_invite.household_id, v_user_id, 'member')
  on conflict (household_id, user_id) do nothing;

  update public.invite_codes
     set used_by = v_user_id,
         used_at = now()
   where id = v_invite.id;

  return query
    select h.id,
           h.name,
           (select count(*)::int
              from public.household_members hm
             where hm.household_id = h.id) as member_count
      from public.households h
     where h.id = v_invite.household_id;
end;
$$;
