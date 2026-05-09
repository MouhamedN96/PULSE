#!/usr/bin/env python3
"""
Experiment 1 — Google Places Baseline Capture
==============================================
Fires the 15 golden queries at the running local server (or Railway),
saves raw JSON responses, simulates the client-side scorer,
and writes a comparison report to experiments/results/.

Usage:
  # With server already running on port 8787:
  python scripts/experiment_places.py

  # Against Railway:
  python scripts/experiment_places.py --base-url https://pulse-production-62b2.up.railway.app

  # Dry-run (uses cached logs if present, skips API calls):
  python scripts/experiment_places.py --dry-run
"""

import argparse
import json
import math
import time
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import urllib.request
import urllib.error

# ── Config ────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
LOG_DIR   = REPO_ROOT / "experiments" / "logs" / "places"
RES_DIR   = REPO_ROOT / "experiments" / "results"

# New York City — matches Flutter client default
DEFAULT_LAT = 40.7128
DEFAULT_LNG = -74.0060

# 15 golden queries — cover the intent parser's full vocabulary
GOLDEN_QUERIES = [
    {"id": "q01", "text": "best tapas near me",          "expected_categories": ["food"]},
    {"id": "q02", "text": "Italian dinner tonight",       "expected_categories": ["food"]},
    {"id": "q03", "text": "yoga class tomorrow morning",  "expected_categories": ["wellness"]},
    {"id": "q04", "text": "craft beer bar",               "expected_categories": ["nightlife"]},
    {"id": "q05", "text": "brunch this weekend",          "expected_categories": ["food"]},
    {"id": "q06", "text": "contemporary art museum",      "expected_categories": ["culture"]},
    {"id": "q07", "text": "hidden gem restaurant",        "expected_categories": ["food"]},
    {"id": "q08", "text": "coffee shop to work from",     "expected_categories": ["food"]},
    {"id": "q09", "text": "rooftop bar",                  "expected_categories": ["nightlife"]},
    {"id": "q10", "text": "japanese ramen",               "expected_categories": ["food"]},
    {"id": "q11", "text": "something fun for two",        "expected_categories": ["fun", "food", "culture"]},
    {"id": "q12", "text": "late night food",              "expected_categories": ["food", "nightlife"]},
    {"id": "q13", "text": "wellness spa downtown",        "expected_categories": ["wellness"]},
    {"id": "q14", "text": "cheap eats",                   "expected_categories": ["food"]},
    {"id": "q15", "text": "french bakery",                "expected_categories": ["food"]},
]

# ── Scoring (mirrors discover_world_controller.dart:_scoreActivity) ───────────

def score_rating(rating: float) -> float:
    return max(0.0, min(1.0, rating / 5.0))

def score_reviews(count: int, max_count: int) -> float:
    if max_count <= 0:
        return 0.0
    return max(0.0, min(1.0, count / max_count))

def score_open(is_open: bool) -> float:
    return 1.0 if is_open else 0.0

def score_distance(distance_str: Optional[str]) -> float:
    if not distance_str:
        return 0.5
    low = distance_str.lower()
    num_str = "".join(c if c.isdigit() or c == "." else " " for c in low).strip().split()[0] if any(c.isdigit() for c in low) else None
    if num_str is None:
        return 0.5
    try:
        val = float(num_str)
    except ValueError:
        return 0.5
    if "mi" in low:
        return max(0.0, min(1.0, 1.0 / (1.0 + val)))
    return max(0.0, min(1.0, 1.0 / (1.0 + val / 1000.0)))

def score_query_affinity(activity: dict, query_tokens: list[str]) -> float:
    if not query_tokens:
        return 0.0
    haystack = " ".join([
        activity.get("name", ""),
        activity.get("description", ""),
        activity.get("category", ""),
        " ".join(activity.get("subcategories", [])),
        " ".join(activity.get("tags", [])),
        activity.get("location", {}).get("neighborhood", ""),
        activity.get("location", {}).get("city", ""),
    ]).lower()
    matches = sum(1 for t in query_tokens if t in haystack)
    return max(0.0, min(1.0, matches / len(query_tokens)))

def client_score(activity: dict, query_tokens: list[str], max_reviews: int,
                 preferred_categories: set[str] | None = None) -> float:
    preferred_categories = preferred_categories or set()
    r  = score_rating(activity.get("rating", 0.0))
    rv = score_reviews(activity.get("reviewCount", 0), max_reviews)
    op = score_open(activity.get("isOpen", True))
    qa = score_query_affinity(activity, query_tokens)
    d  = score_distance(activity.get("distance"))
    pc = 1.0 if activity.get("category", "") in preferred_categories else 0.0

    return (r  * 0.24 +
            rv * 0.12 +
            op * 0.14 +
            0  * 0.14 +   # saved — unknown at eval time
            pc * 0.11 +
            0  * 0.08 +   # preferred tags — unknown at eval time
            qa * 0.14 +
            d  * 0.07 +
            0  * 0.06)    # network affinity — unknown at eval time

