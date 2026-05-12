#!/usr/bin/env python3
"""
Build Resources/episodes.json for MisterRogersRenamer.

 1. Production numbers + first-air dates: The Mister Rogers' Neighborhood Archive
    (https://www.neighborhoodarchive.com/mrn/episodes/index.html).
 2. Season / episode / title (aired order): TheTVDB API v4, series id 77750
    (https://thetvdb.com/series/mister-rogers-neighborhood).

Matching is by air date (YYYY-MM-DD). When multiple TVDB episodes share a date,
regular seasons are preferred before Season 0 specials so a single Archive
production maps to the expected network episode.

Requirements: Python 3.9+, stdlib only.

Environment:
  TVDB_API_KEY   Required. Your TVDB v4 API key (never commit this to git).

Usage:
  export TVDB_API_KEY='your-uuid-key'
  python3 Scripts/build_episodes_json.py [--sleep SECONDS] [--cache-dir DIR] [--manifest PATH] [--data-revision REV]

Optional flags:
  --manifest PATH           Write/update episodes.manifest.json (default: sibling of OUTPUT)
  --data-revision STR       Override manifest dataRevision

After writing OUTPUT, the script computes SHA-256 bytes of episodes.json,
updates dataRevision when the digest changes (calver-style mrn-YYYY-MM-DD
unless unchanged), and writes the manifest beside the bundle.

Attribution: episode titles and SxE from TheTVDB; production numbers and air
dates from the Neighborhood Archive. Respect both sites' terms. Do not commit
scraped data to a public repo without permission.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

# --- Neighborhood Archive (reuse patterns) ---
BASE = "https://www.neighborhoodarchive.com"
INDEX_URL = f"{BASE}/mrn/episodes/index.html"
ARCHIVE_UA = "MisterRogersRenamerEpisodeFetcher/1.0 (+local-maintainer-script)"

H2_YEAR = re.compile(r'<h2><a name="(\d{4})"', re.I)
LI_EP = re.compile(
    r'<li>\s*<a href="(\d{1,4})/index\.html"[^>]*>([^<]+)</a>\s*</li>',
    re.I,
)
AIR_DATE = re.compile(
    r"Air Date:\s*([A-Za-z]+ \d{1,2}, \d{4})",
    re.I,
)

# Inlined from fetch_neighborhood_archive_episodes to avoid import path issues
def parse_index(html: str) -> dict[int, dict[str, Any]]:
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
            pid = int(ml.group(1), 10)
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


def fetch_url(url: str, headers: dict[str, str] | None = None) -> str:
    h = {"User-Agent": ARCHIVE_UA}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read().decode("latin-1", errors="replace")


def parse_air_date(html: str) -> str:
    m = AIR_DATE.search(html)
    if not m:
        return ""
    try:
        return datetime.strptime(m.group(1), "%B %d, %Y").strftime("%Y-%m-%d")
    except ValueError:
        return ""


# --- TheTVDB v4 ---
TVDB_BASE = "https://api4.thetvdb.com/v4"
SERIES_ID = 77750


def tvdb_login(api_key: str) -> str:
    payload = json.dumps({"apikey": api_key}).encode("utf-8")
    req = urllib.request.Request(
        f"{TVDB_BASE}/login",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.load(resp)
    if data.get("status") != "success":
        raise SystemExit(f"TVDB login failed: {data}")
    return str(data["data"]["token"])


def tvdb_fetch_all_episodes(token: str) -> list[dict[str, Any]]:
    headers = {"Authorization": f"Bearer {token}"}
    all_eps: list[dict[str, Any]] = []
    page = 0
    while True:
        url = f"{TVDB_BASE}/series/{SERIES_ID}/episodes/default/eng?page={page}"
        body = fetch_url(url, headers=headers)
        data = json.loads(body)
        if data.get("status") != "success":
            raise SystemExit(f"TVDB episodes page {page}: {data}")
        all_eps.extend(data["data"]["episodes"])
        nxt = data["links"].get("next")
        if nxt is None:
            break
        page += 1
    return all_eps


def tvdb_sort_key(ep: dict[str, Any]) -> tuple[int, int, int, int]:
    """Prefer regular seasons before specials (season 0) when sharing an air date."""
    sn = int(ep.get("seasonNumber") or 0)
    num = int(ep.get("number") or 0)
    primary = 0 if sn > 0 else 1
    return (primary, sn, num, int(ep.get("id") or 0))


def group_tvdb_by_air(
    episodes: list[dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:
    by: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for ep in episodes:
        ad = ep.get("aired") or ""
        if not ad:
            continue
        by[ad].append(ep)
    for ad in by:
        by[ad].sort(key=tvdb_sort_key)
    return dict(by)


def archive_page_path(cache_dir: Path, pid: int) -> Path:
    return cache_dir / f"{pid:04d}.html"


def fetch_archive_air_date(
    pid: int,
    cache_dir: Optional[Path],
    sleep_s: float,
) -> str:
    if cache_dir is not None:
        cache_dir.mkdir(parents=True, exist_ok=True)
        p = archive_page_path(cache_dir, pid)
        if p.exists():
            return parse_air_date(p.read_text(encoding="latin-1", errors="replace"))
    path = str(pid).zfill(4)
    url = f"{BASE}/mrn/episodes/{path}/index.html"
    try:
        html = fetch_url(url)
    except urllib.error.HTTPError as e:
        print(f"WARN archive {pid}: HTTP {e.code}", file=sys.stderr)
        return ""
    if cache_dir is not None:
        try:
            archive_page_path(cache_dir, pid).write_text(
                html, encoding="latin-1", errors="replace"
            )
        except OSError as e:
            print(f"WARN cache write {pid}: {e}", file=sys.stderr)
    if sleep_s > 0:
        time.sleep(sleep_s)
    return parse_air_date(html)


def assign_tvdb_by_air_date(
    pids_sorted: list[int],
    pid_to_air: dict[int, str],
    tvdb_by_air: dict[str, list[dict[str, Any]]],
) -> dict[int, dict[str, Any]]:
    by_air_archive: dict[str, list[int]] = defaultdict(list)
    for pid in pids_sorted:
        air = pid_to_air.get(pid, "").strip()
        if air:
            by_air_archive[air].append(pid)
    pid_tvdb: dict[int, dict[str, Any]] = {}
    for air, plist in by_air_archive.items():
        plist.sort()
        bucket = tvdb_by_air.get(air, [])
        for i, pid in enumerate(plist):
            if i < len(bucket):
                pid_tvdb[pid] = bucket[i]
    return pid_tvdb


def merge_rows(
    pids_sorted: list[int],
    index_meta: dict[int, dict[str, Any]],
    pid_to_air: dict[int, str],
    tvdb_by_air: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    pid_tvdb = assign_tvdb_by_air_date(pids_sorted, pid_to_air, tvdb_by_air)
    rows: list[dict[str, Any]] = []
    for pid in pids_sorted:
        fallback_title = index_meta[pid]["title"]
        fallback_s = int(index_meta[pid]["season"])
        fallback_e = int(index_meta[pid]["episode"])
        src_arch = f"The Mister Rogers' Neighborhood Archive — {BASE}/mrn/episodes/{str(pid).zfill(4)}/"
        air = pid_to_air.get(pid, "").strip()

        if not air:
            rows.append(
                {
                    "id": pid,
                    "season": fallback_s,
                    "episode": fallback_e,
                    "title": fallback_title,
                    "airDate": "",
                    "source": src_arch + " (air date unavailable)",
                }
            )
            continue

        ep = pid_tvdb.get(pid)
        if ep:
            name = (ep.get("name") or "").strip() or fallback_title
            sn = int(ep.get("seasonNumber") or fallback_s)
            en = int(ep.get("number") or fallback_e)
            src = f"TheTVDB (aired {air}, series {SERIES_ID}) + {src_arch}"
            rows.append(
                {
                    "id": pid,
                    "season": sn,
                    "episode": en,
                    "title": name,
                    "airDate": air,
                    "source": src,
                }
            )
        else:
            rows.append(
                {
                    "id": pid,
                    "season": fallback_s,
                    "episode": fallback_e,
                    "title": fallback_title,
                    "airDate": air,
                    "source": src_arch + " (no TVDB match for this air date)",
                }
            )
    return rows


def _manifest_default_path(episodes_json_path: Path) -> Path:
    return episodes_json_path.with_name("episodes.manifest.json")


def _read_existing_manifest(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        with path.open(encoding="utf-8") as f:
            parsed = json.load(f)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _iso_z(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(tzinfo=timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )


def write_manifest(
    *,
    manifest_path: Path,
    episodes_digest: str,
    data_revision_cli: Optional[str],
    prev_manifest: Optional[dict[str, Any]],
) -> None:
    manifest_path.parent.mkdir(parents=True, exist_ok=True)

    if data_revision_cli:
        revision = data_revision_cli.strip()
    elif prev_manifest and prev_manifest.get("contentSha256") == episodes_digest:
        revision = str(prev_manifest.get("dataRevision") or "")
        if not revision:
            revision = datetime.now(timezone.utc).strftime("mrn-%Y-%m-%d")
    else:
        revision = datetime.now(timezone.utc).strftime("mrn-%Y-%m-%d")

    blob = {
        "dataset": "mister-rogers-bundled",
        "tvdbSeriesId": SERIES_ID,
        "dataRevision": revision,
        "contentSha256": episodes_digest,
        "generatedAt": _iso_z(datetime.now(timezone.utc)),
    }
    with manifest_path.open("w", encoding="utf-8") as f:
        json.dump(blob, f, indent=2, sort_keys=False)
        f.write("\n")


def main() -> None:
    api_key = os.environ.get("TVDB_API_KEY", "").strip()
    if not api_key:
        print(
            "ERROR: Set TVDB_API_KEY to your TheTVDB v4 API key.",
            file=sys.stderr,
        )
        raise SystemExit(2)

    ap = argparse.ArgumentParser()
    root = Path(__file__).resolve().parents[1]
    ap.add_argument(
        "--output",
        default=str(root / "Sources/MisterRogersRenamerCore/Resources/episodes.json"),
    )
    ap.add_argument("--sleep", type=float, default=0.2, help="Delay between Archive fetches")
    ap.add_argument(
        "--cache-dir",
        default="",
        help="Optional: cache Archive HTML (large). Default: no cache.",
    )
    ap.add_argument(
        "--manifest",
        default="",
        help="Path for episodes.manifest.json (default: next to episodes.json)",
    )
    ap.add_argument(
        "--data-revision",
        default="",
        help="Overrides dataRevision in manifest (usually leave unset)",
    )
    args = ap.parse_args()
    cache_dir: Optional[Path] = (
        Path(args.cache_dir) if args.cache_dir.strip() else None
    )

    print("Fetching Archive index…", file=sys.stderr)
    index_html = fetch_url(INDEX_URL)
    index_meta = parse_index(index_html)
    pids = sorted(index_meta.keys())
    print(f"Archive: {len(pids)} productions ({pids[0]}–{pids[-1]})", file=sys.stderr)

    print("TVDB login + episodes…", file=sys.stderr)
    token = tvdb_login(api_key)
    tvdb_eps = tvdb_fetch_all_episodes(token)
    tvdb_by_air = group_tvdb_by_air(tvdb_eps)
    print(f"TheTVDB: {len(tvdb_eps)} episodes with air dates", file=sys.stderr)

    pid_to_air: dict[int, str] = {}
    for i, pid in enumerate(pids):
        pid_to_air[pid] = fetch_archive_air_date(pid, cache_dir, args.sleep)
        if (i + 1) % 50 == 0:
            print(f"  Archive pages… {i + 1}/{len(pids)}", file=sys.stderr)

    rows = merge_rows(pids, index_meta, pid_to_air, tvdb_by_air)
    unmatched = sum(
        1
        for r in rows
        if "no TVDB match" in r["source"] or "air date unavailable" in r["source"]
    )
    if unmatched:
        print(f"NOTE: {unmatched} rows use Archive fallback metadata", file=sys.stderr)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    manifest_path = (
        Path(args.manifest.strip())
        if args.manifest.strip()
        else _manifest_default_path(out_path)
    )

    prev_digest: str | None = None
    prior_manifest = _read_existing_manifest(manifest_path)
    if prior_manifest and isinstance(prior_manifest.get("contentSha256"), str):
        prev_digest = prior_manifest["contentSha256"]

    with out_path.open("w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Wrote {len(rows)} episodes to {out_path}", file=sys.stderr)

    digest = hashlib.sha256(out_path.read_bytes()).hexdigest()
    if prev_digest is not None and prev_digest != digest:
        prev_prefix = prev_digest[:12] + "…"
        print(
            f"Bundled episodes payload changed ({prev_prefix} → {digest[:12]}…)",
            file=sys.stderr,
        )
    elif prev_digest is None:
        print(
            f"Bundled episodes digest (new manifest): {digest[:12]}…",
            file=sys.stderr,
        )
    write_manifest(
        manifest_path=manifest_path,
        episodes_digest=digest,
        data_revision_cli=(args.data_revision.strip() or None),
        prev_manifest=prior_manifest,
    )
    print(f"Wrote manifest {manifest_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
