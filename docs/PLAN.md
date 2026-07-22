# Pet Passport — Implementation Plan

## Context

Greenfield Flutter app zur lokalen Verwaltung von Haustieren (Hund/Katze). Ziel: eine private Datenbank für Basisdaten, Tierärzte, Versicherungen, Impfungen, Diät, Medikationsplan, Termine (inkl. wiederkehrende) und ein Protokoll mit spezifischen und generischen Events (inkl. Gewicht, Fütterungsverhalten, Aktivität/Gassi). Ergänzt um: Onboarding beim Erststart, Notfall-Info-Screen, Gewichtsverlauf-Chart, Timeline-Feed, PDF-Export (Impfpass/Übersicht/Notfall-Blatt) und optionalen Biometrie-App-Lock. Kein Cloud-Backend — Daten liegen ausschließlich auf dem Gerät. Export als CSV/JSON und JSON-Import ermöglichen Datenweitergabe (z.B. an Tierarzt) und Backup/Restore. Aggregate-Boundaries so gewählt, dass Cloud-Sync (Firebase o.ä.) später als M7+ additiv ergänzbar ist.

**Repo-Zustand:** komplett leer außer `LICENSE`. Alles wird neu aufgebaut.

**Bestätigte Entscheidungen:**
- Plattform: **Android only** (vorerst)
- Sprachen: **DE + EN**, i18n von Anfang an, DE default
- Media: Profilfoto pro Tier, PDF/Bilder für Versicherung/Impf-Dokumente, Fotos an Protokoll-Events
- Stack: **Flutter + Riverpod (mit codegen) + Drift (SQLite) + go_router**
- Impfungen: eigene Kategorie mit Impfhistorie und Erinnerungen
- Termine: wiederkehrend (daily/weekly-bitmask/monthly, bis-Datum, plus Exception-Slots)
- Reminder: Local Notifications + In-App Dashboard
- Backup: Export CSV/JSON + JSON-Import (voller Zyklus, ZIP-Bundle wenn Media enthalten)

## Architektur-Überblick

**Feature-first Struktur** mit `core/` shared layer. Skaliert besser ab 3-4 Features und ist gängig in der Flutter/Riverpod-Community.

```
lib/
├── main.dart                        # ProviderScope + bootstrap
├── app/                             # app.dart, router.dart, theme.dart
├── core/
│   ├── db/                          # Drift database, tables/, daos/, converters/
│   ├── media/                       # MediaService (Pfade + Copy/Delete)
│   ├── notifications/               # NotificationService + IDs
│   ├── time/                        # recurrence.dart (Expansion)
│   ├── errors/, extensions/, widgets/
├── features/
│   ├── pets/ vets/ insurances/ vaccinations/ diet/
│   ├── appointments/ events/ reminders/ dashboard/
│   ├── export_import/ settings/
│   └── (jedes feature: data/ domain/ application/ presentation/)
├── l10n/                            # app_de.arb, app_en.arb
└── generated/                       # gitignored: drift/freezed/riverpod/l10n
test/                                # unit + widget
integration_test/                    # e2e flows
```

**Naming:** files `snake_case`, classes `PascalCase`, providers `xyzProvider`. Drift tables plural (`Pets`), domain models singular (`Pet` via freezed). Repositories mappen Drift-Rows → Freezed-Domain — Presentation sieht nie Drift-Rows.

## Datenmodell (Drift Schema v1)

**Konventionen:**
- Integer PK `autoIncrement` + `uuid TEXT UNIQUE` auf allen Root-Entitäten (für stabile Export/Import-Referenzen).
- Soft-delete (`deleted_at INTEGER NULL`) auf Root-Entitäten (pets, appointments, events). Hard-delete auf Leaves.
- FKs: `ON DELETE CASCADE` für owned children; `ON DELETE SET NULL` für optionale Referenzen (z.B. vaccination.vet_id).
- Enums als `INTEGER` mit Drift `TypeConverter`. Timestamps als `INTEGER` (unix millis).
- Snapshot der Schema-Versionen ab Tag 1 in `drift_schemas/` (via `drift_dev make-migrations`).

