# Feed & Recommendation System — Analysis, Benchmarking & Evaluation

## 1. How the System Currently Works

### Architecture in one sentence
The server fetches places (Google Places API → SQLite mock fallback), optionally rewrites the summary via an LLM, then returns a flat ranked list; the Flutter client re-scores every item locally and groups them into geo-clusters.

### Data flow

```
User query (voice / text)
       │
       ▼
POST /api/recommend  (Rust · recommendation_api.rs)
       │
       ├─ GOOGLE_PLACES_API_KEY set + lat/lng present?
       │       Yes → Google Places Text Search
       │       No  → Pulse-Core in-memory mock (4 hardcoded venues)
       │
       ├─ LLM provider configured? (OpenRouter / HuggingFace / Gemini / local)
       │       Yes → LLM-generated natural-language summary
       │       No  → rule-based template summary (agent.rs)
       │
       ▼
AgentResponse { summary, activities[], filters[] }
       │
       ▼
Flutter DiscoverWorldController._deriveWorld()
       │  client-side composite score → re-rank → cluster → map overlays
       ▼
DiscoverWorldScreen
```

### Server-side retrieval (two paths)

| Path | Trigger | Ranking |
|------|---------|---------|
| **Google Places** | `GOOGLE_PLACES_API_KEY` env var set, lat/lng in request | Google's own relevance score (opaque) |
| **Mock / SQLite** | No API key or Places returns 0 results | Sort by `rating` DESC, take top 10 |

The query string is forwarded verbatim to Google Places — no pre-processing or intent extraction happens before the Places call.

`parse_query_intent()` (keyword matching in `agent.rs`) only runs for the mock path.

### Client-side scoring weights

Every activity in the local catalog is scored 0–1 before display:

| Signal | Weight | How it's computed |
|--------|--------|-------------------|
| Rating | 24 % | `activity.rating / 5.0` |
| Query affinity | 14 % | Fraction of query tokens found in name + description + tags |
| Open now | 14 % | Binary: `isOpen` |
| Saved by user | 14 % | User's in-session save history |
| Review count | 12 % | `reviewCount / max(reviewCount in catalog)` |
| Preferred category | 11 % | Inferred from feed, trending, and followed users |
| Preferred tags | 8 % | Inferred from trending tags and saved items |
| Distance | 7 % | `1 / (1 + km)` — parsed from string like `"0.8 km"` |
| Network affinity | 6 % | Category / tag overlap with people you follow |

### Known gaps (honest baseline)

- **No server-side geo-distance ranking** — `GeoLocation` is passed to `find_activities` but the parameter is ignored (`_location`, underscore prefix).
- **Trending = insertion order**, not real engagement signals.
- **Personalization is session-only** — preferred categories and tags are rebuilt from scratch on every load; nothing is written back to the API.
- **Coordinate mismatch** — mock data is hardcoded to Shanghai; Flutter client defaults to New York (`40.7128, -74.0060`).
- **Intent parser is keyword-only** — no fuzzy matching, no embeddings, no synonym expansion.

---

## 2. What to Benchmark

Benchmarking a recommender has two orthogonal concerns:

| Concern | Question |
|---------|----------|
| **Retrieval quality** | Did the right places come back at all? |
| **Ranking quality** | Are the best places at the top? |
| **Latency** | How fast does a user get results? |
| **Personalization lift** | Does knowing the user's history improve results? |
| **Fallback resilience** | Does quality degrade gracefully when the LLM or Places API is unavailable? |

---

## 3. Metrics

### 3.1 Offline retrieval & ranking metrics

These apply to any dataset where you have a ground-truth relevance label per (query, place) pair.

| Metric | Formula | Good for |
|--------|---------|----------|
| **Precision@K** | relevant hits in top K / K | Are the top K results all good? |
| **Recall@K** | relevant hits in top K / total relevant | Did we surface all good places? |
| **NDCG@K** | normalized discounted cumulative gain | Does rank order match quality? (penalizes burying a great place at position 5 vs 1) |
| **MRR** | mean reciprocal rank of first hit | How quickly does the user see the first good result? |
| **Hit Rate@K** | fraction of queries where at least one relevant result is in top K | Is the system useful at all? |

