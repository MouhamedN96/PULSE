#!/usr/bin/env python3
"""
Experiment — Yelp Fusion Baseline
===================================
Fires the 15 golden queries directly at the Yelp Fusion API,
applies the same client-side scorer used in the Places experiment,
and produces NDCG@5 / P@3 / CMR metrics for direct comparison.

Usage:
  python scripts/experiment_yelp_fusion.py
  python scripts/experiment_yelp_fusion.py --api-key YOUR_KEY
  python scripts/experiment_yelp_fusion.py --limit 10 --radius 8000
"""

import argparse
import json
import math
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ── Config ────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
LOG_DIR   = REPO_ROOT / "experiments" / "logs" / "yelp_fusion"
RES_DIR   = REPO_ROOT / "experiments" / "results"

NYC_LAT = 40.7128
NYC_LNG = -74.0060

YELP_SEARCH_URL = "https://api.yelp.com/v3/businesses/search"

# Natural-language query → Yelp term (Yelp is keyword-based, not full NLU)
GOLDEN_QUERIES = [
    {"id": "q01", "text": "best tapas near me",         "yelp_term": "tapas",            "expected_categories": ["food"]},
    {"id": "q02", "text": "Italian dinner tonight",      "yelp_term": "italian",          "expected_categories": ["food"]},
    {"id": "q03", "text": "yoga class tomorrow morning", "yelp_term": "yoga",             "expected_categories": ["wellness"]},
    {"id": "q04", "text": "craft beer bar",              "yelp_term": "craft beer bar",   "expected_categories": ["nightlife"]},
    {"id": "q05", "text": "brunch this weekend",         "yelp_term": "brunch",           "expected_categories": ["food"]},
    {"id": "q06", "text": "contemporary art museum",     "yelp_term": "art museum",       "expected_categories": ["culture"]},
    {"id": "q07", "text": "hidden gem restaurant",       "yelp_term": "restaurant",       "expected_categories": ["food"]},
    {"id": "q08", "text": "coffee shop to work from",    "yelp_term": "coffee",           "expected_categories": ["food"]},
    {"id": "q09", "text": "rooftop bar",                 "yelp_term": "rooftop bar",      "expected_categories": ["nightlife"]},
    {"id": "q10", "text": "japanese ramen",              "yelp_term": "ramen",            "expected_categories": ["food"]},
    {"id": "q11", "text": "something fun for two",       "yelp_term": "entertainment",    "expected_categories": ["fun", "food", "culture"]},
    {"id": "q12", "text": "late night food",             "yelp_term": "late night food",  "expected_categories": ["food", "nightlife"]},
    {"id": "q13", "text": "wellness spa downtown",       "yelp_term": "spa",              "expected_categories": ["wellness"]},
    {"id": "q14", "text": "cheap eats",                  "yelp_term": "food",             "expected_categories": ["food"]},
    {"id": "q15", "text": "french bakery",               "yelp_term": "french bakery",    "expected_categories": ["food"]},
]