**Tabellen** (Details in Plan-Anhang):
- `pets` (name, species, breed, sex, dob, color, markings, chip_number, tasso_number, tasso_registered_at, profile_photo_path, notes, timestamps, deleted_at)
- `pet_weights` (pet_id, measured_at, weight_kg, note) — Gewichts-Historie
- `vets` (pet_id, name, practice, address, phone, email, notes)
- `insurances` (pet_id, provider, policy_number, contract_start/end, notes)
- `insurance_documents` (insurance_id, file_path, mime_type, original_filename, size_bytes)
- `vaccinations` (pet_id, vaccine_name, administered_at, next_due_at, vet_id?, batch_number, notes)
- `vaccination_documents` (spiegelt insurance_documents)
- `foods` (pet_id, brand, name, food_type, portion_grams, frequency_per_day, times_of_day JSON, is_active, started_at, ended_at) — aktiv + Historie über `ended_at`
- `appointments` (pet_id, vet_id?, type, title, starts_at, duration_minutes, location, notes, recurrence_freq, recurrence_interval, recurrence_weekdays bitmask, recurrence_until)
- `appointment_reminders` (appointment_id, offset_minutes) — 1..n Offsets pro Termin
- `appointment_exceptions` (appointment_id, occurrence_start, is_cancelled, override_starts_at) — Skip/Override einzelner Occurrences
- `medications` (pet_id, name, dosage_amount, dosage_unit, freq_type [daily/weekly/interval_days], freq_interval, freq_weekdays bitmask, times_of_day JSON [HH:mm], starts_at, ends_at?, is_active, notes, prescribed_by vet_id?) — dauerhafte Medikation mit Reminder-Plan
- `medication_reminders` (medication_id, offset_minutes) — Vorlaufzeit vor jedem Zeitpunkt (default 0)
- `medication_intakes` (medication_id, taken_at, skipped, note) — Log der tatsächlichen Einnahmen (Adherence-Tracking optional)
- `events` (pet_id, event_type, occurred_at, payload_json, note) — payload typisiert per event_type (weight/feeding/medication/symptom/activity/generic). `activity`-Payload: `{ distance_m, duration_min, activity_type }`.
- `event_tags` (name UNIQUE) + `event_tag_links` (m:n)
- `event_photos` (event_id, file_path)
- `settings` (key/value) — locale, theme, default reminder offset, app_lock_enabled, onboarding_completed, **current_pet_uuid** (aktives Tier im PetContext, persistent)

**Indices** auf `(deleted_at)`, `(pet_id, occurred_at DESC)`, `(next_due_at)`, `(starts_at)` für Dashboard/Filter-Queries.

## Aggregate-Boundaries

**Motivation:** Klare Aggregate-Grenzen jetzt festlegen, damit spätere Cloud-Sync-Ergänzung (z.B. Firebase Firestore als M7+) das Mapping 1:1 pro Aggregat vornimmt — ohne Rewrite des lokalen Schemas. Kostet aktuell 0 Extra-Aufwand, spart 1-2 Wochen bei einer Migration.

**Aggregat = Einheit die zusammen gelesen, geschrieben und synchronisiert wird.** Innerhalb eines Aggregats: Cascade-Delete, Konsistenz-Garantie. Zwischen Aggregaten: nur lose Referenzen per UUID.

**Definierte Aggregate:**

| Aggregate Root | Zugehörige Tabellen | Firestore-Mapping (später) |
|---|---|---|
| **Pet** | `pets` + `pet_weights` | `/users/{uid}/pets/{pet_uuid}` + Sub-Collection `weights/` |
| **Vet** | `vets` | `/users/{uid}/pets/{pet_uuid}/vets/{vet_uuid}` |
| **Insurance** | `insurances` + `insurance_documents` | `/users/{uid}/pets/{pet_uuid}/insurances/{ins_uuid}` + Sub-Collection `documents/` |
| **Vaccination** | `vaccinations` + `vaccination_documents` | `/users/{uid}/pets/{pet_uuid}/vaccinations/{vac_uuid}` + Sub-Collection `documents/` |
| **Food** | `foods` | `/users/{uid}/pets/{pet_uuid}/foods/{food_uuid}` |
| **Appointment** | `appointments` + `appointment_reminders` + `appointment_exceptions` | `/users/{uid}/appointments/{appt_uuid}` + Sub-Collections `reminders/` und `exceptions/` |
| **Medication** | `medications` + `medication_reminders` + `medication_intakes` | `/users/{uid}/pets/{pet_uuid}/medications/{med_uuid}` + Sub-Collections `reminders/` und `intakes/` |
| **Event** | `events` + `event_tag_links` + `event_photos` | `/users/{uid}/events/{event_uuid}` (tags als Array, photos als Sub-Collection) |
| **Tag** (global) | `event_tags` | `/users/{uid}/tags/{tag_uuid}` |
| **Settings** | `settings` | `/users/{uid}/settings/{key}` |

**Cross-Aggregate-Referenzen (lose, per UUID):**
- `Vaccination.vet_uuid` → Vet-Aggregate
- `Appointment.pet_uuid`, `Appointment.vet_uuid` → Pet-/Vet-Aggregate
- `Medication.pet_uuid`, `Medication.prescribed_by_vet_uuid` → Pet-/Vet-Aggregate
- `Event.pet_uuid` → Pet-Aggregate
- `Event.tag_uuids[]` → Tag-Aggregate
- `Food.food_uuid` (in Feeding-Event-Payload) → Food-Aggregate
- `Medication.medication_uuid` (in Medication-Intake-Event-Payload) → Medication-Aggregate

