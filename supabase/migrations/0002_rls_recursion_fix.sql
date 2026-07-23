-- ---------------------------------------------------------------------------
-- Pet Passport — Fix RLS infinite recursion on household_members (M1)
-- ---------------------------------------------------------------------------
-- The initial policies referenced household_members from within their own
-- SELECT policy (via `household_id IN (SELECT ... FROM household_members)`),
-- and PostgreSQL detects this as infinite recursion (error 42P17) as soon
-- as anyone reads the table.
--
-- Fix: two SECURITY DEFINER helpers that check membership / ownership
-- without going through RLS. Policies delegate the membership test to
-- these helpers instead of doing correlated subqueries against
-- household_members themselves.
--
-- SECURITY DEFINER runs the function as its owner (postgres role in
-- Supabase); that role bypasses RLS. `search_path = public, pg_temp`
-- neutralises the classic function-hijack attack via a shadowed
-- search-path.
--
-- Idempotent: drop-if-exists everywhere.
-- ---------------------------------------------------------------------------

-- ==========================================================================
-- Helper functions
-- ==========================================================================

create or replace function public.is_member_of(p_household uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.household_members
     where household_id = p_household
       and user_id = auth.uid()
  );
$$;

revoke all on function public.is_member_of(uuid) from public;
grant execute on function public.is_member_of(uuid) to authenticated, anon;

create or replace function public.is_owner_of(p_household uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.household_members
     where household_id = p_household
       and user_id = auth.uid()
       and role = 'owner'
  );
$$;

revoke all on function public.is_owner_of(uuid) from public;
grant execute on function public.is_owner_of(uuid) to authenticated, anon;

-- Returns every household the current caller is a member of. Used by
-- the user_profiles SELECT policy (where a scalar helper would be
-- awkward).
create or replace function public.my_household_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select household_id
    from public.household_members
   where user_id = auth.uid();
$$;

revoke all on function public.my_household_ids() from public;
grant execute on function public.my_household_ids() to authenticated, anon;

-- ==========================================================================
-- Re-create policies using the helpers
-- ==========================================================================

-- ── households ────────────────────────────────────────────────────────────
drop policy if exists households_select on public.households;
create policy households_select on public.households
  for select using ( public.is_member_of(id) );

drop policy if exists households_update on public.households;
create policy households_update on public.households
  for update using ( public.is_owner_of(id) );

drop policy if exists households_delete on public.households;
create policy households_delete on public.households
  for delete using ( public.is_owner_of(id) );

-- households_insert stays as-is (didn't recurse; kept for clarity)
drop policy if exists households_insert on public.households;
create policy households_insert on public.households
  for insert with check (
    auth.uid() is not null
    and (created_by is null or created_by = auth.uid())
  );

-- ── household_members ─────────────────────────────────────────────────────
drop policy if exists members_select on public.household_members;
create policy members_select on public.household_members
  for select using ( public.is_member_of(household_id) );

drop policy if exists members_insert_self_owner on public.household_members;
create policy members_insert_self_owner on public.household_members
  for insert with check (
    user_id = auth.uid() and role = 'owner'
  );

drop policy if exists members_update on public.household_members;
create policy members_update on public.household_members
  for update using ( public.is_owner_of(household_id) );

drop policy if exists members_delete on public.household_members;
create policy members_delete on public.household_members
  for delete using (
    user_id = auth.uid()
    or public.is_owner_of(household_id)
  );

-- ── invite_codes ──────────────────────────────────────────────────────────
drop policy if exists invites_select_owner on public.invite_codes;
create policy invites_select_owner on public.invite_codes
  for select using ( public.is_owner_of(household_id) );

drop policy if exists invites_insert_owner on public.invite_codes;
create policy invites_insert_owner on public.invite_codes
  for insert with check (
    public.is_owner_of(household_id)
    and (created_by is null or created_by = auth.uid())
  );

drop policy if exists invites_update_owner on public.invite_codes;
create policy invites_update_owner on public.invite_codes
  for update using ( public.is_owner_of(household_id) );

drop policy if exists invites_delete_owner on public.invite_codes;
create policy invites_delete_owner on public.invite_codes
  for delete using ( public.is_owner_of(household_id) );

-- ── user_profiles ─────────────────────────────────────────────────────────
-- Visible to me + anyone who shares any household with me. Using
-- my_household_ids() sidesteps the recursion the earlier version had.
drop policy if exists profiles_select on public.user_profiles;
create policy profiles_select on public.user_profiles
  for select using (
    user_id = auth.uid()
    or user_id in (
      select hm.user_id
        from public.household_members hm
       where hm.household_id in (select public.my_household_ids())
    )
  );