# Yelp category alias → ActivityCategory
YELP_CAT_MAP = {
    # Food
    "restaurants": "Food", "food": "Food", "cafes": "Food", "bakeries": "Food",
    "pizza": "Food", "italian": "Food", "japanese": "Food", "spanish": "Food",
    "tapas": "Food", "ramen": "Food", "coffee": "Food", "coffeeroasteries": "Food",
    "breakfast_brunch": "Food", "newamerican": "Food", "tradamerican": "Food",
    "french": "Food", "mediterranean": "Food", "mexican": "Food", "chinese": "Food",
    "thai": "Food", "vietnamese": "Food", "sandwiches": "Food", "burgers": "Food",
    "seafood": "Food", "delis": "Food", "icecream": "Food", "desserts": "Food",
    "indpak": "Food", "greek": "Food", "mideastern": "Food", "korean": "Food",
    "asianfusion": "Food", "diners": "Food", "foodtrucks": "Food",
    # Nightlife
    "bars": "Nightlife", "nightlife": "Nightlife", "cocktailbars": "Nightlife",
    "breweries": "Nightlife", "beerbar": "Nightlife", "divebars": "Nightlife",
    "lounges": "Nightlife", "wine_bars": "Nightlife", "jazzandblues": "Nightlife",
    "karaoke": "Nightlife", "danceclubs": "Nightlife", "sportsbars": "Nightlife",
    "poolhalls": "Nightlife",
    # Wellness
    "fitness": "Wellness", "yoga": "Wellness", "gyms": "Wellness",
    "spas": "Wellness", "massage": "Wellness", "meditation": "Wellness",
    "pilates": "Wellness", "barre": "Wellness", "cycling": "Wellness",
    "crossfit": "Wellness", "swimming": "Wellness", "martialarts": "Wellness",
    "beautysvc": "Wellness", "hair": "Wellness", "nails": "Wellness",
    # Culture
    "museums": "Culture", "galleries": "Culture", "arts": "Culture",
    "culturalcenter": "Culture", "libraries": "Culture", "theater": "Culture",
    "artsandentertainment": "Culture", "publicartsandmuseums": "Culture",
    # Nature
    "parks": "Nature", "hiking": "Nature", "outdoors": "Nature",
    "gardens": "Nature", "beaches": "Nature", "botanicalgardens": "Nature",
    "zoos": "Nature", "aquariums": "Nature",
    # Shopping
    "shopping": "Shopping", "clothing": "Shopping", "bookstores": "Shopping",
    "vintage": "Shopping", "markets": "Shopping", "fashion": "Shopping",
    "accessories": "Shopping", "jewelry": "Shopping", "antiques": "Shopping",
    "gift_shops": "Shopping", "hobby_shops": "Shopping", "florists": "Shopping",
    # Fun
    "entertainment": "Fun", "escapegames": "Fun", "arcades": "Fun",
    "bowling": "Fun", "comedy": "Fun", "amusementparks": "Fun",
    "movietheaters": "Fun", "paintball": "Fun", "lasertag": "Fun",
    "minigolf": "Fun", "rock_climbing": "Fun",
}

# ── Yelp category → ActivityCategory ─────────────────────────────────────────

def yelp_cats_to_activity_cat(categories: list[dict]) -> str:
    for cat in categories:
        alias = cat.get("alias", "")
        if alias in YELP_CAT_MAP:
            return YELP_CAT_MAP[alias]
        # Fuzzy: check if alias contains any key substring
        for key, val in YELP_CAT_MAP.items():
            if key in alias or alias in key:
                return val
    # If no match check parent category titles
    for cat in categories:
        title = cat.get("title", "").lower()
        if any(w in title for w in ("restaurant", "food", "cafe", "bar")): return "Food"
        if any(w in title for w in ("bar", "pub", "club", "nightlife")):   return "Nightlife"
        if any(w in title for w in ("yoga", "gym", "spa", "wellness")):    return "Wellness"
        if any(w in title for w in ("museum", "gallery", "art")):          return "Culture"
        if any(w in title for w in ("park", "garden", "nature")):          return "Nature"
        if any(w in title for w in ("shop", "store", "boutique")):         return "Shopping"
    return "Fun"

# ── Price conversion ──────────────────────────────────────────────────────────

def yelp_price_to_int(price: Optional[str]) -> int:
    if not price:
        return 1
    return min(4, len(price.strip()))

# ── Distance ──────────────────────────────────────────────────────────────────

def meters_to_miles_str(meters: float) -> str:
    miles = meters / 1609.34
    return f"{miles:.1f} mi"

# ── Client-side scorer (mirrors discover_world_controller.dart) ───────────────

def score_activity(act: dict, query: str, max_reviews: int) -> float:
    rating       = act.get("rating", 0) / 5.0
    open_now     = 1.0 if not act.get("is_closed", True) else 0.0
    reviews      = min(1.0, act.get("review_count", 0) / max(max_reviews, 1))
    dist_str     = act.get("_distance_str", "")
    dist_score   = _score_distance(dist_str)
    q_affinity   = _query_affinity(act, query)
    return (rating * 0.24 + open_now * 0.14 + q_affinity * 0.14 +
            reviews * 0.12 + dist_score * 0.07)

