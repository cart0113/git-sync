---
description:
  Core design goals — minimal friction, zero external dependencies, bash-only
---

# Design Principles

## Minimal friction

The entire point of git-sync is that git-submodule is too complicated. git-sync
must not recreate that friction in a different form. Every design decision
filters through: **does this make git-sync harder to install, use, or debug?**

## Zero external dependencies

git-sync requires only `bash` and `git` — tools already present on any developer
machine. No package managers, no compiled binaries, no language runtimes.

Previously the project depended on `yq` for YAML parsing. This was removed
because requiring users to install a separate binary contradicts the minimal
friction goal. The config format is simple enough to parse with pure bash.

## Bash-only implementation

Bash was chosen because:

- It's everywhere — no install step
- Scripts are transparent — developers can read and fix them
- Agentic coding tools can modify bash scripts easily
- Failure modes are obvious (set -e, clear error messages)

## Simple config format

`.git-sync.yaml` uses a deliberately constrained YAML subset: flat key-value
pairs under section headers, with one list field (`sparse-paths`). No nested
objects, no anchors, no complex types. This keeps the pure-bash parser trivial.

## Compose, don't replace

git-sync handles git operations (clone, pin, sync). The language's native build
system handles compilation and imports. Each tool does what it's good at.
git-sync does not try to be a package manager, build system, or monorepo tool.
