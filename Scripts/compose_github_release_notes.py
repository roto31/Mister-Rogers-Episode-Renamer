#!/usr/bin/env python3
"""
Emit full GitHub Release notes body: bundled catalog preamble + gh generated notes API.
Requires `gh` on PATH with auth (e.g. GITHUB_TOKEN).

Usage:
  python3 Scripts/compose_github_release_notes.py --tag v1.0.0 [--repo OWNER/NAME]
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def preamble_from_manifest(repo_root: Path) -> str:
    man = repo_root / "Sources/MisterRogersRenamerCore/Resources/episodes.manifest.json"
    if not man.is_file():
        return ""
    try:
        data = json.loads(man.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print("WARN: Could not parse episodes.manifest.json.", file=sys.stderr)
        return ""
    rev = data.get("dataRevision", "?")
    sha = data.get("contentSha256", "?")
    dataset = data.get("dataset", "?")
    sid = data.get("tvdbSeriesId", "?")
    return (
        "## Bundled MRN catalog\n\n"
        f"- **dataRevision:** `{rev}`\n"
        f"- **contentSha256:** `{sha}`\n"
        f"- **dataset:** `{dataset}` · **TheTVDB** series `{sid}`\n\n"
    )


def gh_generate(repo: str, tag: str) -> str:
    env = dict(os.environ)
    env.setdefault("GH_PROMPT_DISABLED", "1")
    proc = subprocess.run(
        ["gh", "api", f"repos/{repo}/releases/generate-notes", "-f", f"tag_name={tag}"],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    parsed = json.loads(proc.stdout)
    body = parsed.get("body") or ""
    if not isinstance(body, str):
        return ""
    return body


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tag", required=True, help="Release tag without refs (e.g. v1.0.0)")
    ap.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY", ""),
        help="OWNER/NAME (default: GITHUB_REPOSITORY)",
    )
    args = ap.parse_args()
    if not args.repo.strip():
        print("ERROR: --repo or GITHUB_REPOSITORY required for gh.", file=sys.stderr)
        raise SystemExit(2)

    root = Path(__file__).resolve().parents[1]
    pre = preamble_from_manifest(root)
    try:
        gen = gh_generate(args.repo.strip(), args.tag.strip())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or exc.stdout, file=sys.stderr)
        raise SystemExit(1) from exc

    sections = []
    if pre:
        sections.append(pre.rstrip())
    if gen.strip():
        sections.append(gen.strip())
    print("\n\n".join(sections))


if __name__ == "__main__":
    main()
