#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
rust_dir="${repo_root}/rust_core"
flutter_dir="${repo_root}/flutter_app"

rust_only=false
flutter_only=false
skip_integration=false

usage() {
  cat <<'EOF'
Usage: ./scripts/v1-gates.sh [--rust-only] [--flutter-only] [--skip-integration]

Runs local V1 release gates:
  Rust:    cargo fmt --check, cargo clippy -- -D warnings, cargo test
  Flutter: flutter pub get, flutter analyze, flutter test, flutter test integration_test
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: required command '${cmd}' was not found in PATH" >&2
    exit 1
  fi
}

run_in_dir() {
  local dir="$1"
  shift
  echo "==> $*"
  (
    cd "${dir}"
    "$@"
  )
}

while (($#)); do
  case "$1" in
    --rust-only)
      rust_only=true
      ;;
    --flutter-only)
      flutter_only=true
      ;;
    --skip-integration)
      skip_integration=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ "${rust_only}" == "true" && "${flutter_only}" == "true" ]]; then
  echo "error: --rust-only and --flutter-only cannot be used together" >&2
  exit 1
fi

if [[ "${flutter_only}" != "true" ]]; then
  require_command cargo
  run_in_dir "${rust_dir}" cargo fmt --check
  run_in_dir "${rust_dir}" cargo clippy -- -D warnings
  run_in_dir "${rust_dir}" cargo test
fi

if [[ "${rust_only}" != "true" ]]; then
  require_command flutter
  local_flutter_dir="${repo_root}/.tooling/flutter"
  if command -v git >/dev/null 2>&1 && [[ -d "${local_flutter_dir}/.git" ]]; then
    existing_safe_dirs="$(git config --global --get-all safe.directory 2>/dev/null || true)"
    if ! grep -Fxq "${local_flutter_dir}" <<<"${existing_safe_dirs}"; then
      git config --global --add safe.directory "${local_flutter_dir}" >/dev/null
    fi
    export FLUTTER_ROOT="${local_flutter_dir}"
    export PATH="${local_flutter_dir}/bin:${PATH}"
  fi
  run_in_dir "${flutter_dir}" flutter pub get
  run_in_dir "${flutter_dir}" flutter analyze
  run_in_dir "${flutter_dir}" flutter test
  if [[ "${skip_integration}" != "true" ]]; then
    run_in_dir "${flutter_dir}" flutter test integration_test
  fi
fi

echo "V1 gates passed."
