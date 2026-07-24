# Supabase — Migrations

Alle Datenbank-Migrationen liegen in `migrations/` und heißen aufsteigend
nummeriert (`0001_*.sql`, `0002_*.sql`, …). Ausführungsreihenfolge = alphabetisch.

## Migration anwenden (empfohlen)

**Via Supabase CLI** — wenn du sie eh schon nutzt oder magst:

```bash
supabase db push
```

**Via SQL Editor im Dashboard** — ohne CLI:

1. In [supabase.com](https://supabase.com) das Projekt öffnen
2. Linke Sidebar → **SQL Editor** → **+ New query**
3. Inhalt der Migration-Datei rein-copy-pasten
4. **Run** — Fehler-freies grünes Häkchen = fertig

Migrations sind idempotent (`create table if not exists`, `drop policy if exists`
vor `create policy`) — sicher zum Nach-Ausführen wenn ich was ergänze.

## Konvention beim Erweitern

- **Nie** eine bereits deployte Migration nachträglich ändern. Neue Datei mit
  höherer Nummer anlegen.
- Namen sind sprechend: `0002_add_pets_household_fk.sql`, `0003_rls_pets.sql`,
  usw.
- Jede Migration muss `alter table … enable row level security;` für neu
  angelegte Tables enthalten — Supabase-Default ist AUS, das ist der klassische
  Footgun.

## Aktueller Stand

| # | Migration                        | Beschreibung                                            |
| - | -------------------------------- | ------------------------------------------------------- |
| 1 | `0001_multiuser_bootstrap.sql`   | households, household_members, invite_codes, user_profiles, RLS, redeem_invite RPC |
| 2 | `0002_rls_recursion_fix.sql`     | Fix RLS-Rekursion (`42P17`) via `is_member_of` / `is_owner_of` / `my_household_ids` SECURITY-DEFINER-Helper. Policies delegieren Membership-Check an die Helper. |
| 3 | `0003_create_household_rpc.sql`  | `create_household(text)` SECURITY-DEFINER-RPC. Umgeht die 42501-Falle beim client-seitigen `insert into households` und macht Household-Anlage + Owner-Membership in einer Transaction. |
| 4 | `0004_feature_tables.sql`        | pets + 9 Kind-Tables (vets, contacts, appointments, medications, foods, vaccinations, insurances, events, pet_documents). Uuid-PKs, uuid-FKs zu households + Eltern. RLS-Gate `household_id IN my_household_ids()` auf allen. |
| 5 | `0005_household_members_profile_fk.sql` | Zweite FK `household_members.user_id → user_profiles.user_id`. Ohne die kann PostgREST das `user_profiles(display_name)`-Embed im Mitglieder-Query nicht auflösen (PGRST200). |
| 6 | `0006_realtime_publication.sql`  | Fügt alle 10 Feature-Tables der `supabase_realtime`-Publication hinzu. Ohne feuert kein `postgres_changes`-Event, egal wie der Client subscribed. |
| 7 | `0007_media_storage.sql`         | Privater Storage-Bucket `media` + RLS auf `storage.objects`. Pfad-Layout `household/<hid>/…`; Zugriff gated auf `my_household_ids()`. Mime-Whitelist (JPEG/PNG/WebP/PDF), 20 MB max pro Objekt. |
| 8 | `0008_media_storage_keys.sql`    | `profile_photo_storage_key` auf `pets`, `storage_key` auf `pet_documents`. Row-Sync propagiert diese Keys — der Download-Fetcher resolved sie zur Laufzeit gegen den Bucket aus 0007. |
| 9 | `0009_nested_attachment_tables.sql` | Cloud-Tables für die 5 nested Attachment-Surfaces (event_photos, food_photos, insurance_documents, vaccination_documents, pet_passport_documents). Uuid-PKs, uuid-FKs zu Parent + household, RLS-Gate, storage_key nullable, Realtime-Publication. |
| 10 | `0010_drop_pets_dead_cols.sql`   | Mechanical cleanup: drop `markings` + `tasso_registered_at` from pets. Never rendered in UI; dead weight after pet-edit clobber fix. |
| 11 | `0011_pulled_seq.sql`            | Server-monotonic pull cursor: `sync_seq` sequence + `pulled_seq bigint` column + BEFORE-INSERT/UPDATE trigger on all 15 synced tables. Fixes the cursor-race window where two clients with skewed clocks (or delayed drains) could leave rows behind an already-advanced `updated_at` cursor forever. |
