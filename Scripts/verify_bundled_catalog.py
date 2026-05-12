#!/usr/bin/env python3
"""Verify bundled episodes.manifest.json agrees with episodes.json SHA-256."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    ep_path = root / "Sources/MisterRogersRenamerCore/Resources/episodes.json"
    man_path = root / "Sources/MisterRogersRenamerCore/Resources/episodes.manifest.json"
    missing = [str(p.relative_to(root)) for p in (ep_path, man_path) if not p.is_file()]
    if missing:
        print("ERROR: Missing files:", ", ".join(missing), file=sys.stderr)
        raise SystemExit(1)
    blob = json.loads(man_path.read_text(encoding="utf-8"))
    expected = blob.get("contentSha256")
    if not isinstance(expected, str) or len(expected) != 64:
        print("ERROR: manifest contentSha256 missing or invalid.", file=sys.stderr)
        raise SystemExit(2)
    actual = hashlib.sha256(ep_path.read_bytes()).hexdigest()
    if actual != expected:
        print(
            f"ERROR: episodes.json SHA-256 does not match manifest.\n"
            f"  actual:   {actual}\n"
            f"  manifest: {expected}",
            file=sys.stderr,
        )
        raise SystemExit(3)
    rev = blob.get("dataRevision", "?")
    print(f"OK: bundled catalog {rev} matches episodes.json digest.")


if __name__ == "__main__":
    main()
