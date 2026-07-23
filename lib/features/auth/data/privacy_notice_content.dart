/// German privacy notice text bundled into the app.
///
/// Source of truth: `docs/PRIVACY_NOTICE.md`. Keep this constant in sync
/// when the .md file changes — a small helper test verifies parity on
/// key sentences so a drift is caught during CI.
///
/// Sections are separated by `---` for the screen renderer to split
/// into cards. Each section starts with `## ` for its heading (rendered
/// as titleMedium) followed by body paragraphs (one per blank line).
const String kPrivacyNoticeDe = '''
## Was wir speichern

**Lokal auf deinem Gerät (immer):** alle Angaben zu deinen Tieren (Name, Rasse, Geburtstag, Chipnummer, Foto, Notizen), Termine, Impfungen, Medikationsplan, Ernährung, Gewichtsverlauf, Alltags-Events, Kontakte, Tierärzte, Versicherungen, angehängte Fotos und PDF-Dokumente.

Diese Daten liegen ausschließlich im privaten App-Speicher deines Geräts. LorkasApps hat darauf keinen Zugriff. Das gilt auch, wenn du die Cloud-Funktion nicht nutzt.

**Zusätzlich in der Cloud (nur bei aktivem Login):** deine E-Mail-Adresse, ein selbst gewählter Anzeigename, sowie alle Haushalts-Daten (dieselben Kategorien wie oben).
---
## Wo & wie

Cloud-Server bei Supabase, Rechenzentrum in Frankfurt am Main (Deutschland, EU). Verschlüsselt in Transit (TLS 1.3) und at rest (AES-256).

Nur Mitglieder deiner Haushalte sehen die zugehörigen Daten — technisch durchgesetzt via Row-Level-Security auf Datenbank-Ebene. Deine E-Mail-Adresse sehen LorkasApps (als Betreiber) und der Owner eines Haushalts bei Mitgliederverwaltung.

Wir geben keine personenbezogenen Daten an Dritte weiter. Kein Tracking, keine Analytics, keine Werbung.
---
## Rechtsgrundlage & Zweck

Lokale Nutzung: Vertragserfüllung, Art. 6 Abs. 1 lit. b DSGVO.

Cloud-Nutzung: deine bewusste Einwilligung durch Aktivieren des Login, Art. 6 Abs. 1 lit. a DSGVO.

Zweck: Verwaltung deiner Tier-Daten; im Cloud-Modus zusätzlich Synchronisation zwischen deinen Geräten und mit anderen Mitgliedern deines Haushalts.
---
## Deine Rechte

Auskunft (Art. 15): in der App jederzeit einsehbar.

Berichtigung (Art. 16): in der App jederzeit editierbar.

Export (Art. 20): vollständiger JSON-Export unter Mehr → Import / Export.

Löschung (Art. 17): lokal via App-Deinstallation; Cloud via Abmelden + Haushalt löschen in den Einstellungen.

Widerruf der Einwilligung: jederzeit möglich durch Abmelden und Austritt aus dem Haushalt.
---
## Auftragsverarbeitung

Supabase Inc. ist Auftragsverarbeiter für die Cloud-Datenhaltung; Vertrag entspricht Art. 28 DSGVO. Datenverarbeitung ausschließlich in der EU.
---
## Kontakt & Änderungen

Fragen zu diesem Hinweis: Kontakt folgt, sobald ein offizieller Support-Kanal steht.

Wir aktualisieren diesen Hinweis wenn sich Datenverarbeitung oder Anbieter ändern. Die App bittet dann bei erneutem Login um erneute Zustimmung.

Stand: Juli 2026.
''';
