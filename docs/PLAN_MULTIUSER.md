# Pet Passport — Multi-User Plan (Household Sharing)

## Status auf einen Blick (2026-07-24)

| M   | Titel                                      | Status                                      |
| --- | ------------------------------------------ | ------------------------------------------- |
| M1  | Auth + Household-Container                 | ✅ shipped                                   |
| M2  | Schema-Erweiterung + Migration             | ✅ shipped                                   |
| M3  | Push (Outbox) + Pull (Delta)               | ✅ shipped (inkl. server-monotoner Cursor)   |
| M4  | Realtime + Live-Status                     | ✅ shipped                                   |
| M5  | Media-Sync (Photos + Documents)            | ✅ shipped (alle 7 Attachment-Surfaces)      |
| M6  | Owner-Kontrollen + Household-Verlassen     | ⏸️ bewusst zurückgestellt (1 HH + 2 User)   |
| M7  | Härtung + Observability                    | ⏸️ zurückgestellt bis vor Store-Release     |

Security-Checkliste: Day-0 komplett bis auf **Redirect-URL-Allowlist** (Dashboard-Config). M1-Quality-Gate (secure-storage session-token, Auth-Rate-Limits, Invite-Rate-Limit, RLS-Test-Suite) und M7-Härtung (hCaptcha, DSGVO-Endpoints, Sentry) offen — alle vor Store-Release.

Legende: ✅ done, ⏸️ bewusst verschoben, [~] teilweise, [ ] offen.

## Context

Bisheriger Zustand: rein lokale Single-User-App. Daten liegen ausschließlich in einer lokalen Drift-SQLite-DB pro Gerät. JSON-Export/Import existiert für Backup und Datenweitergabe.

**Ziel:** Aus der lokalen Single-User-App eine **offline-first, cloud-synchronisierte App** für **Haushalte 2–5 Personen** machen. Alle User können alle Tiere gleichberechtigt sehen und bearbeiten. Auf jedem Gerät weiterhin volle Offline-Funktionalität; Netz bringt Änderungen anderer rein und pusht eigene.

**Bestätigte Weichenstellungen (aus Scoping-Q&A):**

| Dimension       | Entscheidung                                          |
| --------------- | ----------------------------------------------------- |
| Rollenmodell    | Beide/alle gleichberechtigt (Read + Write)            |
| Backend         | **Supabase** (Managed BaaS, Postgres + Auth + Realtime + Storage) |
| Skalierung      | 2 bis ~5 User pro Household                           |
| Offline-Verhalten | Voll offline-fähig, Sync bei Netz (Outbox + Delta-Pull) |

**Warum Supabase statt Firebase:** unser bestehendes Drift-Schema mappt fast 1:1 auf Postgres. Firebase (Firestore) würde eine Doc-Store-Umschreibung erzwingen. Supabase gibt außerdem serverseitiges SQL + Row Level Security, was das Household-Sharing sauber ausdrückt.

## Architektur-Überblick

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Gerät A     │    │  Gerät B     │    │  Gerät C     │
│  Drift SQLite│    │  Drift SQLite│    │  Drift SQLite│
│  + Outbox    │    │  + Outbox    │    │  + Outbox    │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                    │                    │
       └─────────┬──────────┴──────────┬─────────┘
                 ▼                     ▼
         ┌──────────────────────────────────┐
         │  Supabase                        │
         │  ├─ Auth (magic link email)      │
         │  ├─ Postgres (RLS per household) │
         │  ├─ Realtime (row change stream) │
         │  └─ Storage (media)              │
         └──────────────────────────────────┘
