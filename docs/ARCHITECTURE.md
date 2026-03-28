# STROLL Architecture - Rust + Flutter

> V1 implementation note: Flutter consumes Rust through typed native bridge exports (`stroll_*`) and a repository layer in `flutter_app/lib/data`.

## Overview

STROLL is built with a **Rust core** for business logic and a **Flutter frontend** for the UI, connected via FFI (Foreign Function Interface).

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER LAYER                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Screens   │  │   Widgets   │  │   Bridge    │             │
│  │             │  │             │  │   (FFI)     │             │
│  │ - Feed      │  │ - Cards     │  │             │             │
│  │ - Links     │  │ - Buttons   │  │ Dart ↔ Rust │             │
│  │ - Explore   │  │ - Nav       │  │             │             │
│  │ - Profile   │  │             │  │             │             │
│  └─────────────┘  └─────────────┘  └──────┬──────┘             │
│                                           │                     │
│  ┌────────────────────────────────────────┘                     │
│  │  Plugins: Speech                                              │
│  └─────────────────────────────────────────────────────────────┘
├─────────────────────────────────────────────────────────────────┤
│                         FFI BRIDGE                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Typed native bridge exports (`stroll_*`)                    ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                         RUST CORE                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Models    │  │   Agent     │  │Recommendations            │
│  │             │  │             │  │             │             │
│  │ - Activity  │  │ - Query     │  │ - Engine    │             │
│  │ - User      │  │   Parser    │  │ - Filters   │             │
│  │ - Post      │  │ - Summary   │  │ - Trending  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌─────────────┐  ┌─────────────┐                              │
│  │   Social    │  │   External  │                              │
│  │   Graph     │  │   APIs      │                              │
│  │             │  │             │                              │
│  │ - Network   │  │ - Maps      │                              │
│  │ - Following │  │ - Places    │                              │
│  │ - Requests  │  │ - Reviews   │                              │
│  └─────────────┘  └─────────────┘                              │
└─────────────────────────────────────────────────────────────────┘
```

## Why Rust + Flutter?

### Rust Core Benefits
- **Performance**: Zero-cost abstractions, memory safety without GC
- **Concurrency**: Fearless parallelism with ownership model
- **FFI**: Seamless integration with Flutter via Dart FFI
- **Type Safety**: Compile-time guarantees for business logic
- **Ecosystem**: Rich libraries for async, networking, serialization

### Flutter Frontend Benefits
- **Cross-platform**: iOS, Android (desktop optional)
- **Hot Reload**: Fast development iteration
- **Rich UI**: Beautiful, customizable widgets
- **Native Plugins**: Access to speech
- **Dart FFI**: Direct communication with Rust

## Project Structure

```
stroll-rust-flutter/
├── rust_core/              # Rust business logic
│   ├── src/
│   │   ├── lib.rs         # Main library & FFI exports
│   │   ├── models.rs      # Data structures
│   │   ├── agent.rs       # Voice query processing
│   │   ├── recommendations.rs  # Recommendation engine
│   │   └── social.rs      # Social graph
│   └── Cargo.toml
│
├── flutter_app/           # Flutter UI
│   ├── lib/
│   │   ├── main.dart
│   │   ├── bridge/        # FFI bridge
│   │   ├── core/          # Theme, constants
│   │   ├── data/          # Repositories
│   │   └── presentation/  # UI screens & widgets
│   └── pubspec.yaml
│
└── docs/                  # Documentation
```

## FFI Bridge

The bridge uses typed native envelope responses over `dart:ffi`.

### Rust Exports
```rust
#[no_mangle]
pub extern "C" fn stroll_create_core() -> *mut StrollCore;

#[no_mangle]
pub extern "C" fn stroll_process_voice_query(...) -> *mut c_char;
```

### Dart Bindings
```dart
final result = await StrollBridge.instance.processVoiceQuery(
  query: "Find Italian brunch nearby",
);
```

## Data Flow

1. **User Input** → Flutter captures voice/text query
2. **FFI Call** → Dart calls Rust function
3. **Processing** → Rust parses query, fetches data, generates recommendations
4. **Response** → Rust returns structured data
5. **UI Update** → Flutter renders results

## Key Features

### Voice Agent
- Speech-to-text (Flutter `speech_to_text`)
- Query parsing (Rust NLP)
- Context-aware recommendations
- AI-generated summaries

### Activity Curation
- Location-based filtering
- Category/subcategory matching
- Personalization based on preferences
- Social context (network activity)

### Social Features
- Follow/unfollow users
- Network requests
- Activity feed
- Trending discovery

## Building

### Prerequisites
- Rust toolchain
- Flutter SDK
- Android SDK / Xcode

### Build Commands

```bash
# Build Rust library
cd rust_core
cargo build --release

# Build Flutter app
cd ../flutter_app
flutter pub get
flutter run
```

## Performance Considerations

- **Rust Core**: Single instance shared across Flutter
- **Async Operations**: Tokio runtime for non-blocking I/O
- **Caching**: LRU cache for frequently accessed data
- **Lazy Loading**: Images loaded on-demand
- **Debounce**: Voice input debounced for efficiency

## Future Enhancements

- [ ] Real API integration (Google Places, Yelp)
- [ ] ML-based recommendation ranking
- [ ] Offline mode with local database
- [ ] Push notifications
- [ ] Multi-language support
