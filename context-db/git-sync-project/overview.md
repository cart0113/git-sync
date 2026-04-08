---
description:
  Bash tool that composes independent git repos into a pseudo-monorepo via a YAML
  config file -- an alternative to git submodule
---

# Project Overview

**git-sync** composes independent git repositories into a pseudo-monorepo; an
alternative to git submodule.

> This project is in the concept phase and is lightly tested.

## How It Works

git-sync manages a collection of independent git repos declared in a single YAML
config file (`.git-sync.yaml`). Each sub-repo stays a real, independent git
clone with its own full history. git-sync handles cloning, pinning, and syncing.

Two sync modes:

- **update-branch** -- track a branch, pull latest on sync
- **checkout-commit** -- pin to an exact commit or tag for reproducible builds

Only requires `bash` and `git`. No other dependencies. It's one file.

## Commands

| Command             | Description                                                       |
| ------------------- | ----------------------------------------------------------------- |
| `git-sync sync`     | Clone missing repos and update all to their configured state      |
| `git-sync snapshot` | Record current branch and commit of each repo into .git-sync.yaml |
| `git-sync init`     | Install git hooks for automatic sync/snapshot                     |
| `git-sync uninit`   | Remove git-sync hooks                                             |
| `git-sync status`   | Show the current state of all managed repos                       |

With hooks installed, `git-sync snapshot` runs on commit (recording dependency
state) and `git-sync sync` runs on pull (updating dependencies).

## Documentation

Full docs: https://cart0113.github.io/git-sync/
