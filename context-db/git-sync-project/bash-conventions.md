---
description:
  Bash coding conventions — single-file structure, section markers, function
  naming, error handling patterns
---

# Bash Conventions

## Single-file structure

All logic lives in `bin/git-sync.sh`. No sourced libraries, no external
dependencies beyond bash and git. This keeps install to "copy one file."

## Section markers

The script is divided into sections using banner comments:

```bash
# ── Section Name ─────────────────────────────────────────────────────────
#
# Multi-line description of what this section does.
#
# Functions:
#   function_name ARG1 ARG2  - brief description
#   another_function         - brief description
```

Search for `── <name>` to jump between sections. The sections in order are:
Config, Gitignore, Sync, Snapshot, Hooks, CLI.

## Function naming

- `config_*` — config parsing (config_get, config_set, config_list_repos)
- `sync_*` — sync operations (sync_repo, sync_all)
- `snapshot_*` — snapshot operations (snapshot_repo, snapshot_all)
- `install_*` / `uninstall_*` — hook management
- `cmd_*` — CLI command handlers (cmd_status)
- Helpers are named descriptively: `ensure_in_gitignore`, `find_git_sync_bin`,
  `report_subrepo_error`

## Error handling

- `set -euo pipefail` at the top — fail fast on errors
- Git commands capture output and check exit codes explicitly:
  ```bash
  local output
  output=$(git clone "$url" "$path" 2>&1) || {
      report_subrepo_error "$repo_name" "clone from ${url}" "$output"
      return 1
  }
  ```
- `report_subrepo_error` formats errors with a header and separator for
  readability
- Always `cd "$project_root"` before returning from functions that cd into
  sub-repos

## Config parsing pattern

Pure awk, no external YAML tools. Each awk program:

1. Tracks the current section by matching unindented lines ending with `:`
2. Matches fields within the target section by checking for the `"  field: "`
   prefix
3. Splits on first `": "` to handle values containing colons (URLs)

`config_set` writes to a `.tmp` file then `mv` for atomic replacement.

## Variable conventions

- `local` for all function-scoped variables
- Environment variables for cross-function state: `GIT_SYNC_CONFIG`,
  `GIT_SYNC_MAX_DEPTH`, `GIT_SYNC_CURRENT_DEPTH`
- Defaults via `${VAR:-default}` pattern