def _score_distance(dist_str: str) -> float:
    if not dist_str:
        return 0.5
    try:
        num = float("".join(c for c in dist_str if c.isdigit() or c == ".").strip())
        if "km" in dist_str:
            num *= 0.621371
        return max(0.0, 1.0 - num / 10.0)
    except Exception:
        return 0.5

def _query_affinity(act: dict, query: str) -> float:
    q = query.lower()
    name = act.get("name", "").lower()
    cats = " ".join(c.get("title", "") + " " + c.get("alias", "")
                    for c in act.get("categories", [])).lower()
    tokens = [w for w in q.split() if len(w) > 3 and w not in
              ("near", "best", "good", "some", "this", "with", "from", "tonight",
               "tomorrow", "weekend", "morning", "downtown")]
    if not tokens:
        return 0.5
    hits = sum(1 for t in tokens if t in name or t in cats)
    return min(1.0, hits / len(tokens))

# ── NDCG / relevance ──────────────────────────────────────────────────────────

def grade(act: dict, expected_categories: list[str]) -> int:
    cat = act.get("_activity_category", "").lower()
    cat_match = cat in [c.lower() for c in expected_categories]
    rating = act.get("rating", 0)
    if cat_match and rating >= 4.0:
        return 2
    if cat_match or rating >= 4.5:
        return 1
    return 0

def dcg(grades: list[int], k: int) -> float:
    return sum(g / math.log2(i + 2) for i, g in enumerate(grades[:k]))

def ndcg(grades: list[int], k: int) -> float:
    ideal = sorted(grades, reverse=True)
    idcg = dcg(ideal, k)
    return dcg(grades, k) / idcg if idcg > 0 else 0.0

def precision_at_k(grades: list[int], k: int) -> float:
    return sum(1 for g in grades[:k] if g > 0) / k

def category_match_rate(activities: list[dict], expected_categories: list[str]) -> float:
    if not activities:
        return 0.0
    exp = [c.lower() for c in expected_categories]
    matches = sum(1 for a in activities if a.get("_activity_category", "").lower() in exp)
    return matches / len(activities)

# ── Yelp API ──────────────────────────────────────────────────────────────────

def yelp_search(api_key: str, term: str, lat: float, lng: float,
                limit: int = 10, radius: int = 5000) -> tuple[list[dict], int]:
    params = "&".join([
        f"term={urllib.parse.quote(term)}",
        f"latitude={lat}",
        f"longitude={lng}",
        f"limit={limit}",
        f"radius={radius}",
        "sort_by=best_match",
    ])
    url = f"{YELP_SEARCH_URL}?{params}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {api_key}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read())
            return data.get("businesses", []), data.get("total", 0)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"\n  [YELP ERROR] {e.code}: {body[:200]}", file=sys.stderr)
        return [], 0
    except Exception as exc:
        print(f"\n  [YELP ERROR] {exc}", file=sys.stderr)
        return [], 0


import urllib.parse

# ── Run ───────────────────────────────────────────────────────────────────────

