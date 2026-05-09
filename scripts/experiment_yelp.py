#!/usr/bin/env python3
"""
Experiment 2 — Yelp Dataset Offline Evaluation
===============================================
Evaluates the mock-path ranking logic (rating-sort + client scorer) against
the Yelp Open Dataset business file. No server required.

Steps:
  1. Download the Yelp dataset: https://www.yelp.com/dataset
     Extract yelp_academic_dataset_business.json (one JSON object per line)
  2. Place it at: experiments/yelp_academic_dataset_business.json
     (or pass --yelp-file path/to/file)
  3. Run: python scripts/experiment_yelp.py

What it measures:
  - Random baseline NDCG@5
  - Rating-sort NDCG@5  (what the mock path does today)
  - Review-count-sort NDCG@5
  - Client scorer NDCG@5 (simulated without session signals)
  - Category match rate for each ranking method
"""

import argparse
import json
import math
import random
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
RES_DIR   = REPO_ROOT / "experiments" / "results"
DEFAULT_YELP_FILE = REPO_ROOT / "experiments" / "yelp_academic_dataset_business.json"

# ── Category mapping: Yelp → ActivityCategory ─────────────────────────────────

CATEGORY_MAP = {
    "restaurants":      "food",
    "food":             "food",
    "coffee":           "food",
    "cafes":            "food",
    "bakeries":         "food",
    "bars":             "nightlife",
    "nightlife":        "nightlife",
    "cocktail bars":    "nightlife",
    "fitness":          "wellness",
    "yoga":             "wellness",
    "gyms":             "wellness",
    "spas":             "wellness",
    "massage":          "wellness",
    "museums":          "culture",
    "art galleries":    "culture",
    "arts":             "culture",
    "theaters":         "culture",
    "shopping":         "shopping",
    "fashion":          "shopping",
    "parks":            "nature",
    "hiking":           "nature",
    "bowling":          "fun",
    "arcades":          "fun",
    "escape games":     "fun",
    "amusement parks":  "fun",
}

QUERY_CATEGORIES = {
    "q01": ["food"],
    "q02": ["food"],
    "q03": ["wellness"],
    "q04": ["nightlife"],
    "q05": ["food"],
    "q06": ["culture"],
    "q07": ["food"],
    "q08": ["food"],
    "q09": ["nightlife"],
    "q10": ["food"],
    "q11": ["fun", "food", "culture"],
    "q12": ["food", "nightlife"],
    "q13": ["wellness"],
    "q14": ["food"],
    "q15": ["food"],
}

QUERY_TEXTS = {
    "q01": "best tapas near me",
    "q02": "Italian dinner tonight",
    "q03": "yoga class tomorrow morning",
    "q04": "craft beer bar",
    "q05": "brunch this weekend",
    "q06": "contemporary art museum",
    "q07": "hidden gem restaurant",
    "q08": "coffee shop to work from",
    "q09": "rooftop bar",
    "q10": "japanese ramen",
    "q11": "something fun for two",
    "q12": "late night food",
    "q13": "wellness spa downtown",
    "q14": "cheap eats",
    "q15": "french bakery",
}

# Keywords per query for affinity scoring (mirrors agent.rs intent parser)
QUERY_KEYWORDS = {
    "q01": ["tapas", "spanish"],
    "q02": ["italian", "pizza", "pasta", "dinner"],
    "q03": ["yoga", "wellness", "class"],
    "q04": ["beer", "bar", "craft", "pub"],
    "q05": ["brunch", "breakfast", "weekend"],
    "q06": ["art", "museum", "gallery", "exhibition"],
    "q07": ["restaurant", "gem", "hidden"],
    "q08": ["coffee", "cafe", "work"],
    "q09": ["bar", "rooftop"],
    "q10": ["japanese", "ramen", "sushi"],
    "q11": ["fun", "entertainment", "game"],
    "q12": ["food", "late", "night"],
    "q13": ["wellness", "spa", "massage"],
    "q14": ["food", "cheap", "eats"],
    "q15": ["french", "bakery", "croissant"],
}

# ── Yelp business loader ───────────────────────────────────────────────────────

def map_yelp_category(categories_str: str) -> Optional[str]:
    if not categories_str:
        return None
    cats = [c.strip().lower() for c in categories_str.split(",")]
    for cat in cats:
        if cat in CATEGORY_MAP:
            return CATEGORY_MAP[cat]
    return None