**Regeln:**
1. **Cascade-Delete nur innerhalb eines Aggregats** (via Drift FK `ON DELETE CASCADE`). Zwischen Aggregaten `ON DELETE SET NULL` oder App-Level-Handling.
2. **Referenzen zwischen Aggregaten immer per UUID**, nicht per Integer-PK — Integer-PKs sind lokal, UUIDs sind portabel und sync-fähig.
3. **Repository-API in Aggregate-Grenzen denken** — z.B. `PetRepository.getPetAggregate(uuid)` liefert Pet + Weights zusammen, nicht separate `getPet` + `getWeights` Calls. Reduziert N+1-Queries und macht Sync-Payloads deterministisch.
4. **1-MiB-Größenlimit im Kopf behalten** (Firestore-Constraint) — Aggregate mit potenziell unbeschränktem Wachstum (Weights über Jahre, Vaccinations, Events, Photos) nutzen Sub-Collections statt eingebetteter Arrays.
5. **Cross-Aggregate-Konsistenz** ist eventual, nicht transaktional. Beispiel: Vet löschen ⇒ Vaccinations behalten UUID-Referenz, UI zeigt "Tierarzt gelöscht" statt Cascade-Löschung.

**Impact auf Code-Struktur:**
- Repositories exposen Aggregate-Methoden (`getPetAggregate`, `savePetAggregate`) zusätzlich zu Fine-Grained-Streams für Listen-Views
- Freezed-Domain-Modelle spiegeln Aggregate: `Pet` enthält `List<PetWeight> weights`, `Appointment` enthält `List<ReminderOffset> reminders + List<AppointmentException> exceptions`
- Export/Import arbeitet auf Aggregate-Ebene (1 JSON-Node pro Aggregate-Root, Children eingebettet)

## State Management (Riverpod)

**Package:** `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` (codegen).

**Layer:**
1. **Infrastructure providers** (Singletons): `databaseProvider`, `mediaServiceProvider`, `notificationServiceProvider`
2. **Repository providers**: dünne Wrapper über Drift DAOs. Return `Stream<List<T>>` (via Drift `watch()`) oder `Future<T?>`. Mappen zu Freezed-Domain-Models.
3. **Query providers**: `StreamProvider` für Listen (Drift ist stream-native). Family-Provider für ID-basiert (`petByIdProvider(int)`).
4. **Controller providers** (`AsyncNotifier`): für Actions/CRUD-Flows. Validation → repository call → `AsyncError`/`AsyncData`. UI hört via `ref.listen` für Snackbar/Nav.
5. **Form state**: `flutter_hooks` oder simple Controller — kein Riverpod für rein transiente Formfelder.

**Regel:** Repositories abhängen nicht voneinander. Controller dürfen mehrere Repositories nutzen.

## Navigation (go_router)

**UX-Modell: Pet-as-Profile.** Das aktuell gewählte Tier ist der App-Kontext (wie ein Konto/Profil in Social-Apps). Die Bottom-Nav zeigt **tierspezifische** Funktionen — nicht "Tiere" als Tab. Tierwechsel und globale Funktionen erfolgen über AppBar/Header.

**Root-Verhalten:**
- 0 Tiere → Onboarding → erstes Tier anlegen → wird `current_pet_uuid`
- 1+ Tiere → App startet direkt im PetContext des zuletzt genutzten Tiers
- `current_pet_uuid` in `settings`-Table gespeichert (persistent über Sessions)

**PetContext-Shell (`StatefulShellRoute.indexedStack`):**
- **AppBar links:** aktuelles Tier-Avatar + Name → Tap öffnet Bottom-Sheet mit allen Tieren + "Tier hinzufügen" + "Tiere verwalten"
- **AppBar rechts:** More-Icon (⋮) → Popup mit Emergency, Vets, Insurances, Chart, PDF, Settings, Switch Pet, Export, Import
- **Bottom-Nav:** 4 tierspezifische Tabs (Inhalt pro Milestone wachsend, siehe Tabelle)

**Bottom-Nav-Slots (pro Milestone gefüllt):**

| Tab | M1 | M2 | M3 | M4 | M5 | M6 |
|---|---|---|---|---|---|---|
| **Home** (Overview) | Basisdaten | + Vets/Insurances-Kacheln | + Impfstatus-Kachel | + Termine-Kachel | + Chart-Kachel | + PDF-Quick-Actions |
| **Termine** | (leer, EmptyState) | (leer) | Impfungen | + Appointments + Medications | (nur upcoming) | + PDF-Export |
| **Alltag** | (leer, EmptyState) | (leer) | (leer) | (leer) | Diät + Protokoll (+ Fütter-Reminder) | + Timeline-Filter |
| **Mehr** | Settings | + Vets, Insurances | + Emergency | (unverändert) | + Chart | + PDF, Export, Import, App-Lock |

