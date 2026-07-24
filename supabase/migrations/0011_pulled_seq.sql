-- ---------------------------------------------------------------------------
-- Pet Passport — server-monotonic pull cursor `pulled_seq`
-- ---------------------------------------------------------------------------
-- The v1 delta pull cursored on client-writable `updated_at`. Two devices
-- with skewed clocks (or offline queues that drained after later writes on
-- another device) could produce rows whose `updated_at` sits behind a
-- cursor already advanced past them — those rows were then skipped by
-- every subsequent pull. Realtime shrinks the window to near-zero in
-- practice, but the underlying axis was still fragile.
--
-- Fix: a shared sequence + trigger. Every INSERT / UPDATE bumps
-- `pulled_seq` on the affected row via `nextval('sync_seq')`. The number
-- is monotonic across every write everywhere in the schema — no
-- client clock involved. Clients cursor on `pulled_seq` instead of
-- `updated_at`; LWW conflict resolution still uses `updated_at`.
--
-- Idempotent: `create sequence if not exists`, `add column if not exists`,
-- `drop trigger if exists` before `create trigger`.
-- ---------------------------------------------------------------------------

create sequence if not exists public.sync_seq;

-- The trigger is shared across every synced table.
create or replace function public.tg_bump_pulled_seq()
returns trigger
language plpgsql
as $$
begin
  new.pulled_seq := nextval('public.sync_seq');
  return new;
end;
$$;

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
    'pet_documents',
    'event_photos',
    'food_photos',
    'insurance_documents',
    'vaccination_documents',
    'pet_passport_documents'
  ] loop
    -- Add the column if it isn't already there. Default nextval seeds
    -- every existing row with a fresh monotonic value, so cursors
    -- starting from 0 will pull the whole household on first sync.
    execute format(
      'alter table public.%I '
      'add column if not exists pulled_seq bigint not null '
      'default nextval(''public.sync_seq'')',
      t
    );
    execute format(
      'create index if not exists idx_%s_household_seq '
      'on public.%I (household_id, pulled_seq)',
      t, t
    );
    -- BEFORE INSERT OR UPDATE — bumps on every write. INSERT already
    -- got the DEFAULT value at row-creation time, but that value is
    -- captured before the trigger and might be older than a
    -- concurrent write, so we overwrite here too to keep the
    -- monotonic-across-writes invariant.
    execute format(
      'drop trigger if exists trg_%s_pulled_seq on public.%I',
      t, t
    );
    execute format(
      'create trigger trg_%s_pulled_seq '
      'before insert or update on public.%I '
      'for each row execute function public.tg_bump_pulled_seq()',
      t, t
    );
  end loop;
end;
$$;
