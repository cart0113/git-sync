#!/usr/bin/env bash
#
# serve.sh — Build and serve a bruha docsify site locally.
#
# Usage:
#   docs/bin/serve.sh              # serve on port 3000
#   docs/bin/serve.sh --port 4000  # serve on port 4000
#
set -euo pipefail

PORT=3000
while [ $# -gt 0 ]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$SCRIPT_DIR/build.sh"
echo "Serving at http://localhost:$PORT"
docsify serve "$DOCS_DIR" --port "$PORT"
