-- ---------------------------------------------------------------------------
-- Pet Passport — Multi-user bootstrap (M1)
-- ---------------------------------------------------------------------------
-- Establishes the four tables that hold the household-sharing concept:
--   * households          — the container everything else belongs to
--   * household_members   — n:m user ↔ household with role
--   * invite_codes        — short-lived tokens for adding members
--   * user_profiles       — display name (email stays private)
--
-- All tables have RLS enabled. Policies enforce the invariant "you can only
-- see rows for households you are a member of". The redeem_invite RPC is
-- SECURITY DEFINER so it can insert a household_members row on behalf of
-- someone who is not yet a member (bypassing RLS in a controlled way).
--
-- Idempotent: safe to re-run. Extensions are IF NOT EXISTS; DROP POLICY IF
-- EXISTS before CREATE POLICY, same for triggers.
-- ---------------------------------------------------------------------------

create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ==========================================================================
-- households
-- ==========================================================================
create table if not exists public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 80),
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null
);

alter table public.households enable row level security;

-- ==========================================================================
-- household_members
-- Composite PK (household_id, user_id) prevents duplicate memberships.
-- ==========================================================================
create table if not exists public.household_members (
  household_id  uuid not null references public.households(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  role          text not null check (role in ('owner', 'member')) default 'member',
  joined_at     timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index if not exists idx_household_members_user
  on public.household_members(user_id);

alter table public.household_members enable row level security;

-- ==========================================================================
-- invite_codes
-- Short-lived (TTL 24h), single-use tokens for joining a household.
-- Client generates the token client-side, uniqueness enforced here.
-- ==========================================================================
create table if not exists public.invite_codes (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households(id) on delete cascade,
  token         text not null unique check (char_length(token) between 6 and 32),
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  used_by       uuid references auth.users(id) on delete set null,
  used_at       timestamptz
);

create index if not exists idx_invite_codes_household
  on public.invite_codes(household_id);

alter table public.invite_codes enable row level security;

-- ==========================================================================
-- user_profiles
-- Display name is required (enforced client-side + here via NOT NULL).
-- ==========================================================================
create table if not exists public.user_profiles (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 60),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.user_profiles enable row level security;

-- ==========================================================================
-- Trigger: creator auto-becomes owner of a new household
-- Runs with the caller's privileges so RLS on household_members applies
-- normally; the INSERT it performs is allowed by the "self-owner"
-- household_members INSERT policy below.
-- ==========================================================================
create or replace function public.tg_household_creator_becomes_owner()
returns trigger
language plpgsql
as $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  if new.created_by is not null then
    insert into public.household_members (household_id, user_id, role)
    values (new.id, new.created_by, 'owner')
    on conflict (household_id, user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_household_creator_becomes_owner on public.households;
create trigger trg_household_creator_becomes_owner
  after insert on public.households
  for each row execute function public.tg_household_creator_becomes_owner();

-- ==========================================================================
-- Trigger: keep user_profiles.updated_at fresh
-- ==========================================================================
create or replace function public.tg_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_user_profiles_touch on public.user_profiles;
create trigger trg_user_profiles_touch
  before update on public.user_profiles
  for each row execute function public.tg_touch_updated_at();

-- ==========================================================================
-- RPC: redeem_invite
-- Runs with definer privileges so the calling user can join a household
-- they're not yet a member of. Validates: token exists, not expired, not
-- used. On success: marks used + inserts household_members row + returns
-- household summary.
-- ==========================================================================
create or replace function public.redeem_invite(p_token text)
returns table (household_id uuid, household_name text, member_count int)
language plpgsql
security definer
set search_path = public
as $$
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

  -- If the user is already a member, treat this as a no-op success.
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

revoke all on function public.redeem_invite(text) from public;
grant execute on function public.redeem_invite(text) to authenticated;

-- ==========================================================================
-- RLS POLICIES
-- ==========================================================================

-- ── households ────────────────────────────────────────────────────────────
drop policy if exists households_select on public.households;
create policy households_select on public.households
  for select using (
    id in (select household_id from public.household_members
            where user_id = auth.uid())
  );

drop policy if exists households_insert on public.households;
create policy households_insert on public.households
  for insert with check (
    auth.uid() is not null
    -- created_by is normalized by the trigger; allow null (trigger fills it)
    and (created_by is null or created_by = auth.uid())
  );

drop policy if exists households_update on public.households;
create policy households_update on public.households
  for update using (
    id in (select household_id from public.household_members
            where user_id = auth.uid() and role = 'owner')
  );

drop policy if exists households_delete on public.households;
create policy households_delete on public.households
  for delete using (
    id in (select household_id from public.household_members
            where user_id = auth.uid() and role = 'owner')
  );

-- ── household_members ────────────────────────────────────────────────────
drop policy if exists members_select on public.household_members;
create policy members_select on public.household_members
  for select using (
    household_id in (select household_id from public.household_members
                      where user_id = auth.uid())
  );

-- INSERT via client only for self-owner-membership (used by the trigger
-- on households insert). Other insertions must go through redeem_invite
-- which runs as SECURITY DEFINER.
drop policy if exists members_insert_self_owner on public.household_members;
create policy members_insert_self_owner on public.household_members
  for insert with check (
    user_id = auth.uid() and role = 'owner'
  );

drop policy if exists members_update on public.household_members;
create policy members_update on public.household_members
  for update using (
    household_id in (select household_id from public.household_members
                      where user_id = auth.uid() and role = 'owner')
  );

-- DELETE: owner can remove anyone, member can remove themselves.
drop policy if exists members_delete on public.household_members;
create policy members_delete on public.household_members
  for delete using (
    user_id = auth.uid()
    or household_id in (select household_id from public.household_members
                         where user_id = auth.uid() and role = 'owner')
  );

-- ── invite_codes ──────────────────────────────────────────────────────────
-- Only owners of the target household can manage invites via direct table
-- access. Redemption uses the SECURITY DEFINER RPC — the invitee never
-- needs SELECT on this table (a plain SELECT with the token would leak
-- existence otherwise).
drop policy if exists invites_select_owner on public.invite_codes;
create policy invites_select_owner on public.invite_codes
  for select using (
    household_id in (select household_id from public.household_members
                      where user_id = auth.uid() and role = 'owner')
  );

drop policy if exists invites_insert_owner on public.invite_codes;
create policy invites_insert_owner on public.invite_codes
  for insert with check (
    household_id in (select household_id from public.household_members
                      where user_id = auth.uid() and role = 'owner')
    and (created_by is null or created_by = auth.uid())
  );

drop policy if exists invites_update_owner on public.invite_codes;
create policy invites_update_owner on public.invite_codes
  for update using (
    household_id in (select household_id from public.household_members
                      where user_id = auth.uid() and role = 'owner')
  );

drop policy if exists invites_delete_owner on public.invite_codes;
create policy invites_delete_owner on public.invite_codes
  for delete using (
    household_id in (select household_id from public.household_members
                      where user_id = auth.uid() and role = 'owner')
  );

-- ── user_profiles ────────────────────────────────────────────────────────
-- Visible to me + anyone who shares a household with me.
drop policy if exists profiles_select on public.user_profiles;
create policy profiles_select on public.user_profiles
  for select using (
    user_id = auth.uid()
    or user_id in (
      select hm.user_id
        from public.household_members hm
       where hm.household_id in (
         select household_id from public.household_members
          where user_id = auth.uid()
       )
    )
  );

drop policy if exists profiles_insert_self on public.user_profiles;
create policy profiles_insert_self on public.user_profiles
  for insert with check (user_id = auth.uid());

drop policy if exists profiles_update_self on public.user_profiles;
create policy profiles_update_self on public.user_profiles
  for update using (user_id = auth.uid());

drop policy if exists profiles_delete_self on public.user_profiles;
create policy profiles_delete_self on public.user_profiles
  for delete using (user_id = auth.uid());
