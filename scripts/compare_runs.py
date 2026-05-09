#!/usr/bin/env python3
"""
Compare two experiment result files side-by-side.

Usage:
  python scripts/compare_runs.py experiments/results/places_A.json experiments/results/places_B.json
  python scripts/compare_runs.py experiments/results/yelp_A.json  experiments/results/yelp_B.json
"""

import json
import sys
from pathlib import Path


def load(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def compare_places(a: dict, b: dict) -> None:
    print(f"\n{'='*70}")
    print(f"  COMPARISON — Google Places runs")
    print(f"  A: {a['run_id']}  provider={a.get('provider', '?')}")
    print(f"  B: {b['run_id']}  provider={b.get('provider', '?')}")
    print(f"{'='*70}\n")

    metrics = [
        ("Server NDCG@5",    "server_order",   "avg_ndcg5"),
        ("Server P@3",       "server_order",   "avg_p3"),
        ("Client NDCG@5",    "client_rerank",  "avg_ndcg5"),
        ("Client P@3",       "client_rerank",  "avg_p3"),
        ("Avg latency (ms)", "avg_latency_ms", None),
    ]

    print(f"  {'Metric':<25}  {'Run A':>10}  {'Run B':>10}  {'Delta (B-A)':>12}")
    print(f"  {'-'*25}  {'-'*10}  {'-'*10}  {'-'*12}")
    for label, key, subkey in metrics:
        va = a[key] if subkey is None else a[key][subkey]
        vb = b[key] if subkey is None else b[key][subkey]
        delta = round(vb - va, 4)
        sign  = "+" if delta >= 0 else ""
        print(f"  {label:<25}  {va:>10.4f}  {vb:>10.4f}  {sign}{delta:>11.4f}")

    # Per-query delta
    aq = {r["id"]: r for r in a.get("per_query", [])}
    bq = {r["id"]: r for r in b.get("per_query", [])}
    common = sorted(set(aq) & set(bq))
    if common:
        print(f"\n  Per-query client NDCG@5 delta (B - A):")
        print(f"  {'ID':<5}  {'A':>8}  {'B':>8}  {'Delta':>8}  {'Text'}")
        print(f"  {'-'*5}  {'-'*8}  {'-'*8}  {'-'*8}  {'-'*30}")
        for qid in common:
            va_n = aq[qid]["client_ndcg5"]
            vb_n = bq[qid]["client_ndcg5"]
            delta = round(vb_n - va_n, 4)
            sign  = "+" if delta >= 0 else ""
            print(f"  {qid:<5}  {va_n:>8.4f}  {vb_n:>8.4f}  {sign}{delta:>7.4f}  {aq[qid]['text'][:40]}")


def compare_yelp(a: dict, b: dict) -> None:
    print(f"\n{'='*70}")
    print(f"  COMPARISON — Yelp offline runs")
    print(f"  A: {a['run_id']}  city={a.get('city', '?')}")
    print(f"  B: {b['run_id']}  city={b.get('city', '?')}")
    print(f"{'='*70}\n")

    rankers = ["random", "rating", "reviews", "client"]
    print(f"  {'Ranker':<22}  {'A NDCG5':>9}  {'B NDCG5':>9}  {'Delta':>8}")
    print(f"  {'-'*22}  {'-'*9}  {'-'*9}  {'-'*8}")
    for ranker in rankers:
        va = a["summary"][ranker]["avg_ndcg5"]
        vb = b["summary"][ranker]["avg_ndcg5"]
        delta = round(vb - va, 4)
        sign  = "+" if delta >= 0 else ""
        print(f"  {ranker:<22}  {va:>9.4f}  {vb:>9.4f}  {sign}{delta:>7.4f}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python scripts/compare_runs.py <result_a.json> <result_b.json>")
        sys.exit(1)

    a = load(sys.argv[1])
    b = load(sys.argv[2])

    if "server_order" in a:
        compare_places(a, b)
    elif "summary" in a and "random" in a["summary"]:
        compare_yelp(a, b)
    else:
        print("Unknown result format")
        sys.exit(1)
