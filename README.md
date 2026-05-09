PULSE

Social activity discovery and voice-curated recommendations.

> Live at [pulse-production-62b2.up.railway.app](https://pulse-production-62b2.up.railway.app)

PULSE is a PWA that curates nearby restaurants, nightlife, and activities using the Google Places API, Yelp and Gemini through API and Finetunned Gemma 4 E2B as default AI
. Ask it anything — *"best rooftop bars near me"* — and get smart, distance-aware recommendations with one-tap navigation.


## Features

- **Live Search** — Uses Google Places and Yelp API to fetch real-world venue data.
- **Venue Summaries** — Generates short blurbs for search results.
- **Proximity Ranking** — Distance computed server-side using Haversine formula.
- **Filters** — Presets for food and nightlife plus custom queries.
- **Navigation** — Deep links to Google Maps and Waze.
- **Social Graph** — Follow users and manage friend requests.
- **Voice Queries** — Natural language activity search.

---

## Tech Stack

| Layer | Tech |
|-------|------|
| **Frontend** | Flutter (Dart) — PWA, Material 3 |
| **Backend** | Rust (Axum) — serves API + static PWA |
| **AI** | Gemini 2.0 Flash / Gemma 4-e2b — summaries & intent parsing |
| **Places** | Google Places API + Yelp — live venue data |
| **Infra** | Railway (Docker) — single-container deploy |
| **Database** | PostgreSQL (Railway managed) |
| **Cache** | Redis (Railway managed) |

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   Railway                        │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │         Rust / Axum Server                 │  │
│  │                                            │  │
│  │  GET /           → Flutter PWA (static/)   │  │
│  │  GET /api/health → Health check            │  │
│  │  GET /api/feed   → Google Places + AI      │  │
│  │  POST /api/recommend → AI agent         │  │
│  │  GET /api/network    → Social graph        │  │
│  │  GET /api/trending   → Explore             │  │
│  └────────────────────────────────────────────┘  │
│         │                    │                    │
│    ┌────┴────┐         ┌────┴────┐               │
│    │ Postgres│         │  Redis  │               │
│    └─────────┘         └─────────┘               │
└──────────────────────────────────────────────────┘
         │                    │
   ┌─────┴─────┐       ┌─────┴─────┐
   │  Google   │       │  Gemini   │
   │ Places API│       │  2.0 Flash│
   └───────────┘       └───────────┘
```

---

## Quick Start

### Prerequisites

- [Rust](https://rustup.rs/) 1.85+
- [Flutter](https://docs.flutter.dev/get-started/install) 3.27+
- Google Cloud API key with **Places API (New)** enabled

### Local Development

1. **Backend (Rust)**
   Handles API logic, distance ranking, and AI provider dispatch.
   ```bash
   cd rust_core
   cargo run --bin recommendation_api
   ```

2. **Frontend (Flutter)**
   The mobile/web PWA interface.
   ```bash
   cd flutter_app
   flutter run -d chrome
   ```

3. **Evaluation Dashboard (Streamlit)**
   For analyzing NDCG, latency, and re-ranker signal ablation.
   ```bash
   streamlit run scripts/dashboard.py
   ```
   If you need to refresh the results after changing ranking weights, run:
   ```bash
   python scripts/eval_advanced.py
   ```

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GOOGLE_PLACES_API_KEY` | ✅ | — | Google Cloud key with Places API (New) enabled |
| `GEMINI_API_KEY` | ✅ | — | Gemini API key for AI summaries |
| `PULSE_AGENT_PROVIDER` | — | `local` | AI provider: `local`, `openrouter`, `huggingface`, `gemini` |
| `PULSE_API_PORT` | — | `8787` | Server port (Railway injects `PORT` automatically) |
| `PULSE_DB_PATH` | — | `pulse_v1.sqlite` | SQLite database path |
| `DATABASE_URL` | — | — | PostgreSQL connection string (auto-injected by Railway) |
| `REDIS_URL` | — | — | Redis connection string (auto-injected by Railway) |

---

## Deploy to Railway

1. **Fork & connect** — Link [github.com/MouhamedN96/PULSE](https://github.com/MouhamedN96/PULSE) to a Railway project
2. **Add databases** — Click **+ New** → add **PostgreSQL** and **Redis** services
3. **Set variables** — In the PULSE service → Variables tab:
   ```
   GOOGLE_PLACES_API_KEY=your_key
   GEMINI_API_KEY=your_key
   PULSE_AGENT_PROVIDER=gemini
   ```
4. **Generate domain** — Settings → Networking → Generate Domain
5. **Done** — Railway auto-builds on push using the 3-stage Dockerfile

The Dockerfile handles everything:
- **Stage 1**: Builds Flutter web app (`flutter build web`)
- **Stage 2**: Compiles Rust binary (`cargo build --release`)
- **Stage 3**: Slim Debian runtime with both artifacts

---

## Project Structure

```
PULSE/
├── rust_core/                  # Rust backend
│   ├── src/
│   │   ├── lib.rs              # Core library (models, engine, social)
│   │   └── bin/
│   │       └── recommendation_api.rs  # Axum HTTP server
│   └── Cargo.toml
│
├── flutter_app/                # Flutter PWA
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── core/theme/         # Material 3 theme
│   │   ├── data/               # Repository + models
│   │   └── presentation/
│   │       └── screens/        # Feed, Explore, Network, Profile
│   ├── web/                    # PWA manifest + index.html
│   └── pubspec.yaml
│
├── Dockerfile                  # 3-stage build (Flutter + Rust + runtime)
├── railway.toml                # Railway deployment config
├── .dockerignore
└── .env                        # Local environment config (not committed)
```

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check → `ok` |
| `GET` | `/api/feed?lat=40.7&lng=-74.0&query=bars` | Live venue feed (Google Places + distance) |
| `POST` | `/api/recommend` | Voice/text query → AI-curated results |
| `GET` | `/api/trending?category=food` | Trending activities by category |
| `GET` | `/api/network` | Social network (following, discover, requests) |
| `POST` | `/api/users/follow` | Follow/unfollow a user |
| `POST` | `/api/places/search` | Direct Google Places search |

---

## Contributing/Inspiring

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a PR

---

## License

MIT

---

Built with Flutter and Rust