Anmerkung: In M1/M2 sind "Termine" und "Alltag" leere Placeholder-Tabs (mit `EmptyState`-Widget), damit die Nav-Struktur nicht später bricht.

**Route-Struktur:**
```
/onboarding                     → OnboardingWizard
/                               → PetContext Shell (redirects to /home)
  /home                         → OverviewScreen (Home-Tab, aktuelles Tier)
  /termine                      → TermineScreen
  /alltag                       → AlltagScreen
  /mehr                         → MoreScreen
/pets                           → PetManagementScreen (Verwaltung, Löschen, Reihenfolge)
/pets/new                       → PetEditScreen
/pets/:id/edit                  → PetEditScreen
/pets/:id/vaccinations/new      → VaccinationEditScreen (Ziel aus /termine)
/pets/:id/vaccinations/:vid/edit
/pets/:id/medications/new
/pets/:id/medications/:mid/edit
/pets/:id/appointments/new
/pets/:id/events/new
/pets/:id/pdf                   → PdfExportMenu
/settings                       → SettingsScreen
/export                         → ExportWizard
/import                         → ImportScreen
/timeline                       → TimelineScreen (cross-pet)
```

Tierwechsel: Bottom-Sheet mit PetList, Tap ändert `current_pet_uuid` in Settings-Table → PetContext-Provider `watch` → alle Tabs rebuilden mit neuen Daten. Kein Route-Wechsel nötig.

**App-Lock:** Bei aktiviertem Lock zwingt Router beim App-Resume auf `/lock`-Overlay bis Biometrie/PIN bestätigt.

**Migration von M1-Baseline:**
M1 shipped mit `Pets | Settings`-Bottom-Nav und PetListScreen als Home. Zu Beginn von M2 wird umgebaut auf PetContext-Shell:
1. Neuer Provider `currentPetProvider` liest `current_pet_uuid` aus Settings
2. Router-Shell mit 4 Tabs (Home/Termine/Alltag/Mehr)
3. PetDetail-Overview-Content wird zum Home-Tab (mit Pet aus `currentPetProvider`)
4. PetList wird zum Bottom-Sheet + separate `/pets`-Route für Verwaltung
5. Redirect: nach erfolgreichem Onboarding → Home statt PetList

Kein Datenmodell-Impact — reines UI-Refactoring. `current_pet_uuid` als neuer Settings-Key (kein Schema-Bump nötig, da `settings` bereits key/value ist).

## UI Layer (Material 3)

`useMaterial3: true`, `ColorScheme.fromSeed` (Seed z.B. Teal), light + dark, `ThemeMode.system` default.

**Screens:** OnboardingWizard, **OverviewScreen** (Home-Tab, pet-context), **TermineScreen** (Termine-Tab), **AlltagScreen** (Alltag-Tab), **MoreScreen** (Mehr-Tab), PetManagementScreen, PetEditScreen, EmergencyScreen, VaccinationEdit, MedicationEdit, DietEdit, VetEditScreen (aus Mehr), InsuranceEditScreen, WeightChartScreen, AppointmentEditScreen, EventEditScreen, TimelineScreen (cross-pet), PdfExportMenu, ExportWizard, ImportScreen, SettingsScreen, LockScreenOverlay, **PetSwitcherSheet**.

**Home-Tab (Overview) — Content pro Milestone:**
M1: Basisdaten-Kacheln (Name, Species, Sex, DOB, Chip/Tasso, Notizen)
M2: + Vets-Kachel (Anzahl, Direktzugriff), Insurances-Kachel
M3: + Impfstatus-Kachel (nächste fällige Impfung, Countdown), Emergency-Quick-Access
M4: + Nächste-Termine-Kachel (heute + Woche), Medikamente-Kachel (aktive Medis heute)
M5: + Aktuelles-Gewicht-Mini-Chart, Fütter-Zeiten heute
M6: + Quick-Actions "Impfpass als PDF", "Passport-PDF", "Notfall-Blatt"

**Shared widgets:** `PetAvatar`, `AgeBadge` (computed aus DOB: Welpe/Junior/Adult/Senior), `EmptyState`, `SectionHeader`, `LoadingScaffold`, `ErrorScaffold`, `DatePickerField`, `TimePickerField`, `DateRangePickerField`, `EnumDropdown<T>`, `PhotoPickerTile`, `DocumentAttachmentTile`, `ConfirmDeleteDialog`, `RecurrenceEditor`, `ReminderOffsetChips`, `TagChipInput`, `WeightLineChart` (fl_chart-basiert), `QrCodeCard` (Emergency-QR mit Chip/Kontakt), `PdfPreviewSheet`, `BiometricLockOverlay`.

