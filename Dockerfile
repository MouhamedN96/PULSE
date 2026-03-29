# ── Stage 1: Build Flutter Web ──
FROM ghcr.io/cirruslabs/flutter:3.27.4 AS flutter-builder

WORKDIR /app/flutter_app
COPY flutter_app/ ./
RUN flutter pub get
RUN flutter build web --release

# ── Stage 2: Build Rust Backend ──
FROM rust:1.85-slim AS rust-builder

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY rust_core/ ./

RUN cargo build --release --bin recommendation_api

# ── Stage 3: Runtime ──
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Rust binary
COPY --from=rust-builder /app/target/release/recommendation_api .

# Copy Flutter web build
COPY --from=flutter-builder /app/flutter_app/build/web ./static/

# Railway injects PORT env var
ENV PORT=8787
EXPOSE 8787

CMD ["./recommendation_api"]
