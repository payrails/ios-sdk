#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: SwiftLint is not installed." >&2
  echo "Install SwiftLint or run in CI where it is provisioned." >&2
  exit 1
fi

swiftlint --strict --config .swiftlint.yml
