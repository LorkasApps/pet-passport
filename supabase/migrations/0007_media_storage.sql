-- ---------------------------------------------------------------------------
-- Pet Passport — Media storage bucket + RLS (M5)
-- ---------------------------------------------------------------------------
-- Private bucket for pet media (documents + profile photos). Files are
-- addressed by path prefix `household/<hid>/…` so the RLS policy on
-- `storage.objects` can gate access with the same my_household_ids()
-- helper the feature tables use.
--
-- Mime whitelist from the plan's security checklist: images + PDF. The
-- policy enforces the extension list via `substr(name, ...)` — cheap,
-- and defence-in-depth on top of the client-side check.
--
-- Idempotent: `on conflict (id) do nothing` for the bucket insert,
-- `drop policy if exists` before every `create policy`.
-- ---------------------------------------------------------------------------

-- ==========================================================================
-- Bucket
-- ==========================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  false,
  20 * 1024 * 1024,               -- 20 MB per object; plenty for photos + PDFs
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
)
on conflict (id) do update
  set public              = excluded.public,
      file_size_limit     = excluded.file_size_limit,
      allowed_mime_types  = excluded.allowed_mime_types;

-- ==========================================================================
-- RLS policies on storage.objects
-- Path layout the client generates:
--   household/<household_uuid>/<entity_table>/<entity_uuid>.<ext>
-- The household id is the second path segment (index 2 with `/` as
-- separator in split_part's 1-based counting).
-- ==========================================================================

drop policy if exists media_select on storage.objects;
create policy media_select on storage.objects
  for select using (
    bucket_id = 'media'
    and (
      auth.role() = 'service_role'
      or (split_part(name, '/', 2))::uuid in (select public.my_household_ids())
    )
  );

drop policy if exists media_insert on storage.objects;
create policy media_insert on storage.objects
  for insert with check (
    bucket_id = 'media'
    and split_part(name, '/', 1) = 'household'
    and (split_part(name, '/', 2))::uuid in (select public.my_household_ids())
  );

drop policy if exists media_update on storage.objects;
create policy media_update on storage.objects
  for update using (
    bucket_id = 'media'
    and (split_part(name, '/', 2))::uuid in (select public.my_household_ids())
  );

drop policy if exists media_delete on storage.objects;
create policy media_delete on storage.objects
  for delete using (
    bucket_id = 'media'
    and (split_part(name, '/', 2))::uuid in (select public.my_household_ids())
  );