def load_yelp_businesses(path: Path, city: str, min_reviews: int = 10,
                          limit: int = 5000) -> list[dict]:
    businesses = []
    print(f"  Loading Yelp businesses for '{city}' (min {min_reviews} reviews, limit {limit})...")
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                biz = json.loads(line)
            except json.JSONDecodeError:
                continue

            if biz.get("city", "").lower() != city.lower():
                continue
            if biz.get("review_count", 0) < min_reviews:
                continue
            if not biz.get("is_open", 1):
                continue

            mapped_cat = map_yelp_category(biz.get("categories", ""))
            if not mapped_cat:
                continue

            businesses.append({
                "id":           biz.get("business_id", ""),
                "name":         biz.get("name", ""),
                "category":     mapped_cat,
                "tags":         [c.strip().lower() for c in biz.get("categories", "").split(",")],
                "rating":       float(biz.get("stars", 0.0)),
                "reviewCount":  int(biz.get("review_count", 0)),
                "isOpen":       bool(biz.get("is_open", 1)),
                "lat":          biz.get("latitude", 0.0),
                "lng":          biz.get("longitude", 0.0),
                "address":      biz.get("address", ""),
                "distance":     None,  # no user location in offline eval
            })

            if len(businesses) >= limit:
                break

    print(f"  Loaded {len(businesses)} businesses")
    return businesses

# ── Relevance and metrics ──────────────────────────────────────────────────────

def relevance(biz: dict, expected_categories: list[str]) -> int:
    cat_match = biz["category"] in expected_categories
    rating    = biz["rating"]
    if cat_match and rating >= 4.0:
        return 2
    if cat_match or rating >= 4.5:
        return 1
    return 0

def dcg(relevances: list[int], k: int = 5) -> float:
    return sum(rel / math.log2(i + 2) for i, rel in enumerate(relevances[:k]))

def ndcg(ranked: list[dict], expected_categories: list[str], k: int = 5) -> float:
    labels = [relevance(b, expected_categories) for b in ranked]
    ideal  = sorted(labels, reverse=True)
    idcg   = dcg(ideal, k)
    return round(dcg(labels, k) / idcg, 4) if idcg > 0 else 0.0

def precision_at_k(ranked: list[dict], expected_categories: list[str], k: int = 3) -> float:
    labels = [1 if relevance(b, expected_categories) > 0 else 0 for b in ranked[:k]]
    return round(sum(labels) / k, 4) if labels else 0.0

def category_match_rate(ranked: list[dict], expected_categories: list[str]) -> float:
    if not ranked:
        return 0.0
    return round(sum(1 for b in ranked if b["category"] in expected_categories) / len(ranked), 4)

# ── Client scorer (mirrors discover_world_controller.dart) ─────────────────────

def query_affinity(biz: dict, keywords: list[str]) -> float:
    if not keywords:
        return 0.0
    haystack = " ".join([biz["name"]] + biz["tags"]).lower()
    matches  = sum(1 for kw in keywords if kw in haystack)
    return max(0.0, min(1.0, matches / len(keywords)))

def client_score(biz: dict, keywords: list[str], max_reviews: int,
                 preferred_categories: set[str]) -> float:
    r  = max(0.0, min(1.0, biz["rating"] / 5.0))
    rv = max(0.0, min(1.0, biz["reviewCount"] / max_reviews)) if max_reviews > 0 else 0.0
    op = 1.0 if biz["isOpen"] else 0.0
    qa = query_affinity(biz, keywords)
    pc = 1.0 if biz["category"] in preferred_categories else 0.0
    return (r  * 0.24 +
            rv * 0.12 +
            op * 0.14 +
            0  * 0.14 +   # saved
            pc * 0.11 +
            0  * 0.08 +   # preferred tags
            qa * 0.14 +
            0  * 0.07 +   # distance (not available offline)
            0  * 0.06)    # network affinity

# ── Rankers ───────────────────────────────────────────────────────────────────

def rank_random(pool: list[dict], k: int = 10) -> list[dict]:
    sample = random.sample(pool, min(k, len(pool)))
    return sample

def rank_by_rating(pool: list[dict], k: int = 10) -> list[dict]:
    return sorted(pool, key=lambda b: b["rating"], reverse=True)[:k]

def rank_by_reviews(pool: list[dict], k: int = 10) -> list[dict]:
    return sorted(pool, key=lambda b: b["reviewCount"], reverse=True)[:k]

def rank_client(pool: list[dict], keywords: list[str],
                preferred_categories: set[str], k: int = 10) -> list[dict]:
    if not pool:
        return []
    max_rev = max(b["reviewCount"] for b in pool)
    scored  = sorted(pool,
                     key=lambda b: client_score(b, keywords, max_rev, preferred_categories),
                     reverse=True)
    return scored[:k]

# ── Main ──────────────────────────────────────────────────────────────────────

