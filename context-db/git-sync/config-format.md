---
description: .git-sync.yaml format — all fields, modes, and defaults
---

# Config Format

## .git-sync.yaml

Each top-level key is a logical repo name. Fields:

- **path**: relative path from project root where repo is cloned
- **git-repo**: git URL or local path to clone from
- **mode**: `update-branch` or `checkout-commit`
- **current-branch**: branch name (tracked in update-branch, recorded by snapshot)
- **current-commit**: SHA or tag (pinned in checkout-commit, recorded by snapshot)
- **create-on-missing**: `true`/`false` — clone if path doesn't exist (default: true)
- **ensure-in-git-ignore**: `true`/`false` — auto-add path to .gitignore (default: true)
- **read-only**: `true`/`false` — pull-only mode; errors on dirty working tree, skips snapshot (default: false)
- **sparse-paths**: YAML list of paths to check out via git sparse-checkout; only these directories are materialized in the working tree (default: empty = full checkout)
- **commit-tracked-files-on-parent-commit**: `true`/`false` — auto-commit tracked changes during snapshot (default: false)
- **push-after-auto-commit**: `true`/`false` — push sub-repo after auto-commit (default: false, requires commit-tracked-files-on-parent-commit: true)

## Modes

### update-branch
Checks out the configured branch and runs `git pull`. Stays current with upstream.

### checkout-commit
Fetches all refs and checks out the exact commit or tag. Reproducible pinning.

## Orthogonal Options

`read-only` and `sparse-paths` are independent. Any combination works:

| Config | Behavior |
|---|---|
| neither | Full clone, full read/write |
| `sparse-paths` only | Partial checkout, full read/write |
| `read-only` only | Full clone, pull-only, error on dirty |
| both | Partial checkout, pull-only, error on dirty |

### sparse-paths detail

Uses `git clone --filter=blob:none --sparse` (partial clone) on initial clone,
then `git sparse-checkout set <paths>`. Only the listed directories are checked
out. The `.git` has full history but blobs are fetched lazily.

## .git-sync-private.yaml

Identical format to `.git-sync.yaml`. Gitignored. Holds personal dependencies
that only you need (coding standards, reference docs, tooling). git-sync
processes both files during sync, snapshot, and status. See `private-config.md`
for full details.

### read-only detail

- During **sync**: if the working tree is dirty, sync fails with an error (not a warning)
- During **snapshot**: the repo is skipped entirely (no branch/commit recording)
- Auto-commit and push-after-auto-commit are implicitly disabled
