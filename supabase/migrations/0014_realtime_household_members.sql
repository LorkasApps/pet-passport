-- ---------------------------------------------------------------------------
-- Pet Passport — Realtime on household_members
-- ---------------------------------------------------------------------------
-- 0006 added every feature table to the `supabase_realtime`
-- publication, but not `household_members`. So when someone
-- redeemed an invite (or the owner removed a member), no
-- postgres_changes event fired — the current owner's members list
-- only updated on the next full app restart when the AsyncNotifier
-- re-fetched.
--
-- Adding household_members to the publication means every device
-- that's already a member of the affected household will get an
-- event on INSERT/UPDATE/DELETE. The client-side listener then
-- invalidates myHouseholdsProvider + householdMembersProvider so
-- the UI reactively picks up joins / leaves / role changes.
--
-- RLS still applies: only members of the household see the event.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'household_members'
  ) then
    alter publication supabase_realtime add table public.household_members;
  end if;
end;
$$;