## Media Storage

**Layout** unter `getApplicationDocumentsDirectory()`:
```
<app_docs>/media/
├── pets/<pet_uuid>/profile.jpg
├── insurances/<ins_uuid>/<doc_uuid>.<ext>
├── vaccinations/<vac_uuid>/<doc_uuid>.<ext>
└── events/<event_uuid>/<photo_uuid>.jpg
```

**Regeln:**
- DB speichert **relative Pfade**. `MediaService.resolve(path)` gibt absoluten Pfad zur Read-Zeit — überlebt OS-Pfad-Änderungen.
- Save: `image_picker`/`file_picker` liefert Temp-Pfad → `MediaService` kopiert zu kanonischer UUID-Location → DB-Row schreiben.
- Delete: DB-Row-Delete → `MediaService.deleteFile()` in gleicher Transaktion.
- **Startup-Sweep:** Bei App-Start `media/` scannen und Files ohne DB-Referenz löschen (bounded, 1x pro Session).
- Optional ab M5: `flutter_image_compress` für Profilfotos > 1 MB.

## Notifications

**Packages:** `flutter_local_notifications` + `timezone` + `permission_handler`.

**Setup in `NotificationService.init()` vor `runApp`:**
- Android init + `AndroidInitializationSettings('@mipmap/ic_launcher')`.
- Runtime-Permission `POST_NOTIFICATIONS` (Android 13+).
- `SCHEDULE_EXACT_ALARM` (Android 12+) über `AndroidFlutterLocalNotificationsPlugin.requestExactAlarmsPermission()`. Fallback: `AndroidScheduleMode.inexactAllowWhileIdle`.
- `tz.initializeTimeZones()` + Device-TZ bei Boot merken.

**Scheduling:**
- Deterministische Notification-IDs = Hash(entity-uuid + slot + offset) → idempotent.
- **Appointments:** bei Save nächste N (30) Occurrences in 60-Tage-Horizont expandieren, pro Occurrence × Reminder-Offset eine Notification. Re-run bei App-Start, Edit, TZ-Change.
- **Vaccinations:** single Notification bei `next_due_at - default_offset` (default 1 Woche).
- **Medications:** wie Appointments, aber Occurrence-Expansion aus `freq_type` + `times_of_day` (z.B. täglich 08:00 + 20:00). Ende bei `ends_at`. Reminder-Offset default 0 (zum Zeitpunkt).
- **Feeding-Reminders (optional, Setting-Toggle pro `foods`-Eintrag):** pro `foods.times_of_day` und aktivem Eintrag eine tägliche Notification. Wiederholend, kein Ablaufdatum. Bei Diät-Wechsel (`is_active=false`) alle abgemeldet.
- Payload = JSON mit Entity-Type + ID → Tap öffnet Deep-Link via go_router.

**Reliability-Kommunikation:** Doze/App-Standby kann Notifications verzögern. In Settings kurzer Hilfe-Text statt Foreground-Service.

## Recurring Appointments

**Custom-Struct** in `appointments` (nicht RRULE) — deckt alle Anforderungen ab, einfach zu testen.

Helper `core/time/recurrence.dart`:
```dart
Iterable<DateTime> expand(Appointment appt, {required DateTime from, required DateTime to, int? limit})
```
- `none` → nur `starts_at` in Range.
- `daily` → `starts_at + interval * n days`.
- `weekly` → für jede Woche `n`, iteriere Weekday-Bitmask.
- `monthly` → `DateTime(year, month + n*interval, day)`, clamp für kurze Monate.
- Respektiert `recurrence_until` (inclusive) + `appointment_exceptions` (skip/override).

**Migrationspfad:** API stabil halten — bei Bedarf durch `rrule`-Package austauschbar.

**Edge-Cases früh testen:** Monatlich am 31., DST-Übergänge, Weekday-Bitmask korrekt (Mo=1).

## Export/Import

**Export-Wizard (4 Schritte):**
1. Tier wählen (skip wenn nur 1). "Alle Tiere" möglich.
2. Scope: nur Basisdaten / Basis + Protokoll.
3. Zeitraum (nur bei Protokoll): from/to oder "alles".
4. Format: CSV oder JSON → generate → `share_plus`.

**JSON-Format (versioniert):**
```json
{
  "schema_version": 1,
  "exported_at": "2026-07-22T10:00:00Z",
  "app_version": "1.0.0",
  "pets": [{ "uuid": "...", "name": "...", "vets": [...], "insurances": [...], "vaccinations": [...], "foods": [...], "weights": [...], "appointments": [...], "events": [...] }]
}
```
- Mit Media: **ZIP-Bundle** (`archive` package) mit `data.json` + `media/`. Text-only-Variante ohne Media als reine `.json`.
- `schema_version` im Root → Import migriert alte Versionen aufwärts.

