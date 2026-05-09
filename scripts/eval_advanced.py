#!/usr/bin/env python3
"""
Advanced Evaluation — Three Meaningful Tests
============================================
Reads existing log files (no API calls) and runs:

  Test 1 — Cross-source head-to-head
    Places vs Yelp Fusion per query, 15 queries.
    Metrics: NDCG@5 per source, merged-pool NDCG@5,
             top-5 slot distribution by source.

  Test 2 — Re-ranker signal ablation
    Zero out each of 9 signals on Places data.
    Report NDCG@5 delta vs baseline.
    Cold-start signals (saved, prefTags, netAffinity) are always 0
    and are noted rather than ablated.

  Test 3 — Intra-list diversity (ILD)
    Pairwise category dissimilarity in top-5 per query per source.
    ILD = # diverse pairs / total pairs (10 for k=5).

Results saved to experiments/results/advanced_eval_<timestamp>.json
with "source": "advanced_eval" so the dashboard can detect them.

Usage:
  python scripts/eval_advanced.py
"""

import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ── Config ────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
LOG_DIR   = REPO_ROOT / "experiments" / "logs"
RES_DIR   = REPO_ROOT / "experiments" / "results"

# Use Railway live run (real data, not the fixture-inflated NDCG=1.0 run)
PLACES_RUN = "20260430T051138Z"
YELP_RUN   = "20260430T213155Z"

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

# Mirrors discover_world_controller.dart weights
WEIGHTS = {
    "rating":          0.24,
    "reviews":         0.12,
    "isOpen":          0.14,
    "saved":           0.14,   # always 0 at cold start
    "preferredCat":    0.11,
    "preferredTags":   0.08,   # always 0 at cold start
    "queryAffinity":   0.14,
    "distance":        0.07,
    "networkAffinity": 0.06,   # always 0 at cold start
}

COLD_START_SIGNALS = {"saved", "preferredTags", "networkAffinity"}

STOP_WORDS = {
    "near", "best", "good", "some", "this", "with", "from",
    "tonight", "tomorrow", "weekend", "morning", "downtown",
    "something", "class", "today",
}

# ── Normalization ─────────────────────────────────────────────────────────────

def normalize_places(act: dict) -> dict:
    return {
        "id":       act.get("id", ""),
        "name":     act.get("name", ""),
        "category": act.get("category", ""),
        "tags":     act.get("tags", []),
        "rating":   float(act.get("rating", 0.0)),
        "reviews":  int(act.get("review_count", 0)),
        "is_open":  bool(act.get("is_open", False)),
        "distance": act.get("distance", ""),
        "source":   "places",
    }

def normalize_yelp(act: dict) -> dict:
    return {
        "id":       act.get("id", ""),
        "name":     act.get("name", ""),
        "category": act.get("category", ""),
        "tags":     act.get("yelp_cats", []),
        "rating":   float(act.get("rating", 0.0)),
        "reviews":  int(act.get("review_count", 0)),
        "is_open":  not bool(act.get("is_closed", True)),  # Yelp inverts open/closed
        "distance": act.get("distance", ""),
        "source":   "yelp_fusion",
    }

# ── Signal scorers (mirror discover_world_controller.dart) ────────────────────

def sig_rating(act: dict) -> float:
    return max(0.0, min(1.0, act["rating"] / 5.0))

def sig_reviews(act: dict, max_reviews: int) -> float:
    return max(0.0, min(1.0, act["reviews"] / max(max_reviews, 1)))

def sig_is_open(act: dict) -> float:
    return 1.0 if act["is_open"] else 0.0

def sig_distance(act: dict) -> float:
    dist_str = act.get("distance", "")
    if not dist_str:
        return 0.5
    low = dist_str.lower()
    try:
        num_str = "".join(c if c.isdigit() or c == "." else " " for c in low).strip().split()[0]
        val = float(num_str)
    except Exception:
        return 0.5
    if "km" in low:
        val *= 0.621371
    return max(0.0, min(1.0, 1.0 / (1.0 + val)))

