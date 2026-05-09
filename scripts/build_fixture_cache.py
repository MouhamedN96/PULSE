"""
build_fixture_cache.py
======================
Builds experiments/fixtures/nyc_venues.json from cached Google Places logs.

Usage:
  python scripts/build_fixture_cache.py                      # aggregate best run
  python scripts/build_fixture_cache.py --run 20260430T051138Z  # specific run
  python scripts/build_fixture_cache.py --fetch-supplement   # also hit Railway for missing cats
  python scripts/build_fixture_cache.py --base-url http://localhost:3001  # local server
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from typing import Any

ROOT = pathlib.Path(__file__).parent.parent
LOGS_DIR = ROOT / "experiments" / "logs" / "places"
FIXTURE_DIR = ROOT / "experiments" / "fixtures"
FIXTURE_FILE = FIXTURE_DIR / "nyc_venues.json"
SEED_FILE = ROOT / "rust_core" / "data" / "nyc_seed.json"

RAILWAY_URL = "https://pulse-production-62b2.up.railway.app"

# Queries used for supplemental fetching per missing category
SUPPLEMENT_QUERIES: dict[str, list[str]] = {
    "Shopping": [
        "vintage clothing store",
        "bookshop",
        "local market",
        "design store",
    ],
    "Nature": [
        "park outdoor",
        "botanical garden",
        "riverside walk",
    ],
    "Sports": [
        "rock climbing gym",
        "basketball court",
        "cycling trail",
    ],
}

NYC_LAT, NYC_LNG = 40.7128, -74.006


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _pick_best_run() -> pathlib.Path | None:
    """Return the run directory with the most log files."""
    runs = [d for d in LOGS_DIR.iterdir() if d.is_dir()]
    if not runs:
        return None
    return max(runs, key=lambda d: len(list(d.glob("*.json"))))


def _load_run(run_dir: pathlib.Path) -> dict[str, Any]:
    """Load all query logs from a run dir, return {place_id: activity}."""
    venues: dict[str, Any] = {}
    for log_file in sorted(run_dir.glob("*.json")):
        data = json.loads(log_file.read_text(encoding="utf-8"))
        for act in data.get("activities", []):
            vid = act.get("id", "")
            if vid and vid not in venues:
                venues[vid] = act
    return venues


def _fetch_from_server(base_url: str, query: str) -> list[dict]:
    """POST /api/recommend and return activities list."""
    payload = json.dumps({
        "query": query,
        "lat": NYC_LAT,
        "lng": NYC_LNG,
        "provider": "local",
    }).encode()
    url = f"{base_url.rstrip('/')}/api/recommend"
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.loads(resp.read())
            return body.get("activities", [])
    except (urllib.error.URLError, json.JSONDecodeError) as exc:
        print(f"  [WARN] fetch failed for '{query}': {exc}", file=sys.stderr)
        return []


def _normalize(act: dict) -> dict:
    """Strip fields that expire or vary across runs; keep stable identifiers."""
    # Keep photo URLs — they may still work; if they expire the venue data is still valid
    loc = act.get("location", {})
    return {
        "id": act.get("id", ""),
        "name": act.get("name", ""),
        "description": act.get("description", ""),
        "category": act.get("category", ""),
        "subcategories": act.get("subcategories", []),
        "location": {
            "lat": loc.get("lat", 0.0),
            "lng": loc.get("lng", 0.0),
            "address": loc.get("address", ""),
            "neighborhood": loc.get("neighborhood", ""),
            "city": "New York, NY",
        },
        "rating": act.get("rating", 0.0),
        "review_count": act.get("review_count", 0),
        "price_level": act.get("price_level", 1),
        "tags": act.get("tags", []),
        "open_hours": act.get("open_hours", ""),
        "phone": act.get("phone", ""),
        "website": act.get("website", ""),
        "images": act.get("images", []),
        "is_open": act.get("is_open", False),
        "ai_summary": None,
        "why_recommended": "Fixture — cached NYC venue",
        # Store distance as None; server will recompute from lat/lng at serve time
        "distance": act.get("distance", ""),
    }


def _category_counts(venues: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for v in venues.values():
        cat = v.get("category", "Unknown")
        counts[cat] = counts.get(cat, 0) + 1
    return counts


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Build NYC venue fixture cache")
    parser.add_argument("--run", help="Specific run ID to aggregate (default: best run)")
    parser.add_argument(
        "--fetch-supplement",
        action="store_true",
        help="Fetch additional venues from server for missing categories",
    )
    parser.add_argument(
        "--base-url",
        default=RAILWAY_URL,
        help=f"Server base URL for supplemental fetch (default: {RAILWAY_URL})",
    )
    parser.add_argument(
        "--categories",
        nargs="+",
        default=list(SUPPLEMENT_QUERIES.keys()),
        help="Which categories to supplement (default: Shopping Nature Sports)",
    )
    args = parser.parse_args()

    # ── Step 1: Load existing run logs ────────────────────────────────────────
    if args.run:
        run_dir = LOGS_DIR / args.run
        if not run_dir.exists():
            sys.exit(f"Run directory not found: {run_dir}")
    else:
        run_dir = _pick_best_run()
        if not run_dir is None:
            print(f"[1/4] Using best run: {run_dir.name}")
        else:
            print("[1/4] No run logs found — will fetch everything from server")
            run_dir = None

    venues: dict[str, Any] = {}
    if run_dir:
        raw = _load_run(run_dir)
        venues = {vid: _normalize(act) for vid, act in raw.items()}
        print(f"      Loaded {len(venues)} unique venues from logs")
        counts = _category_counts(venues)
        for cat, n in sorted(counts.items()):
            print(f"      {cat:<12} {n:>3} venues")

    # ── Step 2: Supplemental fetch for missing categories ─────────────────────
    if args.fetch_supplement:
        counts_before = _category_counts(venues)
        missing = [c for c in args.categories if counts_before.get(c, 0) < 5]
        if not missing:
            print("[2/4] All target categories adequately covered — skipping supplement")
        else:
            print(f"[2/4] Fetching supplemental venues for: {missing}")
            for cat in missing:
                queries = SUPPLEMENT_QUERIES.get(cat, [])
                fetched_for_cat = 0
                for q in queries:
                    print(f"      >> '{q}' ... ", end="", flush=True)
                    acts = _fetch_from_server(args.base_url, q)
                    new_count = 0
                    for act in acts:
                        vid = act.get("id", "")
                        if vid and vid not in venues:
                            venues[vid] = _normalize(act)
                            new_count += 1
                            fetched_for_cat += 1
                    print(f"{new_count} new")
                    time.sleep(0.5)
                print(f"      {cat}: added {fetched_for_cat} venues")
    else:
        print("[2/4] Skipping supplement (use --fetch-supplement to add Shopping/Nature/Sports)")

    # ── Step 3: Write fixture file ─────────────────────────────────────────────
    print(f"[3/4] Writing fixture  ({len(venues)} venues)")
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)

    final_counts = _category_counts(venues)
    venue_list = sorted(venues.values(), key=lambda v: (-v["rating"], v["name"]))

    metadata = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_run": run_dir.name if run_dir else "supplement_only",
        "total_venues": len(venue_list),
        "category_counts": final_counts,
        "city": "New York, NY",
        "center_lat": NYC_LAT,
        "center_lng": NYC_LNG,
    }

    fixture = {"metadata": metadata, "venues": venue_list}
    FIXTURE_FILE.write_text(
        json.dumps(fixture, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    size_kb = FIXTURE_FILE.stat().st_size // 1024
    safe_fixture = str(FIXTURE_FILE).encode("ascii", "replace").decode("ascii")
    print(f"      Wrote {safe_fixture} ({size_kb} KB)")
    for cat, n in sorted(final_counts.items()):
        bar = "#" * n
        print(f"      {cat:<12} {n:>3}  {bar}")

    # ── Step 4: Copy to rust_core/data/ for server startup load ───────────────
    safe_seed = str(SEED_FILE).encode("ascii", "replace").decode("ascii")
    print(f"[4/4] Copying to Rust data dir: {safe_seed}")
    SEED_FILE.parent.mkdir(parents=True, exist_ok=True)
    # Rust loads a flat list of venues (no metadata wrapper)
    SEED_FILE.write_text(
        json.dumps(venue_list, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    seed_kb = SEED_FILE.stat().st_size // 1024
    print(f"      Wrote {safe_seed} ({seed_kb} KB)")

    print(f"\nDone. {len(venue_list)} NYC venues cached.")
    print("  experiments/fixtures/nyc_venues.json  -- full fixture with metadata")
    print("  rust_core/data/nyc_seed.json          -- flat list for server startup")
    if final_counts.get("Shopping", 0) < 5:
        print(
            "\n  TIP: re-run with --fetch-supplement to add Shopping/Nature venues from Railway"
        )


if __name__ == "__main__":
    main()
