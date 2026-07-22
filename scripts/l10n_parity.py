#!/usr/bin/env python3
"""Check ARB parity between lib/l10n/app_de.arb and app_en.arb.

Reports keys missing on either side and placeholder metadata drift
(`@key` entries whose base key is gone). Ignores keys starting with `@@`
(locale metadata).

Exit code 0 = in sync, 1 = drift found.

Usage:
    python3 scripts/l10n_parity.py
    python3 scripts/l10n_parity.py --json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "lib/l10n"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def keys(arb: dict) -> set[str]:
    return {k for k in arb if not k.startswith("@")}


def meta_keys(arb: dict) -> set[str]:
    return {k[1:] for k in arb if k.startswith("@") and not k.startswith("@@")}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    de = load(L10N / "app_de.arb")
    en = load(L10N / "app_en.arb")

    de_keys, en_keys = keys(de), keys(en)
    missing_in_de = sorted(en_keys - de_keys)
    missing_in_en = sorted(de_keys - en_keys)

    dangling_de_meta = sorted(meta_keys(de) - de_keys)
    dangling_en_meta = sorted(meta_keys(en) - en_keys)

    ok = not (missing_in_de or missing_in_en or dangling_de_meta or dangling_en_meta)

    if args.json:
        print(json.dumps({
            "ok": ok,
            "missing_in_de": missing_in_de,
            "missing_in_en": missing_in_en,
            "dangling_meta_de": dangling_de_meta,
            "dangling_meta_en": dangling_en_meta,
            "total_de": len(de_keys),
            "total_en": len(en_keys),
        }, indent=2))
        return 0 if ok else 1

    print(f"DE keys: {len(de_keys)}   EN keys: {len(en_keys)}")
    if missing_in_de:
        print(f"\nMissing in DE ({len(missing_in_de)}):")
        for k in missing_in_de:
            print(f"  - {k}")
    if missing_in_en:
        print(f"\nMissing in EN ({len(missing_in_en)}):")
        for k in missing_in_en:
            print(f"  - {k}")
    if dangling_de_meta:
        print(f"\nDangling @-meta in DE ({len(dangling_de_meta)}):")
        for k in dangling_de_meta:
            print(f"  - @{k}")
    if dangling_en_meta:
        print(f"\nDangling @-meta in EN ({len(dangling_en_meta)}):")
        for k in dangling_en_meta:
            print(f"  - @{k}")
    if ok:
        print("\nOK — ARBs in sync.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