def sig_query_affinity(act: dict, query: str) -> float:
    tokens = [w for w in query.lower().split() if len(w) > 3 and w not in STOP_WORDS]
    if not tokens:
        return 0.5
    haystack = " ".join([
        act.get("name", ""),
        act.get("category", ""),
        " ".join(t if isinstance(t, str) else "" for t in act.get("tags", [])),
    ]).lower()
    hits = sum(1 for t in tokens if t in haystack)
    return max(0.0, min(1.0, hits / len(tokens)))

def compute_signals(act: dict, query: str, max_reviews: int) -> dict:
    return {
        "rating":          sig_rating(act),
        "reviews":         sig_reviews(act, max_reviews),
        "isOpen":          sig_is_open(act),
        "saved":           0.0,
        "preferredCat":    0.0,
        "preferredTags":   0.0,
        "queryAffinity":   sig_query_affinity(act, query),
        "distance":        sig_distance(act),
        "networkAffinity": 0.0,
    }

def score_from_signals(signals: dict, ablate: Optional[str] = None) -> float:
    total = 0.0
    for name, weight in WEIGHTS.items():
        val = 0.0 if name == ablate else signals.get(name, 0.0)
        total += val * weight
    return total

# ── NDCG ─────────────────────────────────────────────────────────────────────

def relevance_label(act: dict, expected_categories: list) -> int:
    cat_match = act["category"].lower() in [c.lower() for c in expected_categories]
    rating = act["rating"]
    if cat_match and rating >= 4.0:
        return 2
    if cat_match or rating >= 4.5:
        return 1
    return 0

def dcg(grades: list, k: int = 5) -> float:
    return sum(g / math.log2(i + 2) for i, g in enumerate(grades[:k]))

def ndcg_at_k(activities: list, expected_categories: list, k: int = 5) -> float:
    labels = [relevance_label(a, expected_categories) for a in activities]
    ideal  = sorted(labels, reverse=True)
    idcg   = dcg(ideal, k)
    return round(dcg(labels, k) / idcg, 4) if idcg > 0 else 0.0

# ── Log loading ───────────────────────────────────────────────────────────────

def load_log(source: str, run_id: str, qid: str) -> Optional[dict]:
    f = LOG_DIR / source / run_id / f"{qid}.json"
    if not f.exists():
        return None
    return json.loads(f.read_text(encoding="utf-8"))

# ── Test 1: Cross-source head-to-head ────────────────────────────────────────

