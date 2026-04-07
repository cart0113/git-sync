---
description:
  What git-sync is, why it exists, code structure, language, and dependencies
---

# Overview

**git-sync** is a bash-based tool for composing independent git repositories
into a pseudo-monorepo. It uses a `.git-sync.yaml` config file at the project
root to declare external repos, their target paths, and sync behavior.

## Why git-sync?

- Many small repos need the convenience of versioning together like a monorepo
- git-submodule works most of the time but has confusing edge-case errors
- git-sync is simple, customizable, and transparent
- Two sync modes: `checkout-commit` (pin to exact commit) and `update-branch`
  (track a branch)

## Code Structure

```
bin/git-sync          # main entry point
lib/config.sh         # config parsing (pure bash/awk)
lib/sync.sh           # clone, pull, checkout operations
lib/snapshot.sh       # record current state back to config
lib/hooks.sh          # git hook installation/management
lib/gitignore.sh      # .gitignore management
templates/            # sample AGENTS.md and skills for LLM integration
context-db/           # project knowledge database
docs/                 # GitHub Pages documentation (bruha)
examples/             # example .git-sync.yaml files
```

## Language

This is a **bash** project. All scripts use `#!/usr/bin/env bash` and target
bash 4+.

## Dependencies

- `bash` 4+
- `git`

No other dependencies. Config parsing uses pure bash/awk.
