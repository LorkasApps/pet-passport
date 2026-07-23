#!/usr/bin/env python3
"""
gen_test_data.py — generate a rich JSON snapshot for the Pet Passport
app's JSON import.

Produces one dog with every field the import service reads, so you can
exercise the import flow and downstream features (Übersicht, Notfall,
Impfpass, Timeline, Alltag-Filter, PDF, Emergency-QR, etc.) without
tapping everything in by hand.

What the JSON import currently reads (as of DB v11 / export schema v3):
  - pets (all fields incl. chip/tasso/passport/allergies/photo path)
  - weights (list under each pet)
  - vets (incl. is_active)
  - contacts (sitter/trainer/groomer/other, is_active)
  - insurances (+ documents metadata)
  - vaccinations (+ documents metadata, vet_uuid cross-ref)
  - events (weight/feeding/symptom/activity/generic + payload + tags + photos)
  - appointments (+ reminders + exceptions + vet_uuid cross-ref)
  - medications (+ reminders + intakes + prescribed_by_vet_uuid cross-ref)
  - foods
  - tags (root-level, referenced by event tag_uuids)

Usage:
  python3 scripts/gen_test_data.py            # writes ./test_data.json
  python3 scripts/gen_test_data.py --out foo  # writes ./foo.json
"""

from __future__ import annotations

import argparse
import json
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


def iso(dt: datetime) -> str:
    """UTC ISO-8601 with 'Z' — matches ExportService._dt output shape."""
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def new_uuid() -> str:
    return str(uuid.uuid4())


