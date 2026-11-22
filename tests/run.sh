#!/usr/bin/env bash
# Runs ShellCheck, zsh -n, and the sandboxed install.sh test.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

need shellcheck
need zsh

shellcheck install.sh tests/install_test.sh tests/run.sh
zsh -n .zshrc
bash tests/install_test.sh
