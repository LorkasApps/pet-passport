-- ---------------------------------------------------------------------------
-- Pet Passport — Feature tables + RLS (M3-04)
-- ---------------------------------------------------------------------------
-- Mirrors the local Drift tables that the outbox pushes: pets and its nine
-- top-level children (vets, contacts, appointments, medications, foods,
-- vaccinations, insurances, events, pet_documents).
--
-- Design choices worth stating up front:
--
-- * Uuid primary keys. Local Drift also stores an autoincrement `id`, but
--   that's a device-local artifact — cloud rows key by the `uuid` value.
--   Column named `id` here (Postgres convention); the push translator
--   renames the client's `uuid` field to `id`.
--
-- * Foreign keys are uuid. Local Drift uses int FKs; the enqueue-side
--   FK resolver (next migration + next code change) rewrites the payload
--   from `petId: int` to `pet_id: uuid` before it hits the outbox.
--
-- * household_id is a plain FK, no cascade — deleting a household should
--   never silently take feature rows with it. If a household is deleted,
--   the M6 flow explicitly kills its rows first.
--
-- * RLS on every table with the same three-part gate:
--     select / insert / update / delete → household_id IN my_household_ids()
--   my_household_ids() was defined in migration 0002 and bypasses the
--   RLS-recursion trap. `updated_by_user_id` is not enforced against
--   auth.uid() to allow the last-write-wins server-side observability
--   (whoever wrote last is who wrote last; we don't gate on it).
--
-- * `deleted_at` is a nullable tombstone timestamp. The RLS policies do
--   NOT filter it — SELECT returns tombstones too, so pull-sync can see
--   them on other devices. UI filters in the app.
--
-- * Enum columns are `smallint`. Matches Drift's intEnum converter which
--   emits Java-style small integers.
--
-- * updated_at is a `timestamptz` and drives LWW conflict resolution.
--   Server does not touch it — the client sets it at write time.
--
-- No triggers here — plain tables. Realtime subscriptions land in M4
-- and don't need schema changes.
--
-- Idempotent: `create table if not exists`, `drop policy if exists`
-- before `create policy`.
-- ---------------------------------------------------------------------------

-- ==========================================================================
-- Shared macro-alike: RLS gate for household-scoped tables.
-- Every feature table below repeats the same four policies with only the
-- table name substituted. Kept inline (not a function) so `pg_dump`
-- output stays readable.
-- ==========================================================================

-- ==========================================================================
-- pets
-- ==========================================================================
create table if not exists public.pets (
  id                            uuid primary key,
  name                          text not null check (char_length(name) between 1 and 100),
  species                       smallint not null,
  breed                         text,
  sex                           smallint not null,
  is_neutered                   boolean not null default false,
  date_of_birth                 timestamptz,
  color                         text,
  markings                      text,
  chip_number                   text,
  tasso_number                  text,
  tasso_registered_at           timestamptz,
  vaccination_passport_number   text,
  profile_photo_path            text,
  allergies                     text,
  notes                         text,
  created_at                    timestamptz not null,
  updated_at                    timestamptz not null,
  deleted_at                    timestamptz,
  household_id                  uuid not null references public.households(id),
  updated_by_user_id            uuid references auth.users(id) on delete set null
);
create index if not exists idx_pets_household on public.pets(household_id);
create index if not exists idx_pets_household_updated on public.pets(household_id, updated_at);
alter table public.pets enable row level security;

drop policy if exists pets_select on public.pets;
create policy pets_select on public.pets for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists pets_insert on public.pets;
create policy pets_insert on public.pets for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists pets_update on public.pets;
create policy pets_update on public.pets for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists pets_delete on public.pets;
create policy pets_delete on public.pets for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- vets
-- ==========================================================================
create table if not exists public.vets (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  name                  text not null check (char_length(name) between 1 and 200),
  practice              text,
  address               text,
  phone                 text,
  email                 text,
  notes                 text,
  is_active             boolean not null default true,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_vets_household on public.vets(household_id);
create index if not exists idx_vets_pet on public.vets(pet_id);
create index if not exists idx_vets_household_updated on public.vets(household_id, updated_at);
alter table public.vets enable row level security;

drop policy if exists vets_select on public.vets;
create policy vets_select on public.vets for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists vets_insert on public.vets;
create policy vets_insert on public.vets for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists vets_update on public.vets;
create policy vets_update on public.vets for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists vets_delete on public.vets;
create policy vets_delete on public.vets for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- contacts
-- ==========================================================================
create table if not exists public.contacts (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  role                  smallint not null default 3,
  name                  text not null check (char_length(name) between 1 and 200),
  organization          text,
  address               text,
  phone                 text,
  email                 text,
  notes                 text,
  is_active             boolean not null default true,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_contacts_household on public.contacts(household_id);
create index if not exists idx_contacts_pet on public.contacts(pet_id);
create index if not exists idx_contacts_household_updated on public.contacts(household_id, updated_at);
alter table public.contacts enable row level security;

drop policy if exists contacts_select on public.contacts;
create policy contacts_select on public.contacts for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists contacts_insert on public.contacts;
create policy contacts_insert on public.contacts for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists contacts_update on public.contacts;
create policy contacts_update on public.contacts for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists contacts_delete on public.contacts;
create policy contacts_delete on public.contacts for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- appointments
-- ==========================================================================
create table if not exists public.appointments (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  vet_id                uuid references public.vets(id) on delete set null,
  contact_id            uuid references public.contacts(id) on delete set null,
  type                  smallint not null,
  title                 text not null check (char_length(title) between 1 and 200),
  starts_at             timestamptz not null,
  duration_minutes      int not null default 60,
  location              text,
  notes                 text,
  recurrence_freq       smallint not null default 0,
  recurrence_interval   int not null default 1,
  recurrence_weekdays   int not null default 0,
  recurrence_until      timestamptz,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_appointments_household on public.appointments(household_id);
create index if not exists idx_appointments_pet on public.appointments(pet_id);
create index if not exists idx_appointments_household_updated on public.appointments(household_id, updated_at);
alter table public.appointments enable row level security;

drop policy if exists appointments_select on public.appointments;
create policy appointments_select on public.appointments for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists appointments_insert on public.appointments;
create policy appointments_insert on public.appointments for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists appointments_update on public.appointments;
create policy appointments_update on public.appointments for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists appointments_delete on public.appointments;
create policy appointments_delete on public.appointments for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- medications
-- ==========================================================================
create table if not exists public.medications (
  id                        uuid primary key,
  pet_id                    uuid not null references public.pets(id) on delete cascade,
  name                      text not null check (char_length(name) between 1 and 200),
  dosage_amount             real not null default 0,
  dosage_unit               text not null default '',
  freq_type                 smallint not null default 0,
  freq_interval             int not null default 1,
  freq_weekdays             int not null default 0,
  times_of_day_json         text not null default '[]',
  starts_at                 timestamptz not null,
  ends_at                   timestamptz,
  is_active                 boolean not null default true,
  notes                     text,
  prescribed_by_vet_id      uuid references public.vets(id) on delete set null,
  with_food                 boolean not null default false,
  created_at                timestamptz not null,
  updated_at                timestamptz not null,
  deleted_at                timestamptz,
  household_id              uuid not null references public.households(id),
  updated_by_user_id        uuid references auth.users(id) on delete set null
);
create index if not exists idx_medications_household on public.medications(household_id);
create index if not exists idx_medications_pet on public.medications(pet_id);
create index if not exists idx_medications_household_updated on public.medications(household_id, updated_at);
alter table public.medications enable row level security;

drop policy if exists medications_select on public.medications;
create policy medications_select on public.medications for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists medications_insert on public.medications;
create policy medications_insert on public.medications for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists medications_update on public.medications;
create policy medications_update on public.medications for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists medications_delete on public.medications;
create policy medications_delete on public.medications for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- foods
-- ==========================================================================
create table if not exists public.foods (
  id                        uuid primary key,
  pet_id                    uuid not null references public.pets(id) on delete cascade,
  brand                     text not null default '',
  name                      text not null check (char_length(name) between 1 and 200),
  food_type                 smallint not null default 0,
  portion_grams             real not null default 0,
  frequency_per_day         int not null default 1,
  times_of_day_json         text not null default '[]',
  is_active                 boolean not null default true,
  starts_at                 timestamptz not null,
  ends_at                   timestamptz,
  reminders_enabled         boolean not null default false,
  notes                     text,
  created_at                timestamptz not null,
  updated_at                timestamptz not null,
  deleted_at                timestamptz,
  household_id              uuid not null references public.households(id),
  updated_by_user_id        uuid references auth.users(id) on delete set null
);
create index if not exists idx_foods_household on public.foods(household_id);
create index if not exists idx_foods_pet on public.foods(pet_id);
create index if not exists idx_foods_household_updated on public.foods(household_id, updated_at);
alter table public.foods enable row level security;

drop policy if exists foods_select on public.foods;
create policy foods_select on public.foods for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists foods_insert on public.foods;
create policy foods_insert on public.foods for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists foods_update on public.foods;
create policy foods_update on public.foods for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists foods_delete on public.foods;
create policy foods_delete on public.foods for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- vaccinations
-- ==========================================================================
create table if not exists public.vaccinations (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  vaccine_name          text not null check (char_length(vaccine_name) between 1 and 200),
  administered_at       timestamptz not null,
  next_due_at           timestamptz,
  vet_id                uuid references public.vets(id) on delete set null,
  batch_number          text,
  notes                 text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_vaccinations_household on public.vaccinations(household_id);
create index if not exists idx_vaccinations_pet on public.vaccinations(pet_id);
create index if not exists idx_vaccinations_household_updated on public.vaccinations(household_id, updated_at);
alter table public.vaccinations enable row level security;

drop policy if exists vaccinations_select on public.vaccinations;
create policy vaccinations_select on public.vaccinations for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists vaccinations_insert on public.vaccinations;
create policy vaccinations_insert on public.vaccinations for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists vaccinations_update on public.vaccinations;
create policy vaccinations_update on public.vaccinations for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists vaccinations_delete on public.vaccinations;
create policy vaccinations_delete on public.vaccinations for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- insurances
-- ==========================================================================
create table if not exists public.insurances (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  provider              text not null check (char_length(provider) between 1 and 200),
  policy_number         text,
  contract_start        timestamptz,
  contract_end          timestamptz,
  notes                 text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_insurances_household on public.insurances(household_id);
create index if not exists idx_insurances_pet on public.insurances(pet_id);
create index if not exists idx_insurances_household_updated on public.insurances(household_id, updated_at);
alter table public.insurances enable row level security;

drop policy if exists insurances_select on public.insurances;
create policy insurances_select on public.insurances for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists insurances_insert on public.insurances;
create policy insurances_insert on public.insurances for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists insurances_update on public.insurances;
create policy insurances_update on public.insurances for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists insurances_delete on public.insurances;
create policy insurances_delete on public.insurances for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- events
-- ==========================================================================
create table if not exists public.events (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  event_type            smallint not null,
  occurred_at           timestamptz not null,
  title                 text check (title is null or char_length(title) between 1 and 200),
  note                  text,
  payload_json          text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_events_household on public.events(household_id);
create index if not exists idx_events_pet on public.events(pet_id);
create index if not exists idx_events_household_updated on public.events(household_id, updated_at);
alter table public.events enable row level security;

drop policy if exists events_select on public.events;
create policy events_select on public.events for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists events_insert on public.events;
create policy events_insert on public.events for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists events_update on public.events;
create policy events_update on public.events for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists events_delete on public.events;
create policy events_delete on public.events for delete
  using (household_id in (select public.my_household_ids()));

-- ==========================================================================
-- pet_documents
-- Note: `file_path` currently holds a local device path. M5 media-sync
-- will migrate these to Storage keys under `household/<hid>/…`.
-- ==========================================================================
create table if not exists public.pet_documents (
  id                    uuid primary key,
  pet_id                uuid not null references public.pets(id) on delete cascade,
  title                 text,
  file_path             text not null,
  mime_type             text not null check (char_length(mime_type) between 1 and 128),
  original_filename     text,
  size_bytes            bigint,
  notes                 text,
  created_at            timestamptz not null,
  updated_at            timestamptz not null,
  deleted_at            timestamptz,
  household_id          uuid not null references public.households(id),
  updated_by_user_id    uuid references auth.users(id) on delete set null
);
create index if not exists idx_pet_documents_household on public.pet_documents(household_id);
create index if not exists idx_pet_documents_pet on public.pet_documents(pet_id);
create index if not exists idx_pet_documents_household_updated on public.pet_documents(household_id, updated_at);
alter table public.pet_documents enable row level security;

drop policy if exists pet_documents_select on public.pet_documents;
create policy pet_documents_select on public.pet_documents for select
  using (household_id in (select public.my_household_ids()));
drop policy if exists pet_documents_insert on public.pet_documents;
create policy pet_documents_insert on public.pet_documents for insert
  with check (household_id in (select public.my_household_ids()));
drop policy if exists pet_documents_update on public.pet_documents;
create policy pet_documents_update on public.pet_documents for update
  using (household_id in (select public.my_household_ids()))
  with check (household_id in (select public.my_household_ids()));
drop policy if exists pet_documents_delete on public.pet_documents;
create policy pet_documents_delete on public.pet_documents for delete
  using (household_id in (select public.my_household_ids()));