**NDCG@5 is the primary metric to optimize** — it's position-sensitive, which matters for a mobile UI where only 3–5 cards are visible without scrolling.

### 3.2 Online / user-behaviour metrics

| Metric | Proxy for |
|--------|-----------|
| **Save rate** | `saves / impressions` — user found it worth bookmarking |
| **Click-through rate (CTR)** | `taps on card / cards shown` |
| **Query refinement rate** | User submitted a second query after first results — first result was unsatisfying |
| **Session depth** | How many cards the user scrolled through before stopping |
| **Return rate** | Did the user come back to the app within 7 days? |

### 3.3 Latency

| Percentile | Target | Notes |
|------------|--------|-------|
| p50 | < 400 ms | Perceived as instant on mobile |
| p95 | < 1 500 ms | Acceptable with a skeleton loader |
| p99 | < 3 000 ms | Hard ceiling before users bounce |

Measure end-to-end (Flutter `processVoiceQuery` call → first card rendered), not just server response time.

### 3.4 Personalization lift

Compute NDCG@5 for two conditions and compare:

- **Cold** — no prior session history (first open)
- **Warm** — user has saved 3+ activities and followed 2+ users

A positive delta confirms the personalization signals (weights for saved, preferred category, network affinity) are helping.

---

## 4. Evaluation Datasets

### Option A — Curated golden set (cheapest to start)

1. Pick 20–30 representative queries (see list below).
2. For each query, run the system against a fixed location and collect the top 10 results.
3. Have 2–3 raters label each result as `relevant (2)`, `marginal (1)`, or `irrelevant (0)`.
4. Compute NDCG@5 and Precision@3.

