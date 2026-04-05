#!/usr/bin/env bash
#
# build.sh — Generate sidebar and config for a bruha docsify site.
#
# Finds the bruha Python source automatically:
#   1. ../../src/bruha  (inside the GIT_BRUHA repo itself)
#   2. ../../../GIT_BRUHA/src/bruha  (sibling repo)
#
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$DOCS_DIR/.." && pwd)"

if [ -d "$REPO_ROOT/src/bruha" ]; then
    BRUHA_PY="$REPO_ROOT/src"
elif [ -d "$REPO_ROOT/../GIT_BRUHA/src/bruha" ]; then
    BRUHA_PY="$(cd "$REPO_ROOT/../GIT_BRUHA/src" && pwd)"
else
    echo "Error: bruha Python source not found." >&2
    echo "Expected at $REPO_ROOT/src/bruha or $REPO_ROOT/../GIT_BRUHA/src/bruha" >&2
    exit 1
fi

PYTHONPATH="$BRUHA_PY" python-main -c "
import bruha.docsify_ext_config as cfg
import bruha.sidebar_builder as sb
config = cfg.load_config('$DOCS_DIR')
sb.write_sidebar('$DOCS_DIR', config['top_level_folders_as_top_control'], config['content_folder'])
cfg.generate_config_js('$DOCS_DIR')
print('Built _sidebar.md + bruha-config.js')
"

STAMP=$(date +%Y%m%d%H%M%S)
sed -i '' "s/?v=[0-9a-zA-Z]*/?v=${STAMP}/g" "$DOCS_DIR/index.html"
echo "Cache bust: v=${STAMP}"

npx prettier --write "$DOCS_DIR/src/**/*.md" "$DOCS_DIR/themes/bruha-config.js" 2>&1 | tail -1
