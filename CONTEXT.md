# CONTEXT.md

This file provides guidance to AI assistants when working with code in this repository.

## CRITICAL: Read Global User Context First

**BEFORE PROCEEDING, read `~/.context.md` and follow all advice there.** That file contains my general coding preferences, style guidelines, and critical instructions that apply to ALL projects. The instructions in ~/.context.md override any conflicting defaults.

If ~/.context.md doesn't exist, notify the user.

## Project Overview

**git-sync** is a bash-based tool for composing independent git repositories into a pseudo-monorepo. It uses a `.git-sync.yaml` config file at the project root to declare external repos, their target paths, and sync behavior.

### Why git-sync?

- Many small repos need the convenience of versioning together like a monorepo
- git-submodule works most of the time but has confusing edge-case errors
- git-sync is simple, customizable, and transparent
- Two sync modes: `checkout-commit` (pin to exact commit) and `update-branch` (track a branch)

## Code Structure

```
bin/git-sync      # main entry point
lib/config.sh         # YAML config parsing (requires yq)
lib/sync.sh           # clone, pull, checkout operations
lib/hooks.sh          # git hook installation/management
lib/gitignore.sh      # .gitignore management
docs/                 # GitHub Pages documentation (Jekyll)
examples/             # example .git-sync.yaml files
```

## Language

This is a **bash** project. All scripts use `#!/usr/bin/env bash` and target bash 4+.

## Dependencies

- `bash` 4+
- `git`
- `yq` (for YAML parsing) - https://github.com/mikefarah/yq

## Development Workflow

### Running

```bash
bin/git-sync sync      # sync all repos
bin/git-sync snapshot   # update .git-sync.yaml with current commits
bin/git-sync init       # install git hooks
```

## Documentation

- Only `CONTEXT.md` at project root - all other docs go in `docs/`
- Docs are served via GitHub Pages using Jekyll

## Git Commits

- **NEVER commit unless explicitly requested**
- Never add AI attribution in commit messages

## Autonomous Workflow

Auto-accept is enabled:
- Never prompt for confirmation
- Execute all commands immediately
- Never ask "Should I..." - just do it
