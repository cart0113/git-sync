---
description: How git-sync orchestrates clone, pull, checkout, and recursive sync
---

# Architecture

git-sync is a single bash script (`bin/git-sync.sh`) with all logic inlined. No
external dependencies beyond bash and git.

## Sections

The script is organized into clearly marked sections:

- **Config** — pure awk parsing of `.git-sync.yaml`. Functions: `config_get`,
  `config_set`, `config_list_repos`, `config_get_list`,
  `config_get_with_default`, `config_get_setting_with_default`.
- **Gitignore** — auto-adds repo paths to `.gitignore`.
- **Sync** — clone, fetch, checkout, pull. Handles both sync modes and recursive
  sync into sub-repos.
- **Snapshot** — records current branch/commit back into config. Handles
  auto-commit and push of dirty sub-repos.
- **Hooks** — installs/removes pre-commit (snapshot) and post-merge (sync) git
  hooks.
- **CLI** — usage, status display, argument parsing, command dispatch.

## Config Parsing

Config access uses pure awk — no yq or other tools. The config file path is
resolved dynamically via `git rev-parse --show-toplevel`, which is critical for
recursive sync — when operating inside a sub-repo, git finds that repo's root,
not the parent's.

## Sync Pipeline

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

## Snapshot Pipeline

`snapshot_all` iterates repos and for each, reads the current branch and HEAD
commit from the actual cloned repo and writes them back into .git-sync.yaml.
Repos with `read-only: true` are skipped entirely.

## Hook Installation

Installs pre-commit (runs snapshot) and post-merge (runs sync) hooks. Appends to
existing hooks rather than overwriting.