**CSV-Format:** ZIP mit einer CSV pro Entity (`pets.csv`, `vaccinations.csv`, …), Cross-Referenz per UUID. Package `csv`. Header-Row, Booleans `true`/`false`, Timestamps ISO 8601.

**Import (nur JSON):**
- `file_picker` → parse → schema-migrate → in Drift-Transaktion einspielen.
- Match per `uuid`. Konflikt-Strategie (User wählt vorher):
  - Skip existing (default)
  - Overwrite with imported
  - Merge per-field newer `updated_at` (deferred M6)
- Summary: `X added, Y updated, Z skipped, N conflicts`.

## PDF-Export

**Use-Case:** Weitergabe an Tierarzt, Grenzübertritt, Pension, Hundeschule — offizielles Dokument statt CSV/JSON.

**Packages:** `pdf` (^3.11) für Generierung, `printing` (^5.13) für System-Print/Share.

**Verfügbare PDF-Templates (`lib/features/pdf/templates/`):**
1. **Impfpass** — pro Tier alle Impfungen chronologisch mit Impfstoff, Datum, Fälligkeit, Tierarzt, Batch-Nr. Ergänzt DIN-A6-Format (klassischer Heftlayout) oder DIN-A4-Liste.
2. **Pet-Passport-Übersicht** — Deckblatt (Foto + Basisdaten) + Chip/Tasso + Notfall-Kontakte + aktuelle Medikamente + Impfstatus + Versicherung. DIN-A4, 2-3 Seiten.
3. **Einzelnes Dokument** — Passthrough eines gespeicherten PDFs (aus Insurance-/Vaccination-Documents) mit App-Header/-Footer für Kontext.
4. **Notfall-Blatt** — 1-seitiges DIN-A4 mit Foto, Chip/Tasso, Tierarzt-Kontakt, Medikamente, Allergien, aktuelles Gewicht, optional QR-Code mit vCard-Kontakt.

**Flow:** Pet-Detail → Icon "PDF" → PdfExportMenu → Template wählen → Preview → Share/Print (`printing.Printing.sharePdf` oder `layoutPdf`).

**i18n:** PDF-Strings über gleiches ARB-System wie App (deutsche/englische Templates auto-selektiert).

## App-Lock (Biometrie)

**Package:** `local_auth` (^2.3) + `local_auth_android` für Android-spezifische Optionen.

**Verhalten:**
- Setting `app_lock_enabled` (default false) in `settings`-Table.
- Bei aktiviertem Lock zeigt App beim Start und bei App-Resume (aus Hintergrund) `BiometricLockOverlay` — App-Inhalt gesperrt bis Auth.
- Auth-Methoden: Fingerprint / Face-Unlock (Gerät-abhängig) mit PIN/Pattern als Fallback (System-liefert).
- Grace-Period konfigurierbar (z.B. 30s Toleranz beim App-Switch), default 0.
- Bei Nicht-Verfügbarkeit (kein Biometrie-Setup auf Gerät): Setting kann nicht aktiviert werden, Info-Snackbar.
- Screenshot-Blocker (`FLAG_SECURE`) optional als zweite Setting-Option, verhindert App-Content im Task-Switcher-Preview.

**Persistenz:** Auth-State wird **nicht** persistiert — jeder Cold-Start und App-Resume triggert erneut. Daten selbst bleiben unverschlüsselt in SQLite (Android-App-Sandbox schützt Rest).

## i18n

`flutter_localizations` + `intl` + built-in `flutter gen-l10n`.

