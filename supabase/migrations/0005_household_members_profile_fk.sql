-- ---------------------------------------------------------------------------
-- Pet Passport — Add household_members → user_profiles FK for PostgREST
-- ---------------------------------------------------------------------------
-- The members list query embeds the profile's display_name via
-- `select('user_id, role, joined_at, user_profiles(display_name)')`.
-- PostgREST resolves embeds through foreign keys — and until now
-- `household_members.user_id` only had a FK to `auth.users(id)`, so
-- there was no direct relationship between household_members and
-- user_profiles in the schema cache. Result on the client:
--
--   PostgrestException PGRST200 — "Could not find a relationship
--   between household_members and user_profiles in the schema cache."
--
-- Fix: add a second FK from `household_members.user_id` to
-- `user_profiles.user_id`. The auth-layer FK stays in place — the two
-- coexist and serve different purposes:
--   * FK to `auth.users(id)`: auth-layer cascade when the account
--     itself is deleted from Supabase Auth.
--   * FK to `user_profiles(user_id)`: domain-layer relationship
--     PostgREST needs to embed the display name.
--
-- PostgREST does NOT get confused by two FKs on the same column here,
-- because embeds are resolved by *target table*. Embedding
-- `user_profiles(...)` matches only one of the two.
--
-- Precondition: every existing household_members row must have a
-- matching user_profiles row. In the onboarding flow, saveDisplayName
-- runs before any household write (display-name screen gates the
-- router), so this holds by construction. If a stray row without a
-- profile exists on some project, the ALTER will fail with 23503 —
-- fix by inserting the missing user_profiles row before retrying.
--
-- Idempotent: drop-if-exists before add.
-- ---------------------------------------------------------------------------

alter table public.household_members
  drop constraint if exists household_members_user_profile_fkey;

alter table public.household_members
  add constraint household_members_user_profile_fkey
  foreign key (user_id)
  references public.user_profiles(user_id)
  on delete cascade;
