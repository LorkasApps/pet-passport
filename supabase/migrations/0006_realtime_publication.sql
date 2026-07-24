-- ---------------------------------------------------------------------------
-- Pet Passport — Enable realtime for feature tables (M4)
-- ---------------------------------------------------------------------------
-- Supabase's realtime bridge listens to the `supabase_realtime` publication.
-- A table has to be explicitly added before postgres_changes events fire
-- for it. Doing it here (instead of via the Dashboard toggle) keeps the
-- realtime scope in git alongside the rest of the schema.
--
-- Idempotent: `pg_publication_tables` check per table so re-running is a
-- no-op. Postgres before 15 lacks `alter publication add table if not
-- exists`, hence the explicit dance.
--
-- RLS still applies to realtime — a subscriber only receives events for
-- rows their my_household_ids() scope covers. No extra policy needed.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'pets',
    'vets',
    'contacts',
    'appointments',
    'medications',
    'foods',
    'vaccinations',
    'insurances',
    'events',
    'pet_documents'
  ] loop
    if not exists (
      select 1
        from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t
      );
    end if;
  end loop;
end;
$$;
