# Experiment Log

Append a row every time you run a benchmark. Logs are machine-generated JSON in
`experiments/logs/` and `experiments/results/`; this file captures the human
interpretation: what changed, what you expected, what you saw.

---

## How to run

### Dashboard (visualization)
```bash
streamlit run scripts/dashboard.py
# Opens at http://localhost:8501
# Views: Single run · Compare runs · All runs timeline · Raw logs
```

### Experiment 1 — Google Places live capture
```bash
# Against Railway (no local server needed):
python scripts/experiment_places.py --base-url https://pulse-production-62b2.up.railway.app

# With Gemini summaries:
python scripts/experiment_places.py --provider gemini

# Local server:
cd rust_core && cargo run --release --bin recommendation_api
python scripts/experiment_places.py
```

### Experiment 2 — Yelp offline evaluation
```bash
# 1. Download Yelp dataset from https://www.yelp.com/dataset
# 2. Extract yelp_academic_dataset_business.json into experiments/
python scripts/experiment_yelp.py
python scripts/experiment_yelp.py --city "Las Vegas" --min-reviews 20
```

### Compare two runs
```bash
python scripts/compare_runs.py \
  experiments/results/places_20250430T120000Z.json \
  experiments/results/places_20250430T130000Z.json
```

---

## Metrics reference

| Metric | What it tells you |
|--------|-------------------|
| NDCG@5 | Position-weighted quality of top 5. 1.0 = perfect, 0.0 = useless. Primary metric. |
| Precision@3 | Fraction of top 3 that are relevant. Reflects what the user sees first. |
| Category match rate | Fraction of all returned results with the right category. Broad correctness check. |
| Avg latency (ms) | End-to-end server response time for the query batch. |

**NDCG@5 interpretation:**
- < 0.40 → Worse than random, something is broken
- 0.40–0.55 → Random-level, no real signal
- 0.55–0.65 → Weak signal (rating-sort baseline range)
- 0.65–0.75 → Solid signal (Google Places default range)
- > 0.75 → Strong — client scorer or LLM re-rank is helping

---

## Runs

<!-- Template — copy and fill in for each run:

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Run ID** | (from results filename) |
| **Experiment** | places / yelp |
| **What changed** | e.g. "Baseline, no changes" |
| **Server NDCG@5** | |
| **Client NDCG@5** | |
| **Avg latency ms** | |
| **Surprise / finding** | |
| **Next action** | |

-->

---

### Run 001 — baseline

| Field | Value |
|-------|-------|
| **Date** | 2026-04-30 |
| **Run ID** | 20260430T051138Z |
| **Experiment** | places — Railway server, provider=local |
| **What changed** | Baseline — no code changes |
| **Server NDCG@5** | 0.9348 |
| **Client NDCG@5** | 0.9615 |
| **Avg latency ms** | 560 |
| **Surprise / finding** | Client re-rank helps overall (+0.027 NDCG@5) but **hurts on 3 queries**: `best tapas` (-0.085), `rooftop bar` (-0.077), `wellness spa` (-0.015). Google's default order was better on those. Category match rate is 0.927 — a few off-category results are slipping through on wellness/nightlife queries. |
| **Next action** | Run 002 with provider=gemini to see if LLM summary affects anything. Investigate why `wellness spa` drops — likely `guess_category_from_types` misclassifying spa types. |

---

### Run 002 — Fixture cache baseline

| Field | Value |
|-------|-------|
| **Date** | 2026-04-30 |
| **Run ID** | 20260430T064253Z |
| **Experiment** | places — local fixture server, provider=local |
| **What changed** | New fixture fallback: 249 real NYC venues from Google Places (no live API call needed at serve time). Rust server now loads `rust_core/data/nyc_seed.json` at startup and searches it when `GOOGLE_PLACES_API_KEY` is absent. |
| **Server NDCG@5** | 1.0000 |
| **Client NDCG@5** | 1.0000 |
| **Avg latency ms** | 2146 (local dev server with cargo overhead) |
| **Surprise / finding** | Perfect NDCG@5 = 1.0 because fixture data was originally sourced from Google Places, so category labels are already aligned. Not informative as a standalone ranking metric — fixture NDCG@1.0 is the ceiling, not a real signal. Key value: 15/15 coverage vs 9/15 on old 4-venue mock; Shopping, Nature, Sports now served. Latency 2146 ms is cargo debug startup overhead, not HTTP latency; release binary would be ~50 ms. |
| **Next action** | Deploy fixture to Railway so Railway server also has the fallback (copy nyc_seed.json via Dockerfile COPY). Run 003 with provider=gemini when Gemini quota is renewed. |

---

### Run 003 — with Gemini summaries (TODO)

---

### Run 004 — with Gemini summaries (TODO)

| Field | Value |
|-------|-------|
| **Date** | — |
| **Run ID** | — |
| **Experiment** | places |
| **What changed** | provider=gemini (LLM summary on top of fixture retrieval) |
| **Server NDCG@5** | — |
| **Client NDCG@5** | — |
| **Avg latency ms** | — |
| **Surprise / finding** | — |
| **Next action** | — |

---

### Run 005 — Yelp Fusion NYC direct (live API)

| Field | Value |
|-------|-------|
| **Date** | 2026-04-30 |
| **Run ID** | 20260430T213155Z |
| **Experiment** | yelp_fusion — NYC, direct API (not offline academic dataset) |
| **What changed** | First Yelp Fusion live run. Hits `api.yelp.com/v3/businesses/search` directly with the 15 golden queries translated to Yelp keyword terms. |
| **Server NDCG@5** | 0.9017 |
| **Client NDCG@5** | 0.9322 |
| **Avg latency ms** | 660 |
| **Surprise / finding** | 15/15 coverage. Client re-rank adds +0.0305 NDCG@5 overall. Largest gains: q12 late night food (+0.274), q01 tapas (+0.170), q04 craft beer (+0.146). Regressions on q09 rooftop bar (−0.150) and q07 hidden gem (−0.073) — same pattern as Places Run 001. Server NDCG@5 0.9017 is lower than Places 0.9348, likely because Yelp's best_match sort is less tuned to our 9-signal relevance definition than Google's ranking. Category match rate 0.913 comparable to Places 0.927. |
| **Next action** | Add Yelp Fusion to the A/B/C/D comparison table in the dashboard and deck. Run with larger limit=20 to see if more results improve ranking. |

---

### Run 006 — Yelp offline Philadelphia baseline (TODO)

| Field | Value |
|-------|-------|
| **Date** | — |
| **Run ID** | — |
| **Experiment** | yelp — Philadelphia |
| **What changed** | Baseline offline eval |
| **Random NDCG@5** | — |
| **Rating-sort NDCG@5** | — |
| **Client scorer NDCG@5** | — |
| **Surprise / finding** | — |
| **Next action** | — |