def run_test1_cross_source() -> dict:
    print("\n=== Test 1: Cross-source head-to-head ===")

    per_query = []

    for q in GOLDEN_QUERIES:
        qid  = q["id"]
        plog = load_log("places",     PLACES_RUN, qid)
        ylog = load_log("yelp_fusion", YELP_RUN,  qid)

        if not plog or not ylog:
            print(f"  {qid}: SKIP (missing log)")
            continue

        p_acts_raw = plog.get("activities", [])
        y_acts_raw = ylog.get("activities", [])
        p_acts = [normalize_places(a) for a in p_acts_raw]
        y_acts = [normalize_yelp(a)   for a in y_acts_raw]

        def rerank(acts, max_rev):
            for a in acts:
                a["_score"] = score_from_signals(
                    compute_signals(a, q["text"], max_rev)
                )
            return sorted(acts, key=lambda x: x["_score"], reverse=True)

        max_rev_p = max((a["reviews"] for a in p_acts), default=1)
        max_rev_y = max((a["reviews"] for a in y_acts), default=1)

        p_ranked = rerank(p_acts, max_rev_p)
        y_ranked = rerank(y_acts, max_rev_y)

        p_ndcg = ndcg_at_k(p_ranked, q["expected_categories"])
        y_ndcg = ndcg_at_k(y_ranked, q["expected_categories"])

        # Merged pool — re-rank against shared max_reviews
        merged    = p_acts + y_acts
        max_rev_m = max((a["reviews"] for a in merged), default=1)
        m_ranked  = rerank(merged, max_rev_m)
        m_ndcg    = ndcg_at_k(m_ranked, q["expected_categories"])

        top5        = m_ranked[:5]
        p_in_top5   = sum(1 for a in top5 if a["source"] == "places")
        y_in_top5   = sum(1 for a in top5 if a["source"] == "yelp_fusion")
        winner      = ("places" if p_ndcg > y_ndcg
                       else ("yelp" if y_ndcg > p_ndcg else "tie"))

        per_query.append({
            "id":           qid,
            "text":         q["text"],
            "places_ndcg5": p_ndcg,
            "yelp_ndcg5":   y_ndcg,
            "merged_ndcg5": m_ndcg,
            "winner":       winner,
            "top5_places":  p_in_top5,
            "top5_yelp":    y_in_top5,
        })

        print(f"  {qid}: Places={p_ndcg:.4f}  Yelp={y_ndcg:.4f}  Merged={m_ndcg:.4f}  "
              f"top5=[P:{p_in_top5} Y:{y_in_top5}]  winner={winner}")

    n = len(per_query)
    avg_p  = round(sum(r["places_ndcg5"]  for r in per_query) / n, 4) if n else 0
    avg_y  = round(sum(r["yelp_ndcg5"]    for r in per_query) / n, 4) if n else 0
    avg_m  = round(sum(r["merged_ndcg5"]  for r in per_query) / n, 4) if n else 0
    p_wins = sum(1 for r in per_query if r["winner"] == "places")
    y_wins = sum(1 for r in per_query if r["winner"] == "yelp")
    ties   = sum(1 for r in per_query if r["winner"] == "tie")

    print(f"\n  avg Places={avg_p:.4f}  Yelp={avg_y:.4f}  Merged={avg_m:.4f}")
    print(f"  head-to-head: Places {p_wins}W / Yelp {y_wins}W / {ties}T")

    return {
        "avg_places_ndcg5": avg_p,
        "avg_yelp_ndcg5":   avg_y,
        "avg_merged_ndcg5": avg_m,
        "places_wins":      p_wins,
        "yelp_wins":        y_wins,
        "ties":             ties,
        "per_query":        per_query,
    }

# ── Test 2: Signal ablation ───────────────────────────────────────────────────

def run_test2_ablation() -> dict:
    print("\n=== Test 2: Re-ranker signal ablation (Places data) ===")

    # Pre-compute signals for all queries
    query_data = []
    for q in GOLDEN_QUERIES:
        plog = load_log("places", PLACES_RUN, q["id"])
        if not plog:
            continue
        acts = [normalize_places(a) for a in plog.get("activities", [])]
        max_rev = max((a["reviews"] for a in acts), default=1)
        for a in acts:
            a["_signals"] = compute_signals(a, q["text"], max_rev)
        query_data.append({"query": q, "acts": acts})

    def avg_ndcg(ablate: Optional[str]) -> float:
        total = 0.0
        for qd in query_data:
            ranked = sorted(
                qd["acts"],
                key=lambda a: score_from_signals(a["_signals"], ablate=ablate),
                reverse=True,
            )
            total += ndcg_at_k(ranked, qd["query"]["expected_categories"])
        return round(total / len(query_data), 4) if query_data else 0.0

    baseline = avg_ndcg(None)
    print(f"  Baseline NDCG@5 (full scorer): {baseline:.4f}")

    signals_out = []
    for signal, weight in WEIGHTS.items():
        if signal in COLD_START_SIGNALS:
            signals_out.append({
                "signal":     signal,
                "weight":     weight,
                "ndcg5":      baseline,
                "delta":      0.0,
                "cold_start": True,
                "note":       "always 0 at cold-start — ablation has no effect",
            })
            print(f"  {signal:20s} w={weight:.2f}  [cold-start, no effect]")
        else:
            ablated = avg_ndcg(signal)
            delta   = round(ablated - baseline, 4)
            tag     = "DROP" if delta < -0.001 else ("GAIN" if delta > 0.001 else "flat")
            signals_out.append({
                "signal":     signal,
                "weight":     weight,
                "ndcg5":      ablated,
                "delta":      delta,
                "cold_start": False,
            })
            print(f"  {signal:20s} w={weight:.2f}  NDCG@5={ablated:.4f}  delta={delta:+.4f}  [{tag}]")

    return {
        "baseline_ndcg5": baseline,
        "places_run":     PLACES_RUN,
        "signals":        signals_out,
    }

