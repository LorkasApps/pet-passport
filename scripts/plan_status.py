#!/usr/bin/env python3
"""Check which milestones/features from docs/PLAN.md are still open.

Runs a set of concrete filesystem, drift-schema and git-log probes and reports
per-milestone status: DONE / PARTIAL / OPEN.

Usage:
    python3 scripts/plan_status.py            # summary
    python3 scripts/plan_status.py --verbose  # show every probe result
    python3 scripts/plan_status.py --json     # machine-readable

The probes are declarative — extend `MILESTONES` when the plan changes.
Kept intentionally simple: heuristics not proofs. A DONE line means the
markers matched, not that the feature is bug-free.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent


# ---------- probes ----------

def has_path(rel: str) -> bool:
    return (ROOT / rel).exists()


def any_path(*rels: str) -> bool:
    return any(has_path(r) for r in rels)


def all_paths(*rels: str) -> bool:
    return all(has_path(r) for r in rels)


def has_drift_table(name: str) -> bool:
    tables_dir = ROOT / "lib/core/db/tables"
    if not tables_dir.exists():
        return False
    needle = name.lower()
    for p in tables_dir.glob("*.dart"):
        if needle in p.name.lower():
            return True
        try:
            if needle in p.read_text(encoding="utf-8").lower():
                return True
        except OSError:
            continue
    return False


def schema_at_least(v: int) -> bool:
    schemas = list((ROOT / "drift_schemas").glob("drift_schema_v*.json"))
    if not schemas:
        return False
    versions = []
    for s in schemas:
        stem = s.stem  # drift_schema_vN
        try:
            versions.append(int(stem.split("_v")[-1]))
        except ValueError:
            pass
    return bool(versions) and max(versions) >= v


def git_log_mentions(*needles: str) -> bool:
    try:
        out = subprocess.run(
            ["git", "log", "--pretty=%s%n%b"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.lower()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False
    return any(n.lower() in out for n in needles)


# ---------- model ----------

@dataclass
class Probe:
    label: str
    check: Callable[[], bool]


@dataclass
class Milestone:
    id: str
    title: str
    probes: list[Probe] = field(default_factory=list)

    def run(self) -> tuple[str, list[tuple[str, bool]]]:
        results = [(p.label, p.check()) for p in self.probes]
        hits = sum(1 for _, ok in results if ok)
        if hits == len(results):
            status = "DONE"
        elif hits == 0:
            status = "OPEN"
        else:
            status = "PARTIAL"
        return status, results


MILESTONES: list[Milestone] = [
    Milestone("M1", "Foundation + Pet CRUD + Onboarding", [
        Probe("pets feature",       lambda: has_path("lib/features/pets")),
        Probe("onboarding feature", lambda: has_path("lib/features/onboarding")),
        Probe("pets table",         lambda: has_drift_table("pets_table")),
        Probe("pet_weights table",  lambda: has_drift_table("pet_weights")),
        Probe("theme + router",     lambda: all_paths("lib/app/theme.dart", "lib/app/router.dart")),
        Probe("l10n arb files",     lambda: all_paths("lib/l10n/app_de.arb", "lib/l10n/app_en.arb")),
    ]),
    Milestone("M2", "Pet-Profile-Refactor + Vets, Insurances, Documents", [
        Probe("vets feature",           lambda: has_path("lib/features/vets")),
        Probe("insurances feature",     lambda: has_path("lib/features/insurances")),
        Probe("vets table",             lambda: has_drift_table("vets_table")),
        Probe("insurances table",       lambda: has_drift_table("insurances_table")),
        Probe("insurance_documents",    lambda: has_drift_table("insurance_documents")),
        Probe("pet-context provider",   lambda: has_path("lib/features/pets/application/current_pet_provider.dart")),
    ]),
    Milestone("M3", "Vaccinations + Reminders + Emergency-Info", [
        Probe("vaccinations feature",   lambda: has_path("lib/features/vaccinations")),
        Probe("vaccinations table",     lambda: has_drift_table("vaccinations_table")),
        Probe("emergency feature",      lambda: has_path("lib/features/emergency")),
        Probe("notification service",   lambda: has_path("lib/core/notifications")),
    ]),
    Milestone("M4", "Appointments + Medications + Recurrence", [
        Probe("appointments feature",       lambda: has_path("lib/features/appointments")),
        Probe("appointments table",         lambda: has_drift_table("appointments_table")),
        Probe("appointment_reminders",      lambda: has_drift_table("appointment_reminders")),
        Probe("appointment_exceptions",     lambda: has_drift_table("appointment_exceptions")),
        Probe("medications feature",        lambda: has_path("lib/features/medications")),
        Probe("medications table",          lambda: has_drift_table("medications_table")),
        Probe("recurrence helper",          lambda: has_path("lib/core/time/recurrence.dart")),
    ]),
    Milestone("M5", "Diet + Protocol + Charts + Feeding-Reminders", [
        Probe("protocol feature",       lambda: has_path("lib/features/protocol")),
        Probe("events table",           lambda: has_drift_table("events_table")),
        Probe("event_tags table",       lambda: has_drift_table("event_tags")),
        Probe("event_photos table",     lambda: has_drift_table("event_photos")),
        Probe("diet feature",           lambda: any_path("lib/features/diet", "lib/features/foods")),
        Probe("foods table",            lambda: has_drift_table("foods_table")),
        Probe("charts feature",         lambda: has_path("lib/features/charts")),
        Probe("fl_chart dep",           lambda: "fl_chart:" in (ROOT / "pubspec.yaml").read_text(encoding="utf-8")),
        Probe("schema >= v5",           lambda: schema_at_least(5)),
    ]),
    Milestone("M6", "Export/Import + PDF + App-Lock + Timeline + Polish", [
        Probe("export_import feature",  lambda: has_path("lib/features/export_import")),
        Probe("json import present",    lambda: git_log_mentions("json import", "import")),
        Probe("pdf feature",            lambda: has_path("lib/features/pdf")),
        Probe("pdf dep",                lambda: "pdf:" in (ROOT / "pubspec.yaml").read_text(encoding="utf-8")),
        Probe("app-lock (security)",    lambda: has_path("lib/features/security") or has_path("lib/core/security")),
        Probe("local_auth dep",         lambda: "local_auth:" in (ROOT / "pubspec.yaml").read_text(encoding="utf-8")),
        Probe("timeline feature",       lambda: has_path("lib/features/timeline")),
    ]),
]


# ---------- output ----------

STATUS_COLOR = {"DONE": "\033[32m", "PARTIAL": "\033[33m", "OPEN": "\033[31m"}
RESET = "\033[0m"


def render(results: list[tuple[Milestone, str, list[tuple[str, bool]]]], verbose: bool, use_color: bool) -> str:
    lines: list[str] = []
    for m, status, probes in results:
        badge = f"{STATUS_COLOR[status]}{status:<7}{RESET}" if use_color else f"{status:<7}"
        hits = sum(1 for _, ok in probes if ok)
        lines.append(f"{badge} {m.id}  {m.title}  ({hits}/{len(probes)})")
        if verbose or status == "PARTIAL":
            for label, ok in probes:
                mark = "✓" if ok else "✗"
                lines.append(f"          {mark} {label}")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--verbose", "-v", action="store_true", help="show every probe result")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    ap.add_argument("--no-color", action="store_true")
    args = ap.parse_args()

    results = [(m, *m.run()) for m in MILESTONES]

    if args.json:
        payload = [
            {
                "id": m.id,
                "title": m.title,
                "status": status,
                "probes": [{"label": lbl, "ok": ok} for lbl, ok in probes],
            }
            for m, status, probes in results
        ]
        print(json.dumps(payload, indent=2))
        return 0

    use_color = sys.stdout.isatty() and not args.no_color
    print(render(results, args.verbose, use_color))
    return 0


if __name__ == "__main__":
    sys.exit(main())
