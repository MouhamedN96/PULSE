# ── Stage 1: Build ──
FROM rust:1.82-slim AS builder

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY rust_core/ ./

RUN cargo build --release --bin recommendation_api

# ── Stage 2: Runtime ──
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/release/recommendation_api .

# Railway injects PORT env var
ENV PORT=8787
EXPOSE 8787

CMD ["./recommendation_api"]
