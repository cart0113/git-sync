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
- **push-after-auto-commit**: `true`/`false` — push sub-repo after auto-commit (default: false, requires commit-tracked-files-on-parent-commit: true)

## Modes

### update-branch
Checks out the configured branch and runs `git pull`. Stays current with upstream.

### checkout-commit
Fetches all refs and checks out the exact commit or tag. Reproducible pinning.
