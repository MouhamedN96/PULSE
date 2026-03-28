#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
gates_script="${script_dir}/v1-gates.sh"

install_dir="${repo_root}/.tooling/flutter"
channel="stable"
skip_integration=false
use_system_flutter=false

usage() {
  cat <<'EOF'
Usage: ./scripts/flutter-gates-bootstrap.sh [--install-dir DIR] [--channel stable|beta|main] [--skip-integration] [--use-system-flutter]

Installs a local Flutter SDK if needed, then runs Flutter gates:
  flutter pub get
  flutter analyze
  flutter test
  flutter test integration_test
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: required command '${cmd}' was not found in PATH" >&2
    exit 1
  fi
}

while (($#)); do
  case "$1" in
    --install-dir)
      install_dir="$2"
      shift
      ;;
    --channel)
      channel="$2"
      shift
      ;;
    --skip-integration)
      skip_integration=true
      ;;
    --use-system-flutter)
      use_system_flutter=true
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

if [[ "${use_system_flutter}" == "true" ]]; then
  require_command flutter
else
  require_command git
  if [[ ! -x "${install_dir}/bin/flutter" ]]; then
    mkdir -p "$(dirname "${install_dir}")"
    echo "==> Installing Flutter (${channel}) into ${install_dir}"
    git clone --depth 1 --branch "${channel}" https://github.com/flutter/flutter.git "${install_dir}"
  fi
  existing_safe_dirs="$(git config --global --get-all safe.directory 2>/dev/null || true)"
  if ! grep -Fxq "${install_dir}" <<<"${existing_safe_dirs}"; then
    git config --global --add safe.directory "${install_dir}" >/dev/null
  fi
  export FLUTTER_ROOT="${install_dir}"
  export PATH="${install_dir}/bin:${PATH}"
fi

echo "==> Flutter SDK"
flutter --version

if [[ "${skip_integration}" == "true" ]]; then
  "${gates_script}" --flutter-only --skip-integration
else
  "${gates_script}" --flutter-only
fi