# ── Metrics ───────────────────────────────────────────────────────────────────

def relevance_label(activity: dict, expected_categories: list[str]) -> int:
    """
    Simple heuristic label without human raters:
      2 = category matches AND rating >= 4.0
      1 = category matches OR rating >= 4.5
      0 = neither
    """
    cat_match = activity.get("category", "").lower() in [c.lower() for c in expected_categories]
    rating = activity.get("rating", 0.0)
    if cat_match and rating >= 4.0:
        return 2
    if cat_match or rating >= 4.5:
        return 1
    return 0

def dcg(relevances: list[int], k: int = 5) -> float:
    return sum(rel / math.log2(i + 2) for i, rel in enumerate(relevances[:k]))

def ndcg(result_ids_ordered: list[dict], query: dict, k: int = 5) -> float:
    labels = [relevance_label(a, query["expected_categories"]) for a in result_ids_ordered]
    ideal  = sorted(labels, reverse=True)
    idcg   = dcg(ideal, k)
    return round(dcg(labels, k) / idcg, 4) if idcg > 0 else 0.0

def precision_at_k(activities: list[dict], query: dict, k: int = 3) -> float:
    labels = [1 if relevance_label(a, query["expected_categories"]) > 0 else 0
              for a in activities[:k]]
    return round(sum(labels) / k, 4)

def category_match_rate(activities: list[dict], query: dict) -> float:
    matched = sum(1 for a in activities
                  if a.get("category", "").lower() in query["expected_categories"])
    return round(matched / len(activities), 4) if activities else 0.0

# ── HTTP helpers ──────────────────────────────────────────────────────────────

def post_json(url: str, payload: dict, timeout: int = 15) -> tuple[dict, float]:
    data = json.dumps(payload).encode()
    req  = urllib.request.Request(url, data=data,
                                  headers={"Content-Type": "application/json"},
                                  method="POST")
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read()
    latency = time.monotonic() - t0
    return json.loads(body), latency

# ── Main ──────────────────────────────────────────────────────────────────────

