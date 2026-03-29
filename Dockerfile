# ── Stage 1: Build Flutter Web ──
FROM debian:bookworm-slim AS flutter-builder

RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_VERSION=3.27.4
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt

RUN flutter config --no-analytics \
    && flutter precache --web

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
