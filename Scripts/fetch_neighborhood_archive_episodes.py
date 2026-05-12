#!/usr/bin/env python3
"""
Fetch episode metadata from The Mister Rogers' Neighborhood Archive index and
per-episode pages. Emits JSON suitable for MisterRogersRenamer (Episode Codable).

Requirements: Python 3.9+, stdlib only.

Usage:
  python3 fetch_neighborhood_archive_episodes.py [--output PATH] [--sleep SECONDS]

Attribution: Factual metadata is sourced from neighborhoodarchive.com. Site terms
apply; redistributing generated JSON may require permission from The Fred Rogers Company.
See project README and TECHNICAL_DOCUMENTATION.md.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from typing import Any

BASE = "https://www.neighborhoodarchive.com"
INDEX_URL = f"{BASE}/mrn/episodes/index.html"
USER_AGENT = "MisterRogersRenamerEpisodeFetcher/1.0 (+local-maintainer-script)"

H2_YEAR = re.compile(r'<h2><a name="(\d{4})"', re.I)
LI_EP = re.compile(
    r'<li>\s*<a href="(\d{1,4})/index\.html"[^>]*>([^<]+)</a>\s*</li>',
    re.I,
)
H1_EP = re.compile(r"<h1[^>]*>\s*(Episode\s+\d+)\s*</h1>", re.I)
AIR_DATE = re.compile(
    r"Air Date:\s*([A-Za-z]+ \d{1,2}, \d{4})",
    re.I,
)


def fetch(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        return resp.read().decode("latin-1", errors="replace")


def parse_index(html: str) -> dict[int, dict[str, Any]]:
    """Map production id -> season (broadcast year), episode (ordinal in year), title from index."""
    out: dict[int, dict[str, Any]] = {}
    current_year: int | None = None
    ep_in_year = 0
    pos = 0
    while pos < len(html):
        m2 = H2_YEAR.search(html, pos)
        ml = LI_EP.search(html, pos)
        if m2 and (not ml or m2.start() < ml.start()):
            current_year = int(m2.group(1))
            ep_in_year = 0
            pos = m2.end()
            continue
        if ml and current_year is not None:
            raw_id = ml.group(1)
            pid = int(raw_id, 10)
            ep_in_year += 1
            title = re.sub(r"\s+", " ", ml.group(2).strip())
            if pid in out:
                raise SystemExit(f"duplicate production id in index: {pid}")
            out[pid] = {
                "season": current_year,
                "episode": ep_in_year,
                "title": title,
            }
            pos = ml.end()
            continue
        if ml:
            pos = ml.end()
            continue
        break
    return out


def parse_air_date(html: str) -> str:
    m = AIR_DATE.search(html)
    if not m:
        return ""
    try:
        dt = datetime.strptime(m.group(1), "%B %d, %Y")
        return dt.strftime("%Y-%m-%d")
    except ValueError:
        return ""


def refine_title(html: str, fallback: str) -> str:
    m = H1_EP.search(html)
    if m:
        return re.sub(r"\s+", " ", m.group(1).strip())
    return fallback


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--output",
        default=str(
            __import__("pathlib").Path(__file__).resolve().parents[1]
            / "Sources/MisterRogersRenamerCore/Resources/episodes.json"
        ),
        help="Output JSON path",
    )
    ap.add_argument("--sleep", type=float, default=0.25, help="Delay between episode requests")
    args = ap.parse_args()

    print("Fetching index…", file=sys.stderr)
    index_html = fetch(INDEX_URL)
    meta = parse_index(index_html)
    pids = sorted(meta.keys())
    print(f"Found {len(pids)} episodes ({pids[0]}–{pids[-1]})", file=sys.stderr)

    episodes: list[dict[str, Any]] = []
    for i, pid in enumerate(pids):
        path = str(pid).zfill(4)
        url = f"{BASE}/mrn/episodes/{path}/index.html"
        try:
            body = fetch(url)
        except urllib.error.HTTPError as e:
            print(f"WARN {pid}: HTTP {e.code}", file=sys.stderr)
            body = ""

        air = parse_air_date(body) if body else ""
        title = refine_title(body, meta[pid]["title"]) if body else meta[pid]["title"]
        src = f"The Mister Rogers' Neighborhood Archive — {url}"
        episodes.append(
            {
                "id": pid,
                "season": meta[pid]["season"],
                "episode": meta[pid]["episode"],
                "title": title,
                "airDate": air,
                "source": src,
            }
        )
        if args.sleep > 0:
            time.sleep(args.sleep)
        if (i + 1) % 100 == 0:
            print(f"  … {i + 1}/{len(pids)}", file=sys.stderr)

    out_path = args.output
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(episodes, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Wrote {len(episodes)} episodes to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
