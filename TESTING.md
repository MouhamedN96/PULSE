# Testing Plan (V1)

## One-command gates

```bash
# Full local gates (Rust + Flutter)
./scripts/v1-gates.sh

# Install local Flutter SDK (if missing) and run Flutter gates
./scripts/flutter-gates-bootstrap.sh
```

```powershell
# Full local gates (Rust + Flutter)
powershell -ExecutionPolicy Bypass -File .\scripts\v1-gates.ps1

# Install local Flutter SDK (if missing) and run Flutter gates
powershell -ExecutionPolicy Bypass -File .\scripts\flutter-gates-bootstrap.ps1
```

## Rust

Run:

```bash
cargo fmt --check
cargo clippy -- -D warnings
cargo test
```

Coverage goals:

- Intent parsing (`agent.rs`)
- Filter generation and summary fallback (`agent.rs`)
- Recommendation filtering and ranking (`recommendations.rs`)
- End-to-end core flow (`tests/core_flow.rs`)

## Flutter

Run:

```bash
flutter analyze
flutter test
flutter test integration_test
```

Coverage goals:

- Model mapping from Rust payloads (`test/data/stroll_models_test.dart`)
- Repository error mapping (`test/data/stroll_repository_test.dart`)
- Widget rendering and navigation (`test/widgets/*.dart`)
- Integration smoke flow (`integration_test/app_smoke_test.dart`)