```

**Kernpattern:**
- Drift bleibt Source-of-Truth für die UI.
- Ein Sync-Engine-Worker (a) beobachtet lokale Änderungen und schreibt sie in Postgres, (b) horcht auf Postgres-Changes und schreibt sie zurück in Drift.
- UI ist von Sync entkoppelt — reagiert nur auf Drift-Streams.

## Datenmodell-Erweiterungen

### Neue Konzepte

- **`households`** — Container. Jedes Pet gehört zu genau einem Household.
- **`household_members`** — User ↔ Household **many-to-many** mit `role` (owner / member). Ein User kann Mitglied in beliebig vielen Households sein (siehe Abschnitt „Mehrere Households pro User" unten).
- **`invite_codes`** — kurzlebige 8-Zeichen Base32-Tokens, TTL 24h, single-use.
- **`user_profiles`** — Anzeigename pro User (unabhängig von Auth-Mail).

Alle Query-Filter auf Feature-Tables gehen konsequent über die **volle Membership-Liste** des Users:

```sql
WHERE household_id IN (
  SELECT household_id FROM household_members
  WHERE user_id = auth.uid()
)
```

Kein „aktives" Household serverseitig — die Auswahl passiert (wo überhaupt nötig) rein clientseitig auf der UI-Ebene.

### Bestehende Tabellen — additive Änderungen

Alle Feature-Tables (`pets`, `vets`, `contacts`, `appointments`, `medications`, `foods`, `vaccinations`, `insurances`, `events`, `pet_documents`, alle `*_documents` und `*_photos`) bekommen:

| Spalte                 | Typ                  | Zweck                                                 |
| ---------------------- | -------------------- | ----------------------------------------------------- |
| `household_id`         | uuid, **nullable**   | FK auf `households.id`. Null = weiter rein lokaler Datensatz (Cloud-Opt-out) |
| `updated_by_user_id`   | uuid, nullable       | Wer hat zuletzt geändert (für Konflikt-Attribution)   |
| `deleted_at`           | datetime, nullable   | Soft-Delete für sync-Idempotenz                       |
| `dirty` (lokal only)   | bool                 | „Muss noch gepusht werden" — nicht in Cloud-Schema    |

`updated_at` existiert bereits und dient als LWW-Vergleichsanker.

### Warum nullable statt Migration-erzwungen?

Ein bestehender Solo-User, der Cloud nicht will, soll die App weiter nutzen können. `household_id IS NULL` bedeutet „rein lokal". Ein Login löst die Migration aus (siehe unten).

## Mehrere Households pro User

Real-life-Fall: Person A hat mit Person B zwei Hunde, mit Person C einen weiteren. Person A ist Mitglied in **beiden** Households.

**Modell:** `household_members` ist bewusst n:m; ein User kann in beliebig vielen Households Mitglied sein. Rolle (owner/member) ist pro Membership, nicht pro User global.

**UI: alles flach, kein Context-Switch.** Der User sieht alle Pets aus allen seinen Households in einer gemeinsamen Liste. Household ist Metadaten, kein Modus. Bei 2–3 Households mit je 1–3 Tieren bleibt die Liste übersichtlich; ein Household-Picker im AppBar wäre unnötige Reibung.

**Sichtbar wird das Household nur da, wo es Verwechslungsrisiko gibt:**

- **Pet-Verwaltungsliste** (Settings → Meine Tiere): Sub-Label pro Tile, z.B. „Familie Weber" / „WG Kastanienallee"
- **Pet-Detail** unter „Übersicht": klein aufgelistet
- **Auf der Haupt-Übersicht mit fokussiertem Tier**: nicht — wäre Rauschen

**Pet-Anlegen braucht Household-Zuordnung:**

- Bin ich in genau 1 Household → auto-select, nichts weiter zu tun
- Bin ich in mehreren → Pflicht-Dropdown im Pet-Edit-Screen. Default = zuletzt genutzt
- Bin ich in 0 Households (frisch eingeloggt ohne Membership) → beim Login wird automatisch ein „Mein Haushalt" angelegt

**Household verlassen (M6):**

- Nach Austritt verschwinden Pets/Termine/etc. dieses Households aus dem lokalen Cache
- Sie werden **nicht** in „mein eigenes Household" migriert — sie gehören dem verbleibenden Household
- Ausnahme: wenn ich letzter Owner war → Dialog „Owner-Rolle übertragen an…" oder „Household löschen"

**Pet zwischen Households verschieben:** explizit **out-of-scope für MVP.** Klingt selten, ist heikel (Events, Termine, Medikationen hängen dran — sollen die mitwandern?). Nachrüstbar später als Admin-Aktion.

## Sync + Konflikt-Strategie

### Push (lokal → Cloud)

1. **Outbox-Queue**: jede lokale Write-Op geht auch als Eintrag in `pending_ops` (Op-Log pro Row, wholesale replace)
2. **Bei Netz**: FIFO abarbeiten, per Row `upsert` mit `updated_at`-Konflikterkennung
3. **Bei Fehler**: Retry mit exponential backoff (500ms, 2s, 8s, 30s, dann Idle-Poll)

### Pull (Cloud → lokal)

1. **Beim App-Start / bei Wiederverbindung**: Delta-Sync via `updated_at > last_pulled_at` pro Tabelle, gefiltert auf `household_id IN (mein households)`
2. **Realtime**: WebSocket-Subscription für Live-Updates während App im Vordergrund

### Konflikt-Strategie: Last-Write-Wins (LWW) pro Feld

Für dieses Domänenmodell (kleine Haushalte, seltene gleichzeitige Edits am selben Feld) ausreichend. Alternative CRDT wäre Overkill für den Use-Case.

- Simultane Edits verschiedener Felder → kein Konflikt, beides landet
- Simultane Edits **desselben Felds** → höheres `updated_at` gewinnt
- Loser wird nicht komplett verworfen: bleibt in `sync_conflicts_log` (nur lokal, für User-Debug)

### Soft-Delete statt Hard-Delete

Wenn Gerät A offline löscht und Gerät B parallel editiert, verhindert `deleted_at` „Row war weg, ist plötzlich wieder da"-Effekte. Hard-Delete nur nach Grace-Period (7 Tage), außerhalb des Sync-Fensters.

## Media-Handling

- Fotos/PDFs bleiben lokal gecacht für schnelle Anzeige
- Upload zu Supabase Storage in Household-Bucket: `household/<hid>/photos/<uuid>.jpg`
- Download on-demand + LRU-Cache (Größenlimit z.B. 200MB)
- File-Pfade in DB werden zu Storage-Keys statt lokalen Pfaden
- Migration bestehender lokaler Pfade: bei Erst-Upload auf Storage-Keys gemappt, alter Pfad bleibt als Cache-Hint

## Auth

**Magic Link Email** (Supabase Auth Built-in):
- Nutzer:in gibt E-Mail ein → Mail mit Login-Link → App fängt Deep-Link ab
- Kein Passwort-Handling, kein Passwort-Reset
- Session-Token wird im sicheren Storage abgelegt (Flutter Secure Storage)

**Optional (M7): SSO** — Sign in with Apple / Sign in with Google für weniger E-Mail-Reibung. Zurückgestellt bis Kern-Sync steht.

## Migration bestehender lokaler Daten

Flow beim ersten Cloud-Login eines bestehenden Solo-Nutzers:

1. Login triggern → User-ID erhalten
2. Neues Household anlegen, aktueller Nutzer als Owner
3. Alle bestehenden lokalen Rows kriegen den neuen `household_id`
4. Bulk-Push aller Rows in Cloud (Outbox befüllen, dann drain)
5. Media zu Storage hochladen
6. `last_pulled_at` auf `now()` setzen (nichts zu ziehen)
7. Weiter läuft alles wie gehabt, jetzt synchronisiert

**Rückfallebene: Cloud-Opt-out**
- App bleibt lokal nutzbar ohne Login
- „Zu geteiltem Haushalt erweitern" ist ein aktiver Button in Einstellungen
- Keine Zwangsmigration in absehbarer Zukunft

## Einladungs-Flow

Ein serverseitiger Token, drei Präsentationsformen für die Nutzer:in — je nach Situation ist eine schneller als die andere:

### Die drei Präsentationen

**1. QR-Code** — In-Person-Fall
- Owner-Screen zeigt großen QR
- Empfänger:in scannt mit System-Kamera **oder** Scan-Icon in der App
- Zero Typing

**2. Deep-Link (teilbar)** — Distanz-Fall
- Format: `https://petpassport.example.com/invite/<token>` (Universal Link / Android App Link)
- Owner tippt „Link teilen" → System-Share-Sheet → WhatsApp / Signal / Mail
- Empfänger:in tippt Link → App öffnet direkt im Bestätigungs-Screen mit Token vorbefüllt
- Fallback wenn App nicht installiert: Landing-Page mit Store-Link
- **Für MVP genügt ein Custom Scheme (`petpassport://invite/<token>`)** — Universal Link braucht gehostete `apple-app-site-association` + `assetlinks.json`, nachrüstbar wenn die App im Store ist