**Seed query list (covers the intent parser's vocabulary):**

```
"best tapas near me"
"Italian dinner tonight"
"yoga class tomorrow morning"
"craft beer bar"
"brunch this weekend"
"contemporary art museum"
"hidden gem restaurant"
"coffee shop to work from"
"rooftop bar"
"japanese ramen"
"something fun for two"
"late night food"
"wellness spa downtown"
"cheap eats"
"french bakery"
```

### Option B — Yelp Open Dataset (public, free)

- 150k+ businesses across multiple cities with review counts, ratings, categories, and coordinates.
- Map Yelp categories to `ActivityCategory` (Food → Food, Nightlife → Nightlife, etc.).
- Generate synthetic queries from business names + categories and use rating as a proxy for ground-truth relevance.
- Gives scale to compute statistically significant NDCG.
- Link: [https://www.yelp.com/dataset](https://www.yelp.com/dataset)

### Option C — Google Places shadow log

For live production traffic: log every Places API response alongside the final client-side ranking. If a place was in the Places response but ranked below position 5 and was never saved, flag it as a potential ranking error.

---

## 5. Baselines to Compare Against

The goal is not just an absolute score — you need a baseline to know if the system is better than naive alternatives.

| Baseline | Description | Expected NDCG@5 |
|----------|-------------|-----------------|
| **Random** | Shuffle the Places API results | ~0.30–0.40 |
| **Rating-only** | Sort by rating DESC (what the mock path does today) | ~0.50–0.60 |
| **Review-count-only** | Sort by review count DESC | ~0.45–0.55 |
| **Google Places default** | Trust Google's returned order as-is | ~0.60–0.70 (strong baseline) |
| **Current system** | Client-side weighted scorer on top of Places | Measure to establish |
| **BM25 on place text** | Classic IR: rank by BM25 score of query against name + description + tags | ~0.60–0.65 |
| **Embedding similarity** | Embed query and place descriptions with a small model (e.g. `all-MiniLM-L6`), rank by cosine similarity | ~0.65–0.75 |

**The current system needs to beat "Google Places default order" to justify client-side re-ranking.** If it doesn't, the 9-signal scorer may be adding noise rather than signal.

---

## 6. How to Run a Benchmark (Step-by-Step)

### Step 1 — Freeze a snapshot

Create a deterministic test fixture so results are reproducible:

```dart
// flutter_app/test/bench/recommendation_bench.dart
final fixture = BenchFixture.load('test/bench/fixtures/golden_queries.json');
// Each entry: { query, lat, lng, expectedTopIds: [...] }
```

Or on the Rust side, seed the SQLite store from a fixed JSON dump before each test run.

### Step 2 — Run queries

```bash
# Against the live mock (no Places API key)
for query in "tapas" "yoga" "craft beer" "japanese ramen"; do
  curl -s -X POST http://localhost:8787/api/recommend \
    -H 'Content-Type: application/json' \
    -d "{\"query\":\"$query\",\"lat\":40.7128,\"lng\":-74.0060}" \
    | jq '[.activities[] | {id, name, rating}]'
done
```

### Step 3 — Compute NDCG@5

```python
# scripts/eval_ndcg.py
import json, math

def dcg(relevances, k=5):
    return sum(
        rel / math.log2(i + 2)
        for i, rel in enumerate(relevances[:k])
    )

def ndcg(result_ids, ground_truth, k=5):
    relevances = [ground_truth.get(rid, 0) for rid in result_ids]
    ideal = sorted(ground_truth.values(), reverse=True)
    idcg = dcg(ideal, k)
    return dcg(relevances, k) / idcg if idcg > 0 else 0.0

# Example
ground_truth = {"act-1": 2, "act-3": 2, "act-2": 1, "act-4": 0}
result_ids   = ["act-1", "act-4", "act-3", "act-2", "act-5"]
print(f"NDCG@5 = {ndcg(result_ids, ground_truth):.3f}")
```

### Step 4 — Latency profile

```bash
# p50/p95/p99 with hey (HTTP load tester)
hey -n 200 -c 10 -m POST \
  -H 'Content-Type: application/json' \
  -d '{"query":"brunch","lat":40.7128,"lng":-74.0060}' \
  http://localhost:8787/api/recommend
```

### Step 5 — Compare scorer weights

To test whether a weight change improves NDCG, treat each weight as a hyperparameter and do a grid search over the golden set:

```python
from itertools import product

weight_candidates = {
    "rating":    [0.20, 0.24, 0.30],
    "query":     [0.10, 0.14, 0.20],
    "open_now":  [0.10, 0.14],
}
# Evaluate NDCG@5 for each combination and report the best config
```

---

## 7. Improvement Hypotheses (prioritized by effort vs. expected lift)

| Priority | Change | Effort | Expected NDCG lift |
|----------|--------|--------|--------------------|
| 1 | **Fix the geo-distance bug** — actually use `GeoLocation` in `find_activities` | Low (1 day) | +0.05–0.10 |
| 2 | **Trust Google Places order** — don't re-rank Places results, only re-rank mock fallback | Low (1 day) | +0.05 |
| 3 | **Persist personalization** — write preferred categories to SQLite between sessions | Medium (2–3 days) | +0.05–0.08 |
| 4 | **Synonym expansion in intent parser** — add `"bistro"` → French, `"izakaya"` → Japanese | Low (half day) | +0.03–0.05 |
| 5 | **Real trending signal** — track save/click counts in SQLite instead of insertion order | Medium (3 days) | +0.04–0.07 |
| 6 | **Embedding-based retrieval** — replace keyword matcher with `all-MiniLM-L6` embeddings on the Rust side | High (1–2 weeks) | +0.08–0.15 |
| 7 | **LLM re-ranking** — send top-20 candidates to Gemini Flash with user context, ask it to reorder | High (1 week) | +0.10–0.20 (but latency cost) |

---

## 8. Evaluation Checklist

Before declaring any change an improvement, verify all of the following:

- [ ] NDCG@5 on the golden query set improved vs. the previous baseline
- [ ] No regression on Precision@3 (top 3 results didn't get worse)
- [ ] p95 latency stayed under 1 500 ms
- [ ] Mock fallback path still returns sensible results (no Places API key test)
- [ ] LLM-off path still returns sensible summaries
- [ ] Flutter unit tests pass (`flutter test`)
- [ ] Rust unit tests pass (`cargo test -p stroll_core`)
