---
description: Development workflow — sync, snapshot, and init commands
---

# Development Workflow

## Running

```bash
bin/git-sync.sh sync      # sync all repos
bin/git-sync.sh snapshot   # update .git-sync.yaml with current commits
bin/git-sync.sh init       # install git hooks
```

### sync

Iterates all repos declared in `.git-sync.yaml` (and `.git-sync-private.yaml` if
present). For each repo: clones if missing, applies the configured mode
(`update-branch` or `checkout-commit`), and recurses into sub-repos that have
their own `.git-sync.yaml`.

### snapshot

Records the current branch and HEAD commit of each synced repo back into
`.git-sync.yaml`. Skips repos marked `read-only: true`.

### init

Installs git hooks: a pre-commit hook that runs snapshot and a post-merge hook
that runs sync. Appends to existing hooks rather than overwriting.

## Other Commands

- `bin/git-sync.sh status` — show sync state of all repos
- `bin/git-sync.sh uninit` — remove installed git hooks
