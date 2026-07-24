-- ---------------------------------------------------------------------------
-- Pet Passport — CASCADE household_id FKs
-- ---------------------------------------------------------------------------
-- 0004 + 0009 declared `household_id uuid not null references
-- public.households(id)` on 15 feature tables — no ON DELETE clause,
-- which Postgres defaults to NO ACTION (block). Deleting a household
-- with any pet / vet / event / … attached fails with 23503 and the
-- delete silently no-ops from the client's perspective. The plan
-- explicitly wants delete-household to cascade all rows.
--
-- Rewires every household_id FK to ON DELETE CASCADE. Storage-side
-- objects still need a separate sweep — TODO for M6 proper; for now
-- an orphan sweeps up cheaply since bucket paths embed the deleted
-- household_id and can be listed by prefix.
--
-- Idempotent: DROP CONSTRAINT IF EXISTS + ADD.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
  constraint_name text;
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
    'pet_documents',
    'event_photos',
    'food_photos',
    'insurance_documents',
    'vaccination_documents',
    'pet_passport_documents'
  ] loop
    -- Find whatever Postgres named the household FK on this table.
    -- Auto-generated names are typically `<table>_household_id_fkey`,
    -- but a manual re-run of an earlier migration could have re-used
    -- a different name; look it up from the catalog.
    select conname
      into constraint_name
      from pg_constraint
     where conrelid = format('public.%I', t)::regclass
       and contype = 'f'
       and pg_get_constraintdef(oid) like '%REFERENCES%households(id)%';

    if constraint_name is not null then
      execute format(
        'alter table public.%I drop constraint %I',
        t, constraint_name
      );
    end if;
    execute format(
      'alter table public.%I '
      'add constraint %I_household_id_fkey '
      'foreign key (household_id) references public.households(id) '
      'on delete cascade',
      t, t
    );
  end loop;
end;
$$;