**3. 8-Zeichen-Text-Code** — Fallback
- Anzeige: `X4KM-9RTW` (Base32, verwechslungsanfällige Chars 0/O/1/I/L ausgeschlossen)
- Empfänger:in tippt „Household beitreten" → Code eingeben
- Für schlechte Kameraverhältnisse, defekten Link-Handler etc.

Alle drei kodieren **denselben** Token. Server generiert einmal, die App rendert dreifach.

### Sicherheit

- **TTL 24 h**, single-use — nach Einlösung invalid
- Owner kann jederzeit **revoken** und einen neuen Code generieren
- Serverseitiges **Rate Limiting** (5 Falscheingaben / IP / Stunde) gegen Brute Force
- Bei Fehlversuchen keine „Code existiert nicht"-Meldung, sondern generisches „Bitte kurz warten" — verrät nicht, ob ein Token existiert
- **QR-Content** enthält die volle Deep-Link-URL, **nicht** nur den Rohcode — dann funktioniert derselbe QR auch, wenn er außerhalb der App gescannt wird

### UI-Flow

**Owner-Seite** (ein Screen, drei sichtbare Wege):

```
┌─────────────────────────────────┐
│ Person einladen                 │
├─────────────────────────────────┤
│      ┌───────────┐              │
│      │  QR-Code  │              │
│      └───────────┘              │
│                                 │
│      X4KM-9RTW                  │
│      (manuell eingeben)         │
│                                 │
│  [ Link teilen ]                │
│                                 │
│  Läuft ab in 23:47 h            │
│  [ Neuen Code generieren ]      │
└─────────────────────────────────┘
```

