#!/usr/bin/env bash
#
# format.sh — Run prettier on docs content and theme files.
#
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

npx prettier --write "$DOCS_DIR/**/*.md" "$DOCS_DIR/themes/*.js" "$DOCS_DIR/themes/*.css"
