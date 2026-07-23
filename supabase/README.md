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