**Empfänger-Seite** — drei Einstiegspunkte, alle enden im gleichen Bestätigungs-Screen:
- Deep-Link tap → App öffnet direkt mit Token
- In-App-Scanner (Icon im Onboarding + Settings) → analog
- Manuelle Eingabe: „Household beitreten" → Textfeld

**Bestätigungs-Screen** (kein Blind-Join):
```
Du wirst Mitglied im Household „Familie Weber"
mit 2 aktiven Mitgliedern. Beitreten?
                    [ Abbrechen ] [ Beitreten ]
```

### Ende-zu-Ende-Flow

1. Owner tippt „Person einladen" → Server generiert Token (TTL 24 h, single-use)
2. Owner-Screen zeigt QR + Text-Code + „Link teilen"-Button
3. Empfänger:in wählt einen der drei Wege → landet im Bestätigungs-Screen mit Household-Info
4. Bestätigt → Server verknüpft User mit Household (Rolle: member) → RLS gibt sofort Zugriff auf alle Household-Daten
5. Bestehende Daten der Empfänger:in bleiben **unangetastet** in ihren aktuellen Household(s). Das neue Household kommt **additiv** obendrauf — Membership ist n:m. Kein automatisches Merging bestehender Rows in fremde Households, das wäre zu heikel und zu leise für den User.

### Für MVP bewusst weggelassen