`l10n.yaml`:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-class: AppL10n
```

- Supported: `de` (first → wins bei nicht-en/de Geräten), `en`.
- Locale-Override in `settings`-Table, in `MaterialApp.router.locale` verdrahtet.
- Key-Convention: screen-scoped (`pets_list_title`), actions (`action_save`), enums (`species_dog`), errors (`error_generic`). Named placeholders + plurals.
- Disziplin: **keine hardcoded Strings** im Code.

## Testing

| Layer | Package |
|---|---|
| Unit — repositories/services | `flutter_test` + Drift `NativeDatabase.memory()` |
| Unit — recurrence expansion | `flutter_test` mit deterministischen Fixtures |
| Widget — screens | `flutter_test` + `mocktail`, Provider-Overrides |
| Golden — stable widgets | `alchemist` (später) |
| Integration | `integration_test` — end-to-end Flows |

Helpers: `test/helpers/database_helper.dart` (in-memory DB), `test/helpers/pump_app.dart` (min. ProviderScope + MaterialApp). Repositories gegen echte in-memory DB testen (kein Mock). Coverage-Ziel: 70% auf `core/` + `data/`.

## Milestones

Sechs shipbare Milestones, jeder liefert ein nutzbares Build.

**M1 — Foundation + Pet CRUD + Onboarding (~1-2 Wochen)**
- Scaffold, Deps, Struktur, Codegen wiring.
- Drift v1: `pets`, `pet_weights`.
- Theme, i18n scaffold, go_router shell.
- **OnboardingWizard** (first-launch: "Willkommen → Erstes Tier anlegen"), Setting `onboarding_completed`.
- PetList + PetEdit + PetDetail (nur overview tab) mit `AgeBadge` (Welpe/Junior/Adult/Senior computed aus DOB + Species).
- Profilfoto via `image_picker`.
- Settings (Locale + Theme).
- **Ship:** Tiere anlegen/bearbeiten/löschen mit Foto, Onboarding beim Erststart.

**M2 — Pet-Profile-Refactor + Vets, Insurances, Documents (~1-2 Wochen)**
- **PetContext-Shell-Refactor** (Pet-as-Profile, siehe Navigation-Sektion):
  - `currentPetProvider` liest `current_pet_uuid` aus Settings
  - Router-Shell mit 4 Tabs (Home / Termine / Alltag / Mehr)
  - OverviewScreen als Home-Tab (Content = ehemaliger PetDetail-Overview)
  - PetSwitcherSheet als Bottom-Sheet über AppBar-Avatar
  - PetManagementScreen als `/pets`-Route
  - Empty-Placeholder-Screens für Termine + Alltag
- Drift v2: `vets`, `insurances`, `insurance_documents`.
- Vets- und Insurances-Screens (aus Mehr-Tab erreichbar).
- Home-Tab bekommt Vets-Kachel + Insurances-Kachel.
- `file_picker` für PDF/Bilder.
- **Ship:** Pet-Profile-UX, Kontakte + Dokumente pro Tier.

**M3 — Vaccinations + Reminders + Emergency-Info (~2 Wochen)**
- Drift v3: `vaccinations` (+ optional `vaccination_documents`).
- Vaccinations tab + edit screen.
- `NotificationService` init inkl. Permission-Flow.
- Dashboard-Skelett mit anstehenden Impfungen.
- **Emergency-Info-Tab** in Pet-Detail: Chip/Tasso, Tierarzt-Kontakte, aktuelles Gewicht, Allergien (Freitext), optional QR-Card mit vCard.
- **Ship:** Impftracking mit lokalen Notifications + Notfall-Übersicht.

**M4 — Appointments + Medications + Recurrence (~2-3 Wochen)**
- Drift v4: `appointments`, `appointment_reminders`, `appointment_exceptions`, `medications`, `medication_reminders`, `medication_intakes`.
- `RecurrenceEditor` + Expansion-Helper (mit Unit-Tests für Edge-Cases).
- AppointmentList + AppointmentEdit.
- **Medications-Tab + MedicationEdit** (Dosierung, Frequenz, Zeitpunkte, Prescribed-By-Vet).
- Notification-Scheduling für Recurring-Appointments + Medications (shared Expansion-Logic).
- Dashboard vereint Termine + Impfungen + Medikamente.
- **Ship:** volle Termin- und Medikationsverwaltung mit wiederkehrenden Notifications.

**M5 — Diet + Protocol/Events + Charts + Feeding-Reminders (~2 Wochen)**
- Drift v5: `foods`, `events`, `event_tags`, `event_tag_links`, `event_photos`.
- Diät tab (aktiv + Historie).
- Protokoll tab mit typ-spezifischen Formularen (weight/feeding/medication-intake/symptom/**activity**/generic).
- Event-Fotos, Tags.
- Weight-Event schreibt zusätzlich in `pet_weights`.
- **Weight/Growth-Chart-Tab** mit `fl_chart` (Zeitachse + Trendlinie + Marker für Tierarzt-Kommentare).
- **Feeding-Reminders**: pro `foods`-Eintrag optional aktivierbar, tägliche Notifications zu `times_of_day`.
- **Walk/Activity**-Event-Type mit Payload (Distanz, Dauer, Aktivitätsart).
- **Ship:** vollständige Alltags-Erfassung mit Visualisierung und Fütterungs-Reminders.

**M6 — Export/Import + PDF + App-Lock + Timeline + Polish (~2-3 Wochen)**
- **Export-Wizard** (CSV + JSON, ZIP-Bundle mit Media).
- **JSON-Import** mit Konflikt-Resolution.
- **PDF-Export** (Impfpass, Pet-Passport-Übersicht, Notfall-Blatt, Einzeldokument-Passthrough) mit `pdf` + `printing`.
- **App-Lock (Biometrie)** über `local_auth`, optional in Settings + `FLAG_SECURE`-Toggle.
- **TimelineScreen** — chronologischer Feed aller Events + Termine cross-Pet mit Filter (Pet/Typ/Datum).
- Media-Startup-Sweep.
- Notification-Reliability (reschedule bei Boot, TZ-Change).
- A11y-Pass (semantics, text-scaling).
- Integration-Tests kritischer Flows.
- **Ship:** v1.0-Kandidat.

## Dependencies

**Runtime:**
- `flutter_riverpod: ^2.5`, `riverpod_annotation: ^2.3`
- `drift: ^2.20`, `drift_flutter: ^0.2` (oder `sqlite3_flutter_libs` + `path_provider`)
- `go_router: ^14.6`
- `freezed_annotation: ^2.4`, `json_annotation: ^4.9`
- `flutter_local_notifications: ^17.2`, `timezone: ^0.9`, `permission_handler: ^11.3`
- `path_provider: ^2.1`, `path: ^1.9`
- `image_picker: ^1.1`, `file_picker: ^8.1`
- `share_plus: ^10.0`, `csv: ^6.0`, `archive: ^3.6`
- `intl: ^0.19`, `uuid: ^4.5`, `collection: ^1.18`
- `flutter_image_compress: ^2.3` (optional ab M5)
- `fl_chart: ^0.69` (M5 — Gewichts-/Wachstums-Charts)
- `pdf: ^3.11`, `printing: ^5.13` (M6 — PDF-Templates + Sharing)
- `local_auth: ^2.3` (M6 — App-Lock via Biometrie)
- `qr_flutter: ^4.1` (M3 optional / M6 PDF — Notfall-QR-Code)

**Dev:**
- `build_runner: ^2.4`, `drift_dev: ^2.20`, `riverpod_generator: ^2.4`
- `freezed: ^2.5`, `json_serializable: ^6.8`
- `custom_lint: ^0.6`, `riverpod_lint: ^2.3`, `flutter_lints: ^5.0`
- `mocktail: ^1.0`, `integration_test: sdk`

## Verification (Ende jedes Milestones)

- `flutter analyze` clean, `dart format` clean.
- `flutter test` grün (Unit + Widget).
- `flutter test integration_test/` grün auf Android Emulator.
- Manueller Smoke-Test auf realem Android-Gerät: neue Features durchklicken + Regressionscheck auf vorheriges Milestone.
- Drift Schema-Snapshot committet unter `drift_schemas/`.
- Vor M6-Ende: Notification-Test über echten Wall-Clock (Termin 2 Min. in Zukunft anlegen, App killen, warten, Zustellung + Deep-Link prüfen).

## Kritische Dateien (werden in Implementierung angelegt)

- `pubspec.yaml`
- `l10n.yaml`
- `build.yaml`
- `lib/main.dart`
- `lib/app/app.dart`, `lib/app/router.dart`, `lib/app/theme.dart`
- `lib/core/db/database.dart` (+ `tables/`, `daos/`, `converters/`)
- `lib/core/media/media_service.dart`
- `lib/core/notifications/notification_service.dart`
- `lib/core/time/recurrence.dart`
- `lib/core/security/app_lock_service.dart` (M6)
- `lib/features/pdf/templates/` (M6 — vaccination_pass.dart, passport_overview.dart, emergency_sheet.dart)
- `lib/features/medications/` (M4 — data/domain/application/presentation)
- `lib/features/onboarding/` (M1)
- `lib/features/emergency/` (M3 — presentation only, liest aus pets/vets/medications/vaccinations)
- `lib/features/charts/` (M5 — weight chart)
- `lib/features/timeline/` (M6 — cross-pet feed)
- Pro Feature: `data/`, `domain/`, `application/`, `presentation/`
- `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
- `drift_schemas/` (Migration-Snapshots)
- `test/helpers/database_helper.dart`, `test/helpers/pump_app.dart`

## Risiken

- **Exact-Alarms (Android 12+)** — Permission ist ein bewegliches Ziel. Graceful Degradation zu inexact + Info-Banner in Settings.
- **Doze/App-Standby** — Notifications können Stunden verzögert werden. Nicht mit Foreground-Service fighten, transparent kommunizieren.
- **Drift-Migrations** — ohne `drift_schemas/` Snapshots werden Upgrade-Tests später schmerzhaft. Ab M1 committen.
- **Recurrence-Edge-Cases** — 31. des Monats, DST, Weekday-Bitmask. Frühe Unit-Tests in M4.
- **Backup-Portabilität** — Android Auto-Backup ist opak. ZIP-JSON-Export als expliziter Backup-Weg in M6.
