---
description: How git-sync orchestrates clone, pull, checkout, and recursive sync
---

# Architecture

git-sync is a bash tool with a simple pipeline:

## Entry Point

`bin/git-sync` is the CLI. It sources all lib/ files and dispatches to commands:
sync, snapshot, init, uninit, status.

## Config Layer (lib/config.sh)

All config access goes through `config_get`, `config_set`, `config_get_list`,
`config_list_repos`. These use `yq` to read/write `.git-sync.yaml`. The config
file path is resolved dynamically via `git rev-parse --show-toplevel`, which is
critical for recursive sync — when operating inside a sub-repo, git finds that
repo's root, not the parent's.

`config_get_list` handles YAML list fields (like `sparse-paths`) by returning
newline-separated values.

## Sync Layer (lib/sync.sh)

`sync_all` iterates repos from config. For each repo, `sync_repo`:

1. Ensures path is in .gitignore (if configured)
2. Clones if missing — uses `--filter=blob:none --sparse` when `sparse-paths` is
   set, then runs `git sparse-checkout set` for the listed paths
3. Checks dirty state: hard error if `read-only: true`, warning otherwise
4. Applies mode: checkout-commit (fetch + checkout SHA/tag) or update-branch
   (checkout branch + pull)
5. Recursively syncs if the sub-repo has its own .git-sync.yaml

Recursion uses a subshell with a depth counter (max 10) to prevent infinite
loops.

## Snapshot Layer (lib/snapshot.sh)

`snapshot_all` iterates repos and for each, reads the current branch and HEAD
commit from the actual cloned repo and writes them back into .git-sync.yaml.
Repos with `read-only: true` are skipped entirely.

## Hook Layer (lib/hooks.sh)

Installs pre-commit (runs snapshot) and post-merge (runs sync) hooks. Appends to
existing hooks rather than overwriting.
