---
description:
  .git-sync-private.yaml — personal repo dependencies that stay gitignored
---

# Private Config (.git-sync-private.yaml)

## Motivation

A project's `.git-sync.yaml` is committed and shared — every collaborator gets
the same dependencies. But sometimes you want personal dependencies that only
you use: coding standards you follow, reference docs from other projects,
tooling configs, etc. These don't belong in the shared config because they're
personal preferences, not project requirements.

`.git-sync-private.yaml` solves this. It uses the exact same format as
`.git-sync.yaml` but is gitignored. git-sync processes both files during sync,
snapshot, and status — shared deps from the main config, personal deps from the
private one.

## How It Works

- Place `.git-sync-private.yaml` at your project root alongside `.git-sync.yaml`
- Uses the identical YAML format (same fields, same modes, same options)
- git-sync processes the main config first, then the private config
- The private config file itself should be in `.gitignore`
- Repo paths declared in the private config are auto-added to `.gitignore` (when
  `ensure-in-git-ignore: true`) so the cloned content is also ignored

## Typical Use Case

Pull read-only reference material into your project tree without polluting the
shared config:

```yaml
my-standards:
  path: context-db/coding-standards/general-standards
  git-repo: https://github.com/me/my-standards.git
  mode: update-branch
  current-branch: main
  current-commit: null
  create-on-missing: true
  ensure-in-git-ignore: true
  read-only: true
  sparse-paths:
    - context-db/coding-standards/
```

This clones the repo, checks out only the sparse paths, marks it read-only (so
snapshot skips it and dirty state is an error), and ensures the path is
gitignored. No one else on the project sees it.

## Key Points

- A project can have `.git-sync.yaml` only, `.git-sync-private.yaml` only, or
  both — git-sync handles all combinations
- Private repos appear in `git-sync status` output under a "Private config"
  header
- Snapshot skips private read-only repos (same as main config read-only repos)
- Recursive sync works: if a private repo has its own `.git-sync.yaml`, it is
  synced recursively
