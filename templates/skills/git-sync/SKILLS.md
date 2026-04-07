---
description:
  Manage external git repository dependencies via git-sync. Sync, snapshot, and
  configure repos declared in .git-sync.yaml.
---

git-sync composes independent git repos into a pseudo-monorepo using
`.git-sync.yaml` config files.

## Commands

Run these via `bin/git-sync`:

- `bin/git-sync sync` — clone missing repos, update all to configured state
- `bin/git-sync snapshot` — record current branch/commit into .git-sync.yaml
- `bin/git-sync init` — install pre-commit (snapshot) and post-merge (sync)
  hooks
- `bin/git-sync uninit` — remove git-sync hooks
- `bin/git-sync status` — show current state of all managed repos

## Config format (.git-sync.yaml)

Each top-level key is a repo name. Fields:

- **path**: relative path where repo is cloned
- **git-repo**: git URL to clone from
- **mode**: `update-branch` (track branch, pull latest) or `checkout-commit`
  (pin to exact commit/tag)
- **current-branch**: branch name
- **current-commit**: commit SHA or tag
- **create-on-missing**: clone if not present (default: true)
- **ensure-in-git-ignore**: auto-add to .gitignore (default: true)
- **read-only**: pull-only, error on dirty, skip snapshot (default: false)
- **sparse-paths**: list of paths for partial checkout

## Private config

`.git-sync-private.yaml` uses the same format but is gitignored. For personal
dependencies that shouldn't be shared.

Now help the user with their git-sync task.
