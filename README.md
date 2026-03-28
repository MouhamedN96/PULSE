# STROLL - Agentic Social Activity Curator

**Rust + Flutter** implementation of STROLL - a voice-powered social activity discovery app.

## V1 Scope Lock

V1 ships from this stack only (`rust_core + flutter_app`).

- Included: Feed, Voice Agent (voice/text query), Links, Explore, Profile (read-only + local toggles)
- Excluded: camera/image analysis, maps actions, push notifications, auth/backend sync, web parity

## Features

🎙️ **Voice Agent** - Natural language queries for activity discovery  
📰 **Personalized Feed** - Activity recommendations + social posts  
👥 **Social Network** - Follow friends and review requests  
🔎 **Explore** - Trending activities with category filters  
🤖 **AI-Powered** - Intent parsing and summary generation  

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter + Dart |
| Business Logic | Rust |
| FFI Bridge | Typed native bridge (`stroll_*` C ABI over Rust core) |
| State Management | Screen-local state + repository abstraction |
| UI Components | Material 3 |

## Quick Start

### Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Flutter
# https://docs.flutter.dev/get-started/install

# Clone repository
git clone https://github.com/yourusername/stroll.git
cd stroll

# Build Rust core
cd rust_core
cargo build --release

# Run Flutter app
cd ../flutter_app
flutter pub get
flutter run
```

### Optional Recommendation API

```bash
cd rust_core
cargo run --bin recommendation_api
```

Environment variables:
- `STROLL_API_PORT` (default: `8787`)
- `STROLL_DB_PATH` (default: `stroll_v1.sqlite`)
- `STROLL_AGENT_PROVIDER` (`local`, `openrouter`, `huggingface`, `gemini`; default: `local`)
- `OPENROUTER_API_KEY` / `OPENROUTER_MODEL` (default: `liquid/lfm-2.5-1.2b-instruct:free`)
- `HUGGINGFACE_API_KEY` / `HUGGINGFACE_MODEL` / `HUGGINGFACE_ENDPOINT`
- `GEMINI_API_KEY` / `GEMINI_MODEL` (default: `gemini-2.0-flash`) / `GEMINI_ENDPOINT`

Example call:

```bash
curl -X POST http://127.0.0.1:8787/api/recommend \
  -H "Content-Type: application/json" \
  -d '{"query":"Find Spanish dinner nearby","lat":31.23,"lng":121.47,"provider":"local"}'
```

To make Flutter Voice Agent call this API, run Flutter with:

```bash
flutter run --dart-define=STROLL_RECOMMEND_API_BASE_URL=http://127.0.0.1:8787
```

Voice Agent now shows a backend badge (`API` or `FFI`) so you can verify the active path during local testing.

## Architecture

```
┌─────────────────┐     FFI      ┌─────────────────┐
│  Flutter UI     │ ◄──────────► │   Rust Core     │
│  - Screens      │   (bridge)   │   - Models      │
│  - Widgets      │              │   - Agent       │
│  - State        │              │   - Engine      │
└─────────────────┘              └─────────────────┘
```

## Screenshots

| Feed | Voice Agent | Results |
|------|-------------|---------|
| ![Feed](docs/screens/feed.png) | ![Agent](docs/screens/agent.png) | ![Results](docs/screens/results.png) |

## Project Structure

```
stroll/
├── rust_core/              # Rust business logic
│   ├── src/
│   │   ├── lib.rs         # Main library
│   │   ├── models.rs      # Data structures
│   │   ├── agent.rs       # Voice query processing
│   │   ├── recommendations.rs
│   │   └── social.rs
│   └── Cargo.toml
│
├── flutter_app/
│   ├── lib/
│   │   ├── bridge/        # FFI bridge
│   │   ├── presentation/  # UI screens
│   │   └── core/          # Theme, utils
│   └── pubspec.yaml
│
└── docs/
    └── ARCHITECTURE.md
```

## Key Features

### Voice-to-Activity Flow

1. User speaks: *"Find Italian brunch nearby"*
2. Flutter captures audio → Speech-to-text
3. Dart calls Rust via FFI
4. Rust parses intent: `{ category: Food, subcategory: Italian }`
5. Rust queries activities, applies filters
6. Rust generates AI summary
7. Flutter displays results with cards

### Social Features

- **My Network** - See who you follow
- **Discover** - Find people with similar interests
- **Requests** - Accept/decline connection requests
- **Feed** - See what your network is up to

## API Reference

### Rust Core Functions

```rust
// Initialize
pub fn create_stroll_core() -> StrollCore;
pub fn init_with_mock_data(&self);

// Voice queries
pub async fn process_voice_query(
    &self,
    query: String,
    location: Option<GeoLocation>,
) -> Result<AgentResponse, StrollError>;

// Feed
pub async fn get_personalized_feed(&self) -> Result<FeedResponse, StrollError>;

// Social
pub async fn get_network(&self) -> Result<NetworkResponse, StrollError>;
pub async fn follow_user(&self, user_id: String) -> Result<(), StrollError>;
pub async fn get_trending(&self, category: Option<String>) -> Result<Vec<Activity>, StrollError>;
pub async fn save_activity(&self, activity_id: String) -> Result<(), StrollError>;
pub async fn get_saved_activities(&self) -> Result<Vec<Activity>, StrollError>;
```

### Native Bridge Exports

The Flutter app consumes the Rust core through typed envelope responses:

- `stroll_create_core`
- `stroll_init_mock_data`
- `stroll_process_voice_query`
- `stroll_get_personalized_feed`
- `stroll_get_network`
- `stroll_follow_user`
- `stroll_get_trending`
- `stroll_save_activity`
- `stroll_get_saved_activities`
- `stroll_free_string`

## Testing and Release Gates

### One-command local scripts

```bash
# Run full Rust + Flutter gates
./scripts/v1-gates.sh

# Install local Flutter SDK (if missing) and run Flutter gates
./scripts/flutter-gates-bootstrap.sh
```

```powershell
# Run full Rust + Flutter gates
powershell -ExecutionPolicy Bypass -File .\scripts\v1-gates.ps1

# Install local Flutter SDK (if missing) and run Flutter gates
powershell -ExecutionPolicy Bypass -File .\scripts\flutter-gates-bootstrap.ps1
```

### Rust

```bash
cargo fmt --check
cargo clippy -- -D warnings
cargo test
```

### Flutter

```bash
flutter analyze
flutter test
flutter test integration_test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `cargo test && flutter test`
5. Submit a pull request

## License

MIT License - see LICENSE file

---

Built with 💜 using Rust + Flutter