def run_experiment(api_key: str, limit: int, radius: int) -> None:
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    log_run = LOG_DIR / run_id
    log_run.mkdir(parents=True, exist_ok=True)
    RES_DIR.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("  PULSE - Yelp Fusion Benchmark")
    print(f"  Run ID : {run_id}")
    print(f"  Queries: {len(GOLDEN_QUERIES)}")
    print(f"  Limit  : {limit}  Radius: {radius}m")
    print("=" * 60)

    all_per_q = []
    n_success  = 0

    for q in GOLDEN_QUERIES:
        t0 = time.time()
        businesses, total = yelp_search(api_key, q["yelp_term"], NYC_LAT, NYC_LNG, limit, radius)
        latency_ms = (time.time() - t0) * 1000

        if not businesses:
            print(f"  {q['id']}  {latency_ms:>6.0f} ms  0 results  SKIP  {q['text']}")
            all_per_q.append({
                "id": q["id"], "text": q["text"], "yelp_term": q["yelp_term"],
                "result_count": 0, "latency_ms": round(latency_ms, 1),
                "server_ndcg5": 0.0, "client_ndcg5": 0.0,
                "server_p3": 0.0, "client_p3": 0.0,
                "server_cmr": 0.0, "ndcg_delta": 0.0, "total_available": total,
            })
            continue

        n_success += 1
        max_reviews = max((b.get("review_count", 0) for b in businesses), default=1)

        # Annotate each business
        for b in businesses:
            b["_activity_category"] = yelp_cats_to_activity_cat(b.get("categories", []))
            b["_distance_str"] = meters_to_miles_str(b.get("distance", 0))
            b["_client_score"] = score_activity(b, q["text"], max_reviews)

        # Server order (Yelp best_match default)
        server_grades = [grade(b, q["expected_categories"]) for b in businesses]

        # Client re-rank
        client_order = sorted(businesses, key=lambda b: b["_client_score"], reverse=True)
        client_grades = [grade(b, q["expected_categories"]) for b in client_order]

        s_ndcg5 = ndcg(server_grades, 5)
        c_ndcg5 = ndcg(client_grades, 5)
        s_p3    = precision_at_k(server_grades, 3)
        c_p3    = precision_at_k(client_grades, 3)
        s_cmr   = category_match_rate(businesses, q["expected_categories"])

        marker = "  " if abs(c_ndcg5 - s_ndcg5) < 0.01 else (
            "++" if c_ndcg5 > s_ndcg5 else "--")
        print(f"  {q['id']}  {latency_ms:>6.0f} ms  "
              f"server={s_ndcg5:.4f}  client={c_ndcg5:.4f}  {marker}  {q['text']}")

        # Log per-query
        log_entry = {
            "run_id": run_id, "query_id": q["id"], "query_text": q["text"],
            "yelp_term": q["yelp_term"],
            "expected_categories": q["expected_categories"],
            "source": "yelp_fusion",
            "lat": NYC_LAT, "lng": NYC_LNG,
            "latency_ms": round(latency_ms, 1),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "total_available": total,
            "activities": [{
                "id":           b.get("id", ""),
                "name":         b.get("name", ""),
                "category":     b["_activity_category"],
                "yelp_cats":    [c["alias"] for c in b.get("categories", [])],
                "rating":       b.get("rating", 0),
                "review_count": b.get("review_count", 0),
                "price_level":  yelp_price_to_int(b.get("price")),
                "location": {
                    "lat":     b.get("coordinates", {}).get("latitude", 0),
                    "lng":     b.get("coordinates", {}).get("longitude", 0),
                    "address": ", ".join(b.get("location", {}).get("display_address", [])),
                    "city":    "New York, NY",
                },
                "distance":     b["_distance_str"],
                "is_closed":    b.get("is_closed", True),
                "url":          b.get("url", ""),
                "image_url":    b.get("image_url", ""),
                "_grade":       grade(b, q["expected_categories"]),
                "_client_score": round(b["_client_score"], 4),
            } for b in businesses],
        }
        (log_run / f"{q['id']}.json").write_text(
            json.dumps(log_entry, indent=2, ensure_ascii=False), encoding="utf-8")

        all_per_q.append({
            "id": q["id"], "text": q["text"], "yelp_term": q["yelp_term"],
            "result_count": len(businesses),
            "latency_ms": round(latency_ms, 1),
            "server_ndcg5": round(s_ndcg5, 4),
            "client_ndcg5": round(c_ndcg5, 4),
            "server_p3": round(s_p3, 4),
            "client_p3": round(c_p3, 4),
            "server_cmr": round(s_cmr, 4),
            "ndcg_delta": round(c_ndcg5 - s_ndcg5, 4),
            "total_available": total,
        })
        time.sleep(0.3)   # stay under Yelp rate limit (5 req/s)

    # ── Aggregate ────────────────────────────────────────────────────────────
    success_q = [r for r in all_per_q if r["result_count"] > 0]

    def avg(key):
        vals = [r[key] for r in success_q]
        return round(sum(vals) / len(vals), 4) if vals else 0.0

    server_agg  = {"avg_ndcg5": avg("server_ndcg5"), "avg_p3": avg("server_p3"), "avg_cmr": avg("server_cmr")}
    client_agg  = {"avg_ndcg5": avg("client_ndcg5"), "avg_p3": avg("client_p3"), "avg_cmr": avg("server_cmr")}
    avg_latency = round(sum(r["latency_ms"] for r in success_q) / max(len(success_q), 1), 1)

    result = {
        "run_id":             run_id,
        "timestamp":          datetime.now(timezone.utc).isoformat(),
        "source":             "yelp_fusion",
        "query_count":        len(GOLDEN_QUERIES),
        "successful_queries": n_success,
        "avg_latency_ms":     avg_latency,
        "server_order":       server_agg,
        "client_rerank":      client_agg,
        "per_query":          all_per_q,
    }
    out = RES_DIR / f"yelp_fusion_{run_id}.json"
    out.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")

    # ── Print summary ─────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print(f"  RESULTS  ({n_success}/{len(GOLDEN_QUERIES)} queries succeeded)")
    print("=" * 60)
    print(f"  {'Metric':<28} {'Server order':>12}  {'Client rerank':>13}  {'Delta':>8}")
    print(f"  {'-'*28}  {'-'*12}  {'-'*13}  {'-'*8}")
    for label, sk, ck in [
        ("NDCG@5",        "avg_ndcg5", "avg_ndcg5"),
        ("Precision@3",   "avg_p3",    "avg_p3"),
        ("Category match","avg_cmr",   "avg_cmr"),
    ]:
        sv, cv = server_agg[sk], client_agg[ck]
        print(f"  {label:<28} {sv:>12.4f}  {cv:>13.4f}  {cv-sv:>+8.4f}")
    print(f"\n  Avg latency  : {avg_latency:.0f} ms")
    print()
    print("  Per-query breakdown:")
    print(f"  {'ID':<6} {'Server':>11}  {'Client':>11}  {'Delta':>8}  Query")
    print(f"  {'-'*6}  {'-'*11}  {'-'*11}  {'-'*8}  {'-'*30}")
    for r in all_per_q:
        if r["result_count"] == 0:
            print(f"  {r['id']:<6}        SKIP          SKIP           —  {r['text']}")
        else:
            d = r["ndcg_delta"]
            sign = f"{d:+.4f}"
            print(f"  {r['id']:<6} {r['server_ndcg5']:>11.4f}  {r['client_ndcg5']:>11.4f}  {sign:>8}  {r['text']}")
    safe_out = str(out).encode("ascii", "replace").decode("ascii")
    print(f"\n  Full logs : experiments/logs/yelp_fusion/{run_id}/")
    print(f"  Report    : {safe_out}")
    print()


def main():
    parser = argparse.ArgumentParser(description="Yelp Fusion benchmark")
    parser.add_argument("--api-key", default=None,
                        help="Yelp API key (default: YELP_API_Key from .env)")
    parser.add_argument("--limit",   type=int, default=10, help="Results per query (max 50)")
    parser.add_argument("--radius",  type=int, default=5000, help="Search radius in metres (max 40000)")
    args = parser.parse_args()

    # Load .env manually if needed
    env_file = REPO_ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                os.environ.setdefault(k.strip(), v.strip())

    api_key = args.api_key or os.environ.get("YELP_API_Key") or os.environ.get("YELP_API_KEY")
    if not api_key:
        sys.exit("ERROR: Yelp API key not found. Set YELP_API_Key in .env or pass --api-key.")

    run_experiment(api_key, args.limit, args.radius)


if __name__ == "__main__":
    main()
