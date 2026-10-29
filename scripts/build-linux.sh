#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python scripts/build.py --godot "${GODOT_BIN:-godot}" --target linux "$@"