- **Personalisierte Einladung** („Anna hat dich eingeladen") — nice-to-have, nachrüstbar
- **E-Mail-Invite als eigener Kanal** — überflüssig, Owner nutzt System-Share für Mail
- **Universal-Link-Setup mit Landing-Page** — kommt wenn die App im Store ist

## Sicherheit / Privacy

### Row-Level-Security in Postgres

Beispiel-Policy für `pets`:

```sql
CREATE POLICY pets_household_access ON pets
  USING (
    household_id IN (
      SELECT household_id FROM household_members
      WHERE user_id = auth.uid()
    )
  );
```

Analog für alle anderen Tabellen. Server-seitig durchgesetzt, kein Client-Trust nötig.

### Storage-Bucket-Policy

Nur Zugriff auf Objekte unter `household/<hid>/…` wenn der User Member dieses Households ist.

### DE-Datenschutz

- Supabase-Instanz in EU-Region (Frankfurt) hosten
- Datenschutzhinweis + Einwilligung beim Sign-up
- „Alle meine Daten löschen"-Button in Settings (DSGVO Art. 17)

## Security-Checkliste

Gestaffelt nach „muss ab Day 0" vs. „kann später inkrementell". Die Trennung ist wichtig: RLS **ohne Ausnahme in M1**, alles andere lässt sich ohne Retro-Migration nachrüsten.

### Day-0 (M1 Schema-Setup) — nicht verhandelbar

- [x] **Row Level Security auf jeder Feature-Table aktivieren.** Migrationen 0001 (households + members + invites + profiles), 0004 (10 Top-Level-Feature-Tables), 0009 (5 nested Attachment-Tables) enablen RLS + Policies auf `my_household_ids()`-Helpers aus 0002.
- [x] **Anon Key vs. Service Role Key sauber trennen.** App bindet nur `SUPABASE_PUBLISHABLE_KEY` via `--dart-define`. Service-Role-Key nirgends im Repo.
- [ ] **Redirect-URL-Allowlist konfigurieren.** Supabase-Dashboard-Config (nicht Code) — bitte manuell setzen: `petpassport://auth/callback` + evtl. `http://localhost:*` für Dev.
- [x] **Storage-Bucket auf privat + Path-basierte Policies.** Migration 0007: private Bucket `media`, Policies gaten auf `split_part(name,'/',2)::uuid IN my_household_ids()`.
- [x] **Storage Mime-Whitelist**: `image/jpeg`, `image/png`, `image/webp`, `application/pdf` auf Bucket-Ebene (0007).

### M1 Quality-Gate (vor Ship des ersten Cloud-Users)

- [ ] **Session-Token in `flutter_secure_storage`** (nicht `shared_preferences`). Aktuell: Supabase-Flutter-Default (Hive im sandboxed App-Data-Dir). Beim Threat-Model „Gerät-Diebstahl mit OS-Lock" reicht das; Store-Release erfordert das Upgrade.
- [ ] **Auth Rate Limits senken**: OTP-Requests von 30/h auf 10/h/E-Mail, Sign-ups auf 5/h. Dashboard-Config, nicht Code.
- [ ] **Invite-Einlöse-Endpoint hat serverseitiges Rate-Limit** (5 Falscheingaben/IP/Stunde). Aktuell: `redeem_invite` RPC ist SECURITY DEFINER mit generischen Fehlern, aber ohne explizites Rate-Limit.
- [ ] **RLS-Test-Suite** (ausführbare Integration-Tests: User A darf 0 Rows von User B sehen, pro Feature-Table). Für lokale Unit-Tests haben wir FakeCloudApi-Assertions, aber kein RLS-Live-Test.

### M7 Härtung (bevor App in Store)

- [ ] **hCaptcha auf Auth-Endpoints** aktivieren (Supabase-Integration, kostenlos für unser Volumen). Reduziert Bot-Sign-ups.
- [ ] **Deep-Link-Token clientseitig gegen Server validieren** bevor was passiert (z.B. „ist der Invite noch gültig?" vor Beitritts-UI).
- [ ] **DSGVO-Rechte in Settings umsetzen**: „Alle meine Daten exportieren" (JSON-Bundle) und „Konto komplett löschen" (Cascade auf alle Rows + Storage-Objects meines Users). Löschung darf nicht andere Household-Member betreffen.
- [ ] **Audit-Log-Sichtung** einmal pro Woche für die ersten Monate (Supabase Dashboard → Auth-Logs, DB-Logs). Ungewöhnliche Muster früh erkennen.

### Optional / später

- **MFA / 2FA** — für Familien-App Overkill. Magic-Link ist passwordless. Mail-Verlust ist der eigentliche Recovery-Fall und wird manuell gelöst.
- **Custom JWT-Claim mit Household-IDs** — reine Performance-Optimierung. Erst wenn RLS-Subqueries messbar bremsen.
- **End-to-End-Encryption** — bewusst nicht MVP. Eigener Milestone falls Anspruch kommt.
- **IP-Allowlisting** — Mobile-App-User wandern zwischen Netzen. Sinnlos hier.

### Was Supabase kostenlos + automatisch mitbringt

Kein Setup nötig, nur zur Beruhigung:
- Verschlüsselung at rest (Postgres AES-256)
- TLS 1.3 in transit
- DDoS-Basisschutz vor der API
- Session-JWT-Signatur mit rotierbarem Secret

## Kosten & Free-Tier

Für 2–5 User pro Haushalt reicht der **Supabase Free Tier** komfortabel. Limits (Stand Anfang 2026 — vor Start gegen supabase.com/pricing checken):

| Kontingent      | Free           | Realistisch für uns                           |
| --------------- | -------------- | --------------------------------------------- |
| Datenbank       | 500 MB         | Textdaten pro Haushalt < 10 MB                |
| Storage (Media) | 1 GB           | ~200–400 Fotos + PDFs — knapp aber machbar    |
| Auth-User (MAU) | 50 000         | Vernachlässigbar                              |
| Bandbreite      | 5 GB/Monat     | Delta-Sync + On-demand Media weit darunter    |
| Realtime        | 200 concurrent | Wir brauchen ~5                               |
| Edge Functions  | 500k invoc./Mo | Marginal (Invite-Code-Handling nur, wenn wir Server-Logik brauchen) |

### Der einzige Haken: Pause nach Inaktivität

Free-Tier-Projekte **pausieren nach ~7 Tagen ohne Datenbank-Aktivität**. Bei sporadischer Familien-Nutzung realistisch. Auto-Resume dauert Sekunden bis eine Minute; kein Datenverlust, aber ein hakender Erst-Sync ist eine schlechte UX für eine App die „einfach da sein soll".

### Mitigationsoptionen (nach Aufwand)

1. **GitHub-Action-Wecker (empfohlen für Start)**
   - Cron-Workflow pingt täglich einen Health-Check-Endpoint der Supabase-DB
   - Free, ~10 Minuten Setup, hält die Instanz wach
   - Fällt aus, sobald wir echten organischen Traffic haben — dann obsolet

2. **Pro-Tier: 25 $/Monat**
   - Keine Pause, 8 GB DB, 100 GB Storage, 250 GB Bandbreite
   - Wenn das App-Wachstum es rechtfertigt oder wir den Wecker-Hack loswerden wollen

3. **Media aus Supabase Storage rauslösen (nur wenn 1 GB knapp wird)**
   - Postgres bleibt bei Supabase, Fotos/PDFs wandern nach Cloudflare R2 (10 GB Free, kein Pause-Effekt)
   - Mehr Wiring (zweiter SDK-Client, andere URL-Signatur), aber deutlich mehr Storage-Headroom

### Entscheidung für Start

**Free Tier + GitHub-Action-Wecker.** Kostet nichts, ist reversibel, und upgrade auf Pro oder R2 ist ein additiver Move, wenn's soweit ist. Storage ist der wahrscheinlichste erste Engpass — Media-Cache-Größe + Kompression sind daher schon in M5 relevant.

---

## Milestones

Jeder Milestone ist eigenständig shipbar. Zwischen Milestones bleibt die App voll funktional.

### M1 — Auth + Household-Container (kein Sync)

**Deliverable:** Login, Household anlegen/beitreten, Members-Liste. Daten bleiben noch rein lokal.

**Acceptance Criteria:**
- [x] Ich kann mich mit Magic Link einloggen und ausloggen
- [x] Ich kann in Einstellungen **alle meine Households** sehen (Name, Member-Liste, meine Rolle pro Household, mein Anzeigename)
- [x] Ich kann als Owner in jedem meiner Households einen Invite-Token generieren (QR + Text-Code + teilbarer Link) und wieder invalidieren
- [x] Ich kann einen Code / Deep-Link / QR einlösen und werde Member — auch wenn ich schon in anderen Households bin (additive Membership)
- [x] Rollen (Owner/Member) werden pro Household korrekt angezeigt; Owner kann Member entfernen
- [x] Ohne Login funktioniert die App weiter wie bisher (Opt-in)
- [x] DSGVO-Datenschutzhinweis in-app + Consent-Gate vor Magic-Link (M1-10)

### M2 — Schema-Erweiterung + Migration lokaler Daten

**Deliverable:** Alle Tabellen kriegen `household_id`, Sync-Metadaten. Bestehende Daten migrieren beim ersten Login sauber.

**Acceptance Criteria:**
- [x] Alle Feature-Tables haben `household_id` (nullable) + `updated_by_user_id` + `deleted_at`
- [x] Drift-Migration auf neuen Schema-Version verläuft idempotent (fresh install + upgrade beide grün)
- [x] Ein Nutzer mit bestehender lokaler DB, der sich erstmalig einloggt, sieht danach alle seine Tiere/Termine/etc. mit `household_id` gesetzt (auto-erstelltes „Mein Haushalt")
- [x] Ein Nutzer, der nicht eingeloggt ist, sieht seine Tiere weiter, `household_id` bleibt null
- [x] Beim Pet-Anlegen erscheint ein Household-Picker, wenn ich in >1 Household bin (Pflichtfeld, Default = zuletzt genutzt); bei genau 1 Household wird still auto-zugeordnet
- [x] In der Pet-Verwaltungsliste zeigt jedes Tier ein Sub-Label mit Household-Namen, wenn ich in >1 Household bin
- [x] Löschungen werden zu Soft-Deletes; UI filtert `deleted_at IS NULL`
- [x] Alle bestehenden Round-Trip- und Repository-Tests bleiben grün

### M3 — Push (Outbox) + Pull (Delta) für Kern-Entities

**Deliverable:** Änderungen an Pet, Vet, Contact, Appointment, Medication, Food, Vaccination, Insurance, Event, Document propagieren zwischen Geräten. Ohne Realtime — noch pull-basiert bei App-Start.

**Acceptance Criteria:**
- [x] Änderung auf Gerät A (Pet umbenennen) erscheint auf Gerät B nach nächstem App-Start
- [x] Offline-Änderung auf Gerät A queued → bei Netz automatischer Push, Gerät B kriegt beim nächsten Pull
- [x] Simultane Edits (Feld X auf A, Feld Y auf B, beide offline) → beide landen ohne Datenverlust, kein Duplicate
- [x] Simultane Edits am **gleichen Feld** → LWW auf Basis `updated_at`, keine Corruption
- [x] Soft-Delete auf A wird auf B respektiert; Rekord verschwindet aus UI
- [x] Sync-Fehler (Netz weg mid-flight) → Retry, keine verlorenen Ops
- [x] Property-based Test: 100 zufällige interleaved Edit-Sequenzen → Konvergenz auf beiden Geräten identisch

**Post-M3 nachgezogen (folgt oben in der Reihenfolge der Auslieferung):**
- Server-monotoner Pull-Cursor `pulled_seq` (Migration 0011) — schließt die Cursor-Race-Lücke, in der zwei Geräte mit Uhr-Drift Rows verlieren konnten. LWW bleibt auf `updated_at`.
- `softDeleteByUuid` bumpt `updated_at` — sonst konnte eine Tombstone von einem älteren Update reverted werden.
- Household-Set wächst → automatischer Cursor-Reset, damit die Pre-Existing-Rows des neuen Households sichtbar werden.

### M4 — Realtime-Updates + Live-Status

**Deliverable:** Änderungen anderer erscheinen live, wenn App vorne ist. Sync-Status in UI sichtbar.

**Acceptance Criteria:**
- [x] App im Vordergrund: Änderung von B erscheint bei A innerhalb ~2 Sekunden
- [x] Sync-Indicator in AppBar (offline / synchronisiert / syncing / Fehler)
- [x] Pending-Ops-Count im Settings/Debug-Screen einsehbar
- [x] Bei Realtime-Verbindungsabbruch fällt App transparent auf Poll-Pull zurück, kein User-Sichtbar

**M4 Bau-Notiz:** Realtime-Publication in Migration 0006. RealtimeEngine + Sync-Status-Badge + Fallback-Pull-Hook alle über einen Riverpod-`myHouseholdsProvider`-Listener.

### M5 — Media-Sync (Photos + Documents)

**Deliverable:** Fotos und PDFs werden hochgeladen, bei Bedarf runtergeladen und lokal gecacht.

**Acceptance Criteria:**
- [x] Neu angehängtes Foto auf A landet in Storage; B sieht ein Thumbnail-Placeholder und lädt beim Öffnen die Datei
- [x] Offline gemachtes Foto queued zum Upload, wird bei Netz automatisch hochgeladen
- [x] Storage-Quota-Behandlung: Fehler abgefangen + verständliche Message (StorageResult ok/retryable/terminal, Terminal parkt mit Message in `last_error` sichtbar über die Sync-Tile)
- [x] Beim Löschen eines Attachments wird auch die Storage-Datei entfernt (Media-Outbox `enqueueDelete` beim soft-delete)
- [x] LRU-Cache limitiert lokalen Media-Speicher (default 200MB) — `MediaFetcher.sweep` bei Cold-Start

**Post-M5 nachgezogen:**
- Alle 5 nested Attachment-Surfaces (event_photos, food_photos, insurance/vaccination/passport_documents) im Sync-System (Phasen 1–5, Migrationen 0009).
- MediaBackfiller für pre-M5 Rows — enqueued Bestandsdaten für Upload beim Cold-Start.
- UploadWorker enqueued Row-Outbox nach Storage-Key-Writeback, damit peers den Key sofort sehen.
- Viewer (PetAvatar + alle Doc-Opener) resolven über `MediaFetcher` — Downloads passieren lazy beim Öffnen.

### M6 — Owner-Kontrollen + Household-Verlassen

**Deliverable:** Feinschliff für Multi-User-Verwaltung.

**Acceptance Criteria:**
- [~] Owner kann Member entfernen; danach hat der ehemalige Member keinen Zugriff mehr (RLS erzwingt) — Remove-Button existiert in M1-09; RLS-Enforcement kommt aus 0001. Lokaler Cache-Cleanup auf der entfernten Seite ist noch nicht implementiert.
- [~] Member kann selbst das Household verlassen — Leave-Button existiert (M1-09), Local-Data-Wahl-Dialog („löschen vs. eigener Haushalt") fehlt.
- [ ] Household löschen (Owner-Recht) mit doppelter Bestätigung; kaskadiert alle Rows + Storage
- [ ] Owner-Übergabe an anderen Member möglich

**Status:** bewusst zurückgestellt — für 1 Haushalt + 2 Personen aktuell nicht dringend.

### M7 — Härtung + Observability

**Deliverable:** Produktionsreife.

**Acceptance Criteria:**
- [x] Retry-Backoff für alle Netzwerk-Ops — PushWorker + UploadWorker: 500ms/2s/8s/30s/idle; Realtime-Channel handhabt eigenen Reconnect.
- [ ] Sync-Konflikte werden im Debug-Log der App gesammelt (`sync_conflicts_log`)
- [ ] Analytics/Sentry: Sync-Fehlerrate, Latenz, Konflikte, aktive Member pro Household
- [~] Backup-Strategie: Supabase-Cronjob-Snapshot (Free-Tier built-in, keine Code-Arbeit) + JSON-Export lokal möglich (existiert seit M6-Solo-Plan)
- [ ] Chaos-Test: Netzwerk-Simulator (delay, loss, jitter) → Sync konvergiert unter allen Bedingungen

**Status:** bewusst zurückgestellt bis vor Store-Release.

---

## Offene Entscheidungen

### Empfehlung ausgesprochen — braucht nur „go" oder Widerspruch

| Punkt                          | Empfehlung im Plan                                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Auth-Flavor (M1)               | Nur Magic Link zum Start. SSO (Google/Apple) frühestens M7+                                             |
| Free-Tier                      | Supabase Free + GitHub-Action-Wecker gegen 7-Tage-Pause. Upgrade auf Pro erst bei Bedarf                |
| Solo-Nutzer-Zwang              | Cloud bleibt dauerhaft opt-in. Migration nur beim ersten freiwilligen Login                             |
| Sync-Test-Strategie            | Unit-Tests gegen Mock-Client + Integration-Tests gegen lokale Supabase-Docker-Instanz (nightly, nicht per PR) |
| Kollaborations-Präsenz         | Nicht MVP. „User X bearbeitet gerade …" frühestens M8+                                                  |
| CRDT statt LWW                 | Bewusst nicht. LWW ist für Familien-Haushalt ausreichend                                                |
| Web-Frontend                   | Bewusst nicht. Nur Mobile                                                                                |

### Vor M1-Start festgezurrt (2026-07-24)

- **Datenschutzhinweis-Text**: Erstwurf entsteht im M1-Zug als `docs/PRIVACY_NOTICE.md` und wird im Sign-up-Screen gerendert. Inhalt: lokal vs. Cloud getrennt, Supabase EU-Frankfurt, Zweck = Household-Sync, keine Analytics, DSGVO-Rechte (Export + komplett löschen).
- **Universal Links**: bewusst out-of-scope. Custom Scheme `petpassport://invite/<token>` für Testphase. Nachrüstung erst bei Store-Release.
- **Anzeigename**: Pflicht. Nach dem Magic-Link-Login zwingender Onboarding-Screen „Wie sollst du in der App heißen?". Kein Skip. E-Mail bleibt privat; Owner sieht sie nur beim Member-Removal-Bestätigen.
- **Free-Tier-Wecker**: GitHub Action in diesem Repo, alle 5 Tage per `curl` gegen `<SUPABASE_URL>/rest/v1/households?select=id&limit=1` (Anon-Key im Header). RLS liefert leere Antwort zurück — reicht, der DB-Query wurde intern ausgeführt und resettet den 7-Tage-Idle-Timer.

### Explizite Nicht-Ziele

- Public / Community-Features (Tier-Teilen mit Fremden, Züchter-Netzwerk etc.)
- Enterprise / Multi-Tenant für Tierheime / Praxen
- End-to-End-Encryption (Supabase-Server sieht Klartext; wenn das mal ein Problem wird → eigener Milestone)
- Pet zwischen Households verschieben (siehe Abschnitt „Mehrere Households pro User")