def build_snapshot() -> dict:
    now = datetime.now(timezone.utc).replace(microsecond=0)

    # --- tags (root-level; events reference by uuid) ---
    tag_walk = {
        "uuid": new_uuid(),
        "label": "Spaziergang",
        "color": 0xFF4CAF50,  # green
        "created_at": iso(now - timedelta(days=90)),
    }
    tag_vet = {
        "uuid": new_uuid(),
        "label": "Tierarzt",
        "color": 0xFFE53935,  # red
        "created_at": iso(now - timedelta(days=90)),
    }
    tag_food = {
        "uuid": new_uuid(),
        "label": "Futter",
        "color": 0xFFFB8C00,  # orange
        "created_at": iso(now - timedelta(days=90)),
    }
    tags = [tag_walk, tag_vet, tag_food]

    # --- pet ---
    pet_uuid = new_uuid()
    date_of_birth = now.replace(hour=0, minute=0, second=0) - timedelta(
        days=365 * 4 + 42  # ~4 years old
    )

    # --- vets: 1 active + 1 archived ---
    vet_active = {
        "uuid": new_uuid(),
        "name": "Dr. Anna Weber",
        "practice": "Tierklinik Nord",
        "address": "Hauptstraße 12, 20095 Hamburg",
        "phone": "+49 40 1234567",
        "email": "praxis@tierklinik-nord.example",
        "notes": "Stammtierarzt, immer erreichbar.",
        "is_active": True,
        "created_at": iso(now - timedelta(days=800)),
        "updated_at": iso(now - timedelta(days=30)),
    }
    vet_archived = {
        "uuid": new_uuid(),
        "name": "Dr. Martin Schulz",
        "practice": "Alte Praxis (umgezogen)",
        "address": "Lindenweg 4, 22083 Hamburg",
        "phone": "+49 40 7654321",
        "email": None,
        "notes": "Praxis geschlossen — Kontakt nur zu alten Impfterminen.",
        "is_active": False,
        "created_at": iso(now - timedelta(days=1200)),
        "updated_at": iso(now - timedelta(days=180)),
    }
    vets = [vet_active, vet_archived]

    # --- contacts: sitter (active) + trainer (active) + old groomer (archived) ---
    contact_sitter = {
        "uuid": new_uuid(),
        "role": "sitter",
        "name": "Lisa Müller",
        "organization": None,
        "address": "Bergstraße 3, 22083 Hamburg",
        "phone": "+49 176 1234567",
        "email": "lisa.mueller@example.com",
        "notes": "Nachbarin, kann kurzfristig einspringen.",
        "is_active": True,
        "created_at": iso(now - timedelta(days=180)),
        "updated_at": iso(now - timedelta(days=30)),
    }
    contact_trainer = {
        "uuid": new_uuid(),
        "role": "trainer",
        "name": "Marco Bauer",
        "organization": "Hundeschule Elbe",
        "address": "Elbchaussee 200, 22763 Hamburg",
        "phone": "+49 40 9876543",
        "email": "marco@hundeschule-elbe.example",
        "notes": "Trainer für Rückruf + Leinenführigkeit.",
        "is_active": True,
        "created_at": iso(now - timedelta(days=250)),
        "updated_at": iso(now - timedelta(days=60)),
    }
    contact_groomer = {
        "uuid": new_uuid(),
        "role": "groomer",
        "name": "Sabine Klein",
        "organization": "Hundesalon Klein (geschlossen)",
        "address": None,
        "phone": None,
        "email": None,
        "notes": "Salon nicht mehr aktiv. Nur Referenz für alte Termine.",
        "is_active": False,
        "created_at": iso(now - timedelta(days=800)),
        "updated_at": iso(now - timedelta(days=300)),
    }
    contacts = [contact_sitter, contact_trainer, contact_groomer]

    # --- insurance (+ document metadata; file itself is NOT restored) ---
    insurance = {
        "uuid": new_uuid(),
        "provider": "Petplan Deutschland",
        "policy_number": "PP-2024-998877",
        "contract_start": iso(now - timedelta(days=400)),
        "contract_end": iso(now + timedelta(days=330)),
        "notes": "OP-Schutz inklusive. Selbstbehalt 20%.",
        "created_at": iso(now - timedelta(days=400)),
        "updated_at": iso(now - timedelta(days=30)),
        "documents": [
            {
                "uuid": new_uuid(),
                "file_path": "insurance_docs/petplan_police_2024.pdf",
                "mime_type": "application/pdf",
                "original_filename": "petplan_police_2024.pdf",
                "size_bytes": 184320,
                "created_at": iso(now - timedelta(days=400)),
            },
        ],
    }

    # --- vaccinations: past-done, coming-up, overdue ---
    vac_past = {
        "uuid": new_uuid(),
        "vaccine_name": "Tollwut",
        "administered_at": iso(now - timedelta(days=200)),
        "next_due_at": iso(now + timedelta(days=165)),  # future
        "vet_uuid": vet_active["uuid"],
        "batch_number": "TW-2025-A12",
        "notes": "Kombiimpfung. Gut vertragen.",
        "created_at": iso(now - timedelta(days=200)),
        "updated_at": iso(now - timedelta(days=200)),
        "documents": [
            {
                "uuid": new_uuid(),
                "file_path": "vaccination_docs/tollwut_2025.pdf",
                "mime_type": "application/pdf",
                "original_filename": "tollwut_zertifikat.pdf",
                "size_bytes": 92160,
                "created_at": iso(now - timedelta(days=200)),
            },
        ],
    }
    vac_upcoming = {
        "uuid": new_uuid(),
        "vaccine_name": "SHP (Staupe/Hepatitis/Parvovirose)",
        "administered_at": iso(now - timedelta(days=340)),
        "next_due_at": iso(now + timedelta(days=25)),  # due soon
        "vet_uuid": vet_active["uuid"],
        "batch_number": "SHP-24-B7",
        "notes": None,
        "created_at": iso(now - timedelta(days=340)),
        "updated_at": iso(now - timedelta(days=340)),
        "documents": [],
    }
    vac_overdue = {
        "uuid": new_uuid(),
        "vaccine_name": "Zwingerhusten",
        "administered_at": iso(now - timedelta(days=420)),
        "next_due_at": iso(now - timedelta(days=55)),  # overdue
        "vet_uuid": vet_archived["uuid"],  # archived vet reference on purpose
        "batch_number": "ZH-23-X9",
        "notes": "Booster wurde vergessen — beim nächsten Termin nachholen.",
        "created_at": iso(now - timedelta(days=420)),
        "updated_at": iso(now - timedelta(days=420)),
        "documents": [],
    }
    vaccinations = [vac_past, vac_upcoming, vac_overdue]

    # --- weights over ~1 year ---
    weight_curve = [
        (365, 18.4),
        (300, 19.1),
        (240, 20.0),
        (180, 20.6),
        (120, 21.0),
        (60, 21.4),
        (30, 21.8),
        (14, 22.0),
        (3, 22.1),
    ]
    weights = [
        {
            "measured_at": iso(now - timedelta(days=days_ago)),
            "weight_kg": kg,
            "note": "Routine-Wiegen" if days_ago > 14 else "Beim Tierarzt gewogen",
        }
        for days_ago, kg in weight_curve
    ]

    # --- events: every EventType, mixing tags + photos ---
    events = []

    # 1. Weight event — links to pet_weights via same measured_at handling
    events.append({
        "uuid": new_uuid(),
        "event_type": "weight",
        "occurred_at": iso(now - timedelta(days=3)),
        "title": "Gewichtskontrolle",
        "note": "Gewicht stabil, guter Muskelzustand.",
        "payload": {"weight_kg": 22.1},
        "tag_uuids": [tag_vet["uuid"]],
        "photos": [],
        "created_at": iso(now - timedelta(days=3)),
        "updated_at": iso(now - timedelta(days=3)),
    })

    # 2. Feeding event (morning meal)
    events.append({
        "uuid": new_uuid(),
        "event_type": "feeding",
        "occurred_at": iso(now - timedelta(days=1, hours=14)),
        "title": "Morgen-Fütterung",
        "note": None,
        "payload": {
            "food_name": "Josera Adult",
            "amount_g": 220,
            "meal": "morning",
        },
        "tag_uuids": [tag_food["uuid"]],
        "photos": [],
        "created_at": iso(now - timedelta(days=1, hours=14)),
        "updated_at": iso(now - timedelta(days=1, hours=14)),
    })

    # 3. Symptom event with a photo attachment (file itself not restored)
    events.append({
        "uuid": new_uuid(),
        "event_type": "symptom",
        "occurred_at": iso(now - timedelta(days=5)),
        "title": "Humpelt hinten links",
        "note": "Nach dem Spaziergang. Nach 2 Std. weg.",
        "payload": {
            "description": "Leichtes Humpeln, hinten links.",
            "severity": "medium",
        },
        "tag_uuids": [tag_vet["uuid"]],
        "photos": [
            {
                "uuid": new_uuid(),
                "file_path": "event_photos/symptom_pfote.jpg",
                "mime_type": "image/jpeg",
                "size_bytes": 245760,
                "created_at": iso(now - timedelta(days=5)),
            },
        ],
        "created_at": iso(now - timedelta(days=5)),
        "updated_at": iso(now - timedelta(days=5)),
    })

    # 4. Activity: walk with distance + duration
    events.append({
        "uuid": new_uuid(),
        "event_type": "activity",
        "occurred_at": iso(now - timedelta(days=2)),
        "title": "Morgen-Runde am Elbufer",
        "note": None,
        "payload": {
            "activity_type": "walk",
            "distance_m": 3200,
            "duration_min": 55,
        },
        "tag_uuids": [tag_walk["uuid"]],
        "photos": [],
        "created_at": iso(now - timedelta(days=2)),
        "updated_at": iso(now - timedelta(days=2)),
    })

    # 5. Activity: training
    events.append({
        "uuid": new_uuid(),
        "event_type": "activity",
        "occurred_at": iso(now - timedelta(days=4)),
        "title": "Hundeschule",
        "note": "Rückruf klappt jetzt bei mittlerer Ablenkung.",
        "payload": {
            "activity_type": "training",
            "duration_min": 45,
        },
        "tag_uuids": [tag_walk["uuid"]],
        "photos": [],
        "created_at": iso(now - timedelta(days=4)),
        "updated_at": iso(now - timedelta(days=4)),
    })

    # 6. Generic note
    events.append({
        "uuid": new_uuid(),
        "event_type": "generic",
        "occurred_at": iso(now - timedelta(days=10)),
        "title": "Krallen geschnitten",
        "note": "Zuhause selbst, ohne Stress.",
        "payload": {},
        "tag_uuids": [],
        "photos": [],
        "created_at": iso(now - timedelta(days=10)),
        "updated_at": iso(now - timedelta(days=10)),
    })

    # --- appointments: single + recurring + one with an override exception ---
    appt_next = {
        "uuid": new_uuid(),
        "type": "vet",
        "vet_uuid": vet_active["uuid"],
        "contact_uuid": None,
        "title": "Jährliche Vorsorge",
        "starts_at": iso(now + timedelta(days=14, hours=9)),
        "duration_minutes": 45,
        # Vet-appointments derive their location from the linked vet.
        "location": None,
        "notes": "Blutbild + Zähne-Check.",
        "recurrence_freq": "none",
        "recurrence_interval": 1,
        "recurrence_weekdays": 0,
        "recurrence_until": None,
        "reminder_offsets_minutes": [60, 1440],  # 1h + 1 day before
        "exceptions": [],
        "created_at": iso(now - timedelta(days=5)),
        "updated_at": iso(now - timedelta(days=5)),
    }
    appt_recurring = {
        "uuid": new_uuid(),
        "type": "training",
        "vet_uuid": None,
        "contact_uuid": contact_trainer["uuid"],
        "title": "Hundeschule Kurs",
        "starts_at": iso(now + timedelta(days=3, hours=10)),
        "duration_minutes": 90,
        "location": "Elbchaussee 200, 22763 Hamburg",
        "notes": None,
        "recurrence_freq": "monthly",
        "recurrence_interval": 1,
        "recurrence_weekdays": 0,
        "recurrence_until": iso(now + timedelta(days=365)),
        "reminder_offsets_minutes": [1440],
        "exceptions": [
            # One instance rescheduled by 2 days
            {
                "occurrence_start": iso(now + timedelta(days=33, hours=10)),
                "is_cancelled": False,
                "override_starts_at": iso(now + timedelta(days=35, hours=10)),
            },
            # One instance cancelled outright
            {
                "occurrence_start": iso(now + timedelta(days=64, hours=10)),
                "is_cancelled": True,
                "override_starts_at": None,
            },
        ],
        "created_at": iso(now - timedelta(days=200)),
        "updated_at": iso(now - timedelta(days=10)),
    }
    appointments = [appt_next, appt_recurring]

    # --- medications: 1 active + 1 finished (inactive), with intakes ---
    med_active_uuid = new_uuid()
    med_active_intakes = []
    # 5 recent intakes, one skipped
    for i in range(5):
        med_active_intakes.append({
            "uuid": new_uuid(),
            "taken_at": iso(now - timedelta(days=i, hours=1)),
            "skipped": (i == 2),  # skipped one
            "note": "Mit Frühstück" if i == 0 else None,
        })
    med_active = {
        "uuid": med_active_uuid,
        "name": "Metacam",
        "dosage_amount": 1.5,
        "dosage_unit": "mg",
        "freq_type": "daily",
        "freq_interval": 1,
        "freq_weekdays": 0,
        "times_of_day": ["08:00", "20:00"],
        "starts_at": iso(now - timedelta(days=14)),
        "ends_at": iso(now + timedelta(days=14)),
        "is_active": True,
        "notes": "Bei Bedarf gegen Gelenkschmerzen.",
        "prescribed_by_vet_uuid": vet_active["uuid"],
        "with_food": True,
        "reminder_offsets_minutes": [0, 15],
        "intakes": med_active_intakes,
        "created_at": iso(now - timedelta(days=14)),
        "updated_at": iso(now - timedelta(days=1)),
    }
    med_finished = {
        "uuid": new_uuid(),
        "name": "Amoxicillin",
        "dosage_amount": 250,
        "dosage_unit": "mg",
        "freq_type": "daily",
        "freq_interval": 1,
        "freq_weekdays": 0,
        "times_of_day": ["09:00", "21:00"],
        "starts_at": iso(now - timedelta(days=60)),
        "ends_at": iso(now - timedelta(days=50)),
        "is_active": False,
        "notes": "10-Tage-Kur nach Ohrenentzündung. Erfolgreich abgeschlossen.",
        "prescribed_by_vet_uuid": vet_archived["uuid"],  # archived vet ref
        "with_food": False,
        "reminder_offsets_minutes": [0],
        "intakes": [],
        "created_at": iso(now - timedelta(days=60)),
        "updated_at": iso(now - timedelta(days=50)),
    }
    medications = [med_active, med_finished]

    # --- foods: 1 active + 1 old (for history section) ---
    food_current_uuid = new_uuid()
    food_current = {
        "uuid": food_current_uuid,
        "brand": "Josera",
        "name": "Adult Sensitive",
        "food_type": "dry",
        "portion_grams": 220.0,
        "frequency_per_day": 2,
        "times_of_day": ["07:00", "19:00"],
        "is_active": True,
        "starts_at": iso(now - timedelta(days=90)),
        "ends_at": None,
        "reminders_enabled": True,
        "notes": "Verträgt er super, keine Magenprobleme mehr.",
        "photos": [
            {
                "uuid": new_uuid(),
                "file_path": f"foods/{food_current_uuid}/bag.jpg",
                "mime_type": "image/jpeg",
                "original_filename": "josera_bag.jpg",
                "size_bytes": 184320,
                "created_at": iso(now - timedelta(days=90)),
            },
        ],
        "created_at": iso(now - timedelta(days=90)),
        "updated_at": iso(now - timedelta(days=1)),
    }
    food_old = {
        "uuid": new_uuid(),
        "brand": "Wolfsblut",
        "name": "Wild Duck",
        "food_type": "dry",
        "portion_grams": 200.0,
        "frequency_per_day": 2,
        "times_of_day": ["07:00", "19:00"],
        "is_active": False,
        "starts_at": iso(now - timedelta(days=400)),
        "ends_at": iso(now - timedelta(days=91)),
        "reminders_enabled": False,
        "notes": "Zu proteinreich — auf Sensitive umgestellt.",
        "photos": [],
        "created_at": iso(now - timedelta(days=400)),
        "updated_at": iso(now - timedelta(days=91)),
    }
    foods = [food_current, food_old]

    pet = {
        "uuid": pet_uuid,
        "name": "Balu",
        "species": "dog",
        "sex": "male",
        "is_neutered": True,
        "breed": "Border Collie Mix",
        "date_of_birth": iso(date_of_birth),
        "color": "Schwarz-weiß",
        "markings": "Weißer Bruststreif, weiße Pfoten vorn.",
        "chip_number": "276098106123456",
        "tasso_number": "0123456789",
        "tasso_registered_at": iso(now - timedelta(days=1400)),
        "vaccination_passport_number": "DE-IP-2021-778899",
        "profile_photo_path": "pet_photos/balu_profile.jpg",
        "allergies": "Huhn, Milbenstaub",
        "notes": (
            "Zieht an der Leine bei Fahrrädern. Angst vor Feuerwerk — "
            "Silvester Trazodon-Rezept vom Tierarzt einholen."
        ),
        "created_at": iso(now - timedelta(days=1400)),
        "updated_at": iso(now - timedelta(days=1)),
        "weights": weights,
        "vets": vets,
        "contacts": contacts,
        "insurances": [insurance],
        "vaccinations": vaccinations,
        "events": events,
        "appointments": appointments,
        "medications": medications,
        "foods": foods,
    }

    return {
        "schema_version": 3,
        "exported_at": iso(now),
        "app_version": "gen_test_data.py",
        "tags": tags,
        "pets": [pet],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--out",
        default="test_data",
        help="output filename stem (without .json). Default: test_data",
    )
    parser.add_argument(
        "--dir",
        default=".",
        help="output directory. Default: current dir",
    )
    args = parser.parse_args()

    snapshot = build_snapshot()
    out_path = Path(args.dir) / f"{args.out}.json"
    out_path.write_text(
        json.dumps(snapshot, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    pet = snapshot["pets"][0]
    print(f"wrote {out_path}")
    print(f"  pet:           {pet['name']} ({pet['uuid']})")
    print(f"  weights:       {len(pet['weights'])}")
    print(f"  vets:          {len(pet['vets'])} "
          f"(active={sum(1 for v in pet['vets'] if v['is_active'])}, "
          f"archived={sum(1 for v in pet['vets'] if not v['is_active'])})")
    print(f"  contacts:      {len(pet['contacts'])} "
          f"(active={sum(1 for c in pet['contacts'] if c['is_active'])}, "
          f"archived={sum(1 for c in pet['contacts'] if not c['is_active'])})")
    print(f"  insurances:    {len(pet['insurances'])}")
    print(f"  vaccinations:  {len(pet['vaccinations'])} "
          "(1 upcoming due, 1 overdue, 1 done)")
    print(f"  events:        {len(pet['events'])} "
          "(weight, feeding, symptom+photo, 2×activity, generic)")
    print(f"  appointments:  {len(pet['appointments'])} "
          "(single + monthly recurring with 2 exceptions)")
    n_intakes = sum(len(m['intakes']) for m in pet['medications'])
    print(f"  medications:   {len(pet['medications'])} "
          f"({sum(1 for m in pet['medications'] if m['is_active'])} active, "
          f"{n_intakes} intakes total)")
    print(f"  foods:         {len(pet['foods'])} "
          f"({sum(1 for f in pet['foods'] if f['is_active'])} active)")
    print(f"  tags:          {len(snapshot['tags'])}")
    print()
    print("Import via app: Mehr → Einstellungen → Import (JSON restore).")
    print("Media files (photos, PDFs) are referenced by path only — the JSON")
    print("does not contain the bytes. Missing files won't break the import,")
    print("but 'Open document' actions will fail on those entries.")


if __name__ == "__main__":
    main()