# ── Test 3: Intra-list diversity (ILD) ───────────────────────────────────────

def run_test3_ild() -> dict:
    print("\n=== Test 3: Intra-list diversity (ILD @5) ===")

    K       = 5
    N_PAIRS = K * (K - 1) // 2  # 10 pairs

    def ild_for_query(acts_raw, normalize_fn, query: dict) -> dict:
        acts = [normalize_fn(a) for a in acts_raw]
        max_rev = max((a["reviews"] for a in acts), default=1)
        for a in acts:
            a["_score"] = score_from_signals(compute_signals(a, query["text"], max_rev))
        top5 = sorted(acts, key=lambda x: x["_score"], reverse=True)[:K]
        cats = [a["category"].lower() for a in top5]
        diverse = sum(
            1 for i in range(len(cats))
              for j in range(i + 1, len(cats))
              if cats[i] != cats[j]
        )
        ild = round(diverse / N_PAIRS, 4) if N_PAIRS > 0 else 0.0
        dist: dict = {}
        for c in cats:
            dist[c] = dist.get(c, 0) + 1
        return {"ild": ild, "category_distribution": dist, "top5_categories": cats}

    places_rows = []
    yelp_rows   = []

    for q in GOLDEN_QUERIES:
        plog = load_log("places",     PLACES_RUN, q["id"])
        ylog = load_log("yelp_fusion", YELP_RUN,  q["id"])

        p_ild_data = ild_for_query(plog["activities"], normalize_places, q) if plog else None
        y_ild_data = ild_for_query(ylog["activities"], normalize_yelp,   q) if ylog else None

        if p_ild_data:
            places_rows.append({"id": q["id"], "text": q["text"], **p_ild_data})
        if y_ild_data:
            yelp_rows.append({"id": q["id"], "text": q["text"], **y_ild_data})

        p_str = f"{p_ild_data['ild']:.4f}" if p_ild_data else "N/A"
        y_str = f"{y_ild_data['ild']:.4f}" if y_ild_data else "N/A"
        print(f"  {q['id']}: Places ILD={p_str}  Yelp ILD={y_str}")

    avg_p = round(sum(r["ild"] for r in places_rows) / max(len(places_rows), 1), 4)
    avg_y = round(sum(r["ild"] for r in yelp_rows)   / max(len(yelp_rows),   1), 4)

    print(f"\n  avg Places ILD@5={avg_p:.4f}  avg Yelp ILD@5={avg_y:.4f}")
    print(f"  (0=all same category, 1=all different — higher means more diverse top-5)")

    return {
        "k":              K,
        "n_pairs":        N_PAIRS,
        "avg_ild_places": avg_p,
        "avg_ild_yelp":   avg_y,
        "places":         places_rows,
        "yelp":           yelp_rows,
    }

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    print("=" * 60)
    print("  PULSE Advanced Evaluation")
    print(f"  Run ID   : {run_id}")
    print(f"  Places   : {PLACES_RUN}  (Railway live, NDCG@5=0.9348)")
    print(f"  Yelp     : {YELP_RUN}  (Fusion live, NDCG@5=0.9017)")
    print("=" * 60)

    t1 = run_test1_cross_source()
    t2 = run_test2_ablation()
    t3 = run_test3_ild()

    result = {
        "run_id":             run_id,
        "source":             "advanced_eval",
        "timestamp":          datetime.now(timezone.utc).isoformat(),
        "places_run":         PLACES_RUN,
        "yelp_run":           YELP_RUN,
        "test1_cross_source": t1,
        "test2_ablation":     t2,
        "test3_ild":          t3,
    }

    RES_DIR.mkdir(parents=True, exist_ok=True)
    out = RES_DIR / f"advanced_eval_{run_id}.json"
    out.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(f"\n{'='*60}")
    print(f"  Done. Results -> {out.name}")
    print(f"  Open dashboard and select 'Advanced Eval' view.")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