def run(base_url: str, dry_run: bool, provider: str) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    RES_DIR.mkdir(parents=True, exist_ok=True)

    run_id  = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = LOG_DIR / run_id
    run_dir.mkdir()

    recommend_url = f"{base_url.rstrip('/')}/api/recommend"
    print(f"\n{'='*60}")
    print(f"  PULSE — Google Places Benchmark")
    print(f"  Run ID : {run_id}")
    print(f"  Server : {base_url}")
    print(f"  Provider: {provider}")
    print(f"  Queries: {len(GOLDEN_QUERIES)}")
    print(f"{'='*60}\n")

    results = []

    for q in GOLDEN_QUERIES:
        log_path = run_dir / f"{q['id']}.json"

        if dry_run and log_path.exists():
            with open(log_path) as f:
                log = json.load(f)
            print(f"  [DRY] {q['id']} — loaded from cache")
        else:
            payload = {
                "query":    q["text"],
                "lat":      DEFAULT_LAT,
                "lng":      DEFAULT_LNG,
                "provider": provider,
            }
            try:
                response, latency_s = post_json(recommend_url, payload)
                log = {
                    "run_id":          run_id,
                    "query_id":        q["id"],
                    "query_text":      q["text"],
                    "expected_categories": q["expected_categories"],
                    "provider":        provider,
                    "lat":             DEFAULT_LAT,
                    "lng":             DEFAULT_LNG,
                    "latency_ms":      round(latency_s * 1000),
                    "timestamp":       datetime.now(timezone.utc).isoformat(),
                    "server_summary":  response.get("summary", ""),
                    "activities":      response.get("activities", []),
                    "filters":         response.get("filters", []),
                }
                with open(log_path, "w") as f:
                    json.dump(log, f, indent=2)
                print(f"  {q['id']}  {latency_s*1000:6.0f} ms  {q['text'][:45]}")
            except Exception as exc:
                print(f"  {q['id']}  ERROR  {exc}")
                log = {"query_id": q["id"], "query_text": q["text"],
                       "activities": [], "error": str(exc)}

        activities = log.get("activities", [])
        if not activities:
            results.append({"query": q, "activities": [], "error": log.get("error")})
            continue

        max_reviews = max((a.get("reviewCount", 0) for a in activities), default=1)
        query_tokens = [t for t in q["text"].lower().split() if len(t) > 2]

        # Server order (Google Places default)
        server_ndcg5 = ndcg(activities, q)
        server_p3    = precision_at_k(activities, q, 3)
        server_cmr   = category_match_rate(activities, q)

        # Client re-ranked order
        reranked = sorted(
            activities,
            key=lambda a: client_score(a, query_tokens, max_reviews),
            reverse=True,
        )
        client_ndcg5 = ndcg(reranked, q)
        client_p3    = precision_at_k(reranked, q, 3)
        client_cmr   = category_match_rate(reranked, q)

        results.append({
            "query":        q,
            "activities":   activities,
            "latency_ms":   log.get("latency_ms", 0),
            "server_ndcg5": server_ndcg5,
            "server_p3":    server_p3,
            "server_cmr":   server_cmr,
            "client_ndcg5": client_ndcg5,
            "client_p3":    client_p3,
            "client_cmr":   client_cmr,
        })

    # ── Report ────────────────────────────────────────────────────────────────
    valid = [r for r in results if "activities" in r and r["activities"]]

    def mean(vals): return round(sum(vals) / len(vals), 4) if vals else 0.0

    report = {
        "run_id":            run_id,
        "timestamp":         datetime.now(timezone.utc).isoformat(),
        "server_url":        base_url,
        "provider":          provider,
        "query_count":       len(GOLDEN_QUERIES),
        "successful_queries": len(valid),
        "avg_latency_ms":    mean([r["latency_ms"] for r in valid]),
        "server_order": {
            "avg_ndcg5": mean([r["server_ndcg5"] for r in valid]),
            "avg_p3":    mean([r["server_p3"]    for r in valid]),
            "avg_cmr":   mean([r["server_cmr"]   for r in valid]),
        },
        "client_rerank": {
            "avg_ndcg5": mean([r["client_ndcg5"] for r in valid]),
            "avg_p3":    mean([r["client_p3"]    for r in valid]),
            "avg_cmr":   mean([r["client_cmr"]   for r in valid]),
        },
        "per_query": [
            {
                "id":            r["query"]["id"],
                "text":          r["query"]["text"],
                "result_count":  len(r["activities"]),
                "latency_ms":    r.get("latency_ms", 0),
                "server_ndcg5":  r.get("server_ndcg5", 0),
                "client_ndcg5":  r.get("client_ndcg5", 0),
                "ndcg_delta":    round(r.get("client_ndcg5", 0) - r.get("server_ndcg5", 0), 4),
                "server_p3":     r.get("server_p3", 0),
                "client_p3":     r.get("client_p3", 0),
            }
            for r in valid
        ],
    }

    report_path = RES_DIR / f"places_{run_id}.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    # ── Print summary ─────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print(f"  RESULTS  ({len(valid)}/{len(GOLDEN_QUERIES)} queries succeeded)")
    print(f"{'='*60}")
    print(f"\n  {'Metric':<25}  {'Server order':>12}  {'Client rerank':>13}  {'Delta':>8}")
    print(f"  {'-'*25}  {'-'*12}  {'-'*13}  {'-'*8}")
    s, c = report["server_order"], report["client_rerank"]
    for label, sk, ck in [("NDCG@5", "avg_ndcg5", "avg_ndcg5"),
                           ("Precision@3", "avg_p3", "avg_p3"),
                           ("Category match rate", "avg_cmr", "avg_cmr")]:
        delta = round(c[ck] - s[sk], 4)
        sign  = "+" if delta >= 0 else ""
        print(f"  {label:<25}  {s[sk]:>12.4f}  {c[ck]:>13.4f}  {sign}{delta:>7.4f}")

    print(f"\n  Avg latency  : {report['avg_latency_ms']:.0f} ms")
    print(f"\n  Per-query breakdown:")
    print(f"  {'ID':<5}  {'Server NDCG5':>12}  {'Client NDCG5':>12}  {'Delta':>8}  {'Text'}")
    print(f"  {'-'*5}  {'-'*12}  {'-'*12}  {'-'*8}  {'-'*30}")
    for pq in report["per_query"]:
        sign = "+" if pq["ndcg_delta"] >= 0 else ""
        print(f"  {pq['id']:<5}  {pq['server_ndcg5']:>12.4f}  {pq['client_ndcg5']:>12.4f}  "
              f"{sign}{pq['ndcg_delta']:>7.4f}  {pq['text'][:40]}")

    print(f"\n  Full logs : experiments/logs/places/{run_id}/")
    print(f"  Report    : experiments/results/places_{run_id}.json\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PULSE — Google Places benchmark")
    parser.add_argument("--base-url",  default="http://localhost:8787",
                        help="Base URL of the running Rust server")
    parser.add_argument("--provider",  default="local",
                        choices=["local", "gemini", "openrouter", "huggingface"],
                        help="LLM provider for summary (default: local)")
    parser.add_argument("--dry-run",   action="store_true",
                        help="Load cached logs instead of hitting the API")
    args = parser.parse_args()
    run(args.base_url, args.dry_run, args.provider)
