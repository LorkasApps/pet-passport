-- ---------------------------------------------------------------------------
-- Pet Passport — Cloud tables for the 5 nested attachment surfaces (M5)
-- ---------------------------------------------------------------------------
-- pet_documents already lives cloud-side (migration 0004). This adds the
-- remaining five attachment tables so their metadata rides through
-- row-sync exactly like the top-level tables do:
--
--   event_photos             child of events
--   food_photos              child of foods
--   insurance_documents      child of insurances
--   vaccination_documents    child of vaccinations
--   pet_passport_documents   child of pets
--
-- Shape matches pet_documents: uuid PK, uuid FK to parent + household,
-- timestamptz for the sync-standard columns, `storage_key` nullable
-- so the row can exist before the media upload has landed.
--
-- Realtime + RLS are the same pattern the other M4/M2 migrations
-- established. Idempotent throughout.
-- ---------------------------------------------------------------------------

-- ==========================================================================
-- event_photos
-- ==========================================================================
create table if not exists public.event_photos (
  id                    uuid primary key,
  event_id              uuid not null references public.events(id) on delete cascade,
  title                 text,
  file_path             text not null,
  mime_type             text not null check (char_length(mime_type) between 1 and 128),
  size_bytes            bigint,
  storage_key           text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_event_photos_household on public.event_photos(household_id);
create index if not exists idx_event_photos_event on public.event_photos(event_id);
create index if not exists idx_event_photos_household_updated on public.event_photos(household_id, updated_at);
alter table public.event_photos enable row level security;

drop policy if exists event_photos_select on public.event_photos;
create policy event_photos_select on public.event_photos for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists event_photos_insert on public.event_photos;
create policy event_photos_insert on public.event_photos for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists event_photos_update on public.event_photos;
create policy event_photos_update on public.event_photos for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists event_photos_delete on public.event_photos;
create policy event_photos_delete on public.event_photos for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- food_photos
-- ==========================================================================
create table if not exists public.food_photos (
  id                    uuid primary key,
  food_id               uuid not null references public.foods(id) on delete cascade,
  title                 text,
  file_path             text not null,
  mime_type             text not null check (char_length(mime_type) between 1 and 128),
  original_filename     text,
  size_bytes            bigint,
  storage_key           text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_food_photos_household on public.food_photos(household_id);
create index if not exists idx_food_photos_food on public.food_photos(food_id);
create index if not exists idx_food_photos_household_updated on public.food_photos(household_id, updated_at);
alter table public.food_photos enable row level security;

drop policy if exists food_photos_select on public.food_photos;
create policy food_photos_select on public.food_photos for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists food_photos_insert on public.food_photos;
create policy food_photos_insert on public.food_photos for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists food_photos_update on public.food_photos;
create policy food_photos_update on public.food_photos for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists food_photos_delete on public.food_photos;
create policy food_photos_delete on public.food_photos for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- insurance_documents
-- ==========================================================================
create table if not exists public.insurance_documents (
  id                    uuid primary key,
  insurance_id          uuid not null references public.insurances(id) on delete cascade,
  title                 text,
  file_path             text not null,
  mime_type             text not null check (char_length(mime_type) between 1 and 128),
  original_filename     text,
  size_bytes            bigint,
  storage_key           text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_insurance_documents_household on public.insurance_documents(household_id);
create index if not exists idx_insurance_documents_insurance on public.insurance_documents(insurance_id);
create index if not exists idx_insurance_documents_household_updated on public.insurance_documents(household_id, updated_at);
alter table public.insurance_documents enable row level security;

drop policy if exists insurance_documents_select on public.insurance_documents;
create policy insurance_documents_select on public.insurance_documents for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists insurance_documents_insert on public.insurance_documents;
create policy insurance_documents_insert on public.insurance_documents for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists insurance_documents_update on public.insurance_documents;
create policy insurance_documents_update on public.insurance_documents for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists insurance_documents_delete on public.insurance_documents;
create policy insurance_documents_delete on public.insurance_documents for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- vaccination_documents
-- ==========================================================================
create table if not exists public.vaccination_documents (
  id                    uuid primary key,
  vaccination_id        uuid not null references public.vaccinations(id) on delete cascade,
  title                 text,
  file_path             text not null,
  mime_type             text not null check (char_length(mime_type) between 1 and 128),
  original_filename     text,
  size_bytes            bigint,
  storage_key           text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_vaccination_documents_household on public.vaccination_documents(household_id);
create index if not exists idx_vaccination_documents_vaccination on public.vaccination_documents(vaccination_id);
create index if not exists idx_vaccination_documents_household_updated on public.vaccination_documents(household_id, updated_at);
alter table public.vaccination_documents enable row level security;

drop policy if exists vaccination_documents_select on public.vaccination_documents;
create policy vaccination_documents_select on public.vaccination_documents for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists vaccination_documents_insert on public.vaccination_documents;
create policy vaccination_documents_insert on public.vaccination_documents for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists vaccination_documents_update on public.vaccination_documents;
create policy vaccination_documents_update on public.vaccination_documents for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists vaccination_documents_delete on public.vaccination_documents;
create policy vaccination_documents_delete on public.vaccination_documents for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- pet_passport_documents
-- ==========================================================================
create table if not exists public.pet_passport_documents (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  title                 text,
  file_path             text not null,
  mime_type             text not null check (char_length(mime_type) between 1 and 128),
  original_filename     text,
  size_bytes            bigint,
  storage_key           text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_pet_passport_documents_household on public.pet_passport_documents(household_id);
create index if not exists idx_pet_passport_documents_pet on public.pet_passport_documents(pet_id);
create index if not exists idx_pet_passport_documents_household_updated on public.pet_passport_documents(household_id, updated_at);
alter table public.pet_passport_documents enable row level security;

drop policy if exists pet_passport_documents_select on public.pet_passport_documents;
create policy pet_passport_documents_select on public.pet_passport_documents for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists pet_passport_documents_insert on public.pet_passport_documents;
create policy pet_passport_documents_insert on public.pet_passport_documents for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists pet_passport_documents_update on public.pet_passport_documents;
create policy pet_passport_documents_update on public.pet_passport_documents for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists pet_passport_documents_delete on public.pet_passport_documents;
create policy pet_passport_documents_delete on public.pet_passport_documents for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- Add all five to the realtime publication so postgres_changes fires.
-- Same idempotent dance as 0006.
-- ==========================================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'event_photos',
    'food_photos',
    'insurance_documents',
    'vaccination_documents',
    'pet_passport_documents'
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
