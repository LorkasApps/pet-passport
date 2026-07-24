-- ---------------------------------------------------------------------------
-- Pet Passport — Cloud storage_key columns for pets + pet_documents (M5)
-- ---------------------------------------------------------------------------
-- The media outbox uploads files to the `media` bucket (migration 0007)
-- and writes the resulting object key back into the owning row's new
-- `*_storage_key` column. Row-sync then carries the key across devices,
-- and the download-on-demand fetcher resolves it via a signed URL when
-- a viewer needs the file.
--
-- Local `file_path` / `profile_photo_path` columns stay as device-local
-- hints — they aren't part of the cloud row shape (see the migration
-- doc comment on 0004 for the same pattern applied to other columns).
-- We don't add them here at all; the push translator won't push them
-- either, so the cloud schema doesn't need to know about them.
--
-- Idempotent: `add column if not exists` on both.
-- ---------------------------------------------------------------------------

alter table public.pets
  add column if not exists profile_photo_storage_key text;

alter table public.pet_documents
  add column if not exists storage_key text;