def run(yelp_file: Path, city: str, min_reviews: int, runs: int) -> None:
    RES_DIR.mkdir(parents=True, exist_ok=True)

    if not yelp_file.exists():
        print(f"\n  ERROR: Yelp file not found at {yelp_file}")
        print("  Download it from https://www.yelp.com/dataset")
        print("  Extract yelp_academic_dataset_business.json and place it at:")
        print(f"  {yelp_file}\n")
        return

    businesses = load_yelp_businesses(yelp_file, city, min_reviews)
    if not businesses:
        print(f"  No businesses found for city='{city}'. Try a different city (e.g. Philadelphia, Las Vegas).")
        return

    random.seed(42)
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    print(f"\n{'='*60}")
    print(f"  PULSE — Yelp Offline Benchmark")
    print(f"  Run ID : {run_id}")
    print(f"  City   : {city}  ({len(businesses)} businesses)")
    print(f"  Queries: {len(QUERY_CATEGORIES)}")
    print(f"{'='*60}\n")

    all_results = []

    for qid, expected_cats in QUERY_CATEGORIES.items():
        keywords = QUERY_KEYWORDS.get(qid, [])

        # Use a random pool of 50 businesses for each query (simulates what the
        # server would return before ranking — no real retrieval at this layer)
        pool = random.sample(businesses, min(50, len(businesses)))

        rand_ranked   = rank_random(pool, 10)
        rating_ranked = rank_by_rating(pool, 10)
        review_ranked = rank_by_reviews(pool, 10)
        client_ranked = rank_client(pool, keywords, set(expected_cats), 10)

        all_results.append({
            "qid":              qid,
            "text":             QUERY_TEXTS[qid],
            "expected_cats":    expected_cats,
            "pool_size":        len(pool),
            "random_ndcg5":    ndcg(rand_ranked,   expected_cats),
            "rating_ndcg5":    ndcg(rating_ranked, expected_cats),
            "reviews_ndcg5":   ndcg(review_ranked, expected_cats),
            "client_ndcg5":    ndcg(client_ranked, expected_cats),
            "random_p3":       precision_at_k(rand_ranked,   expected_cats),
            "rating_p3":       precision_at_k(rating_ranked, expected_cats),
            "reviews_p3":      precision_at_k(review_ranked, expected_cats),
            "client_p3":       precision_at_k(client_ranked, expected_cats),
        })

    def mean(vals): return round(sum(vals) / len(vals), 4) if vals else 0.0

    report = {
        "run_id":       run_id,
        "timestamp":    datetime.now(timezone.utc).isoformat(),
        "city":         city,
        "dataset_size": len(businesses),
        "query_count":  len(all_results),
        "summary": {
            "random":  {"avg_ndcg5": mean([r["random_ndcg5"]  for r in all_results]),
                        "avg_p3":    mean([r["random_p3"]     for r in all_results])},
            "rating":  {"avg_ndcg5": mean([r["rating_ndcg5"]  for r in all_results]),
                        "avg_p3":    mean([r["rating_p3"]     for r in all_results])},
            "reviews": {"avg_ndcg5": mean([r["reviews_ndcg5"] for r in all_results]),
                        "avg_p3":    mean([r["reviews_p3"]    for r in all_results])},
            "client":  {"avg_ndcg5": mean([r["client_ndcg5"]  for r in all_results]),
                        "avg_p3":    mean([r["client_p3"]     for r in all_results])},
        },
        "per_query": all_results,
    }

    report_path = RES_DIR / f"yelp_{city.lower().replace(' ', '_')}_{run_id}.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    # Print
    print(f"  {'Ranker':<22}  {'NDCG@5':>8}  {'Precision@3':>12}  {'vs Random':>10}")
    print(f"  {'-'*22}  {'-'*8}  {'-'*12}  {'-'*10}")
    base = report["summary"]["random"]["avg_ndcg5"]
    for key, label in [("random", "Random baseline"),
                        ("rating", "Rating-sort (mock today)"),
                        ("reviews", "Review-count-sort"),
                        ("client", "Client scorer")]:
        s = report["summary"][key]
        delta = round(s["avg_ndcg5"] - base, 4)
        sign  = "+" if delta >= 0 else ""
        print(f"  {label:<22}  {s['avg_ndcg5']:>8.4f}  {s['avg_p3']:>12.4f}  {sign}{delta:>9.4f}")

    print(f"\n  Per-query NDCG@5:")
    print(f"  {'ID':<5}  {'Random':>7}  {'Rating':>7}  {'Reviews':>8}  {'Client':>7}  {'Text'}")
    print(f"  {'-'*5}  {'-'*7}  {'-'*7}  {'-'*8}  {'-'*7}  {'-'*30}")
    for r in all_results:
        print(f"  {r['qid']:<5}  {r['random_ndcg5']:>7.4f}  {r['rating_ndcg5']:>7.4f}  "
              f"{r['reviews_ndcg5']:>8.4f}  {r['client_ndcg5']:>7.4f}  {r['text'][:40]}")

    print(f"\n  Report saved: experiments/results/{report_path.name}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PULSE — Yelp offline benchmark")
    parser.add_argument("--yelp-file",   default=str(DEFAULT_YELP_FILE),
                        help="Path to yelp_academic_dataset_business.json")
    parser.add_argument("--city",        default="Philadelphia",
                        help="City to filter (default: Philadelphia — largest in Yelp dataset)")
    parser.add_argument("--min-reviews", type=int, default=10,
                        help="Minimum review count to include a business (default: 10)")
    parser.add_argument("--runs",        type=int, default=1,
                        help="Number of random sampling runs to average (default: 1)")
    args = parser.parse_args()
    run(Path(args.yelp_file), args.city, args.min_reviews, args.runs)
