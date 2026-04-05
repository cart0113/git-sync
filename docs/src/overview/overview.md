# git-sync

Compose independent git repositories into a pseudo-monorepo.

## What is git-sync?

git-sync is a specific solution to a common workflow pattern: you have many small, independent git repositories and you want the convenience of versioning them together like a monorepo — without actually merging them into one.

Each sub-repo stays a real, independent git clone with its own full history. The parent project just declares what it needs in a single YAML config file (`.git-sync.yaml`). git-sync handles the cloning, pinning, and syncing.

This is not meant to be an exhaustive dependency management tool. It is a straightforward bash utility for a straightforward problem.

## Why git-sync?

- Many small repos need the convenience of versioning together like a monorepo
- git-submodule works most of the time but has confusing edge-case errors
- git-sync is simple, customizable, and transparent
- Two sync modes: `checkout-commit` (pin to exact commit) and `update-branch` (track a branch)

## How it differs from git-submodule

- Sub-repos are real, independent git clones — not embedded pointers
- Single YAML config declares everything in one place
- Two sync modes: pin to exact commits or track a branch
- Transparent bash scripts you can read and modify
- No confusing edge-case errors

## Quick Start

### 1. Install

Clone this repo and add `bin/` to your PATH, or copy `bin/git-sync` and `lib/` into your project.

```bash
git clone https://github.com/cart0113/git-sync.git
export PATH="$PATH:/path/to/git-sync/bin"
```

### 2. Install yq

git-sync requires [yq](https://github.com/mikefarah/yq) for YAML parsing.

```bash
# macOS
brew install yq

# Linux
snap install yq
```

### 3. Create .git-sync.yaml

Add a `.git-sync.yaml` to your project root:

```yaml
my-dependency:
  path: external/my-dependency
  git-repo: https://github.com/example/my-dependency.git
  mode: update-branch
  current-branch: main
  current-commit: abc1234
  create-on-missing: true
  ensure-in-git-ignore: true
```

### 4. Sync

```bash
git-sync sync
```

### 5. Install hooks (optional)

```bash
git-sync init
```

This installs a pre-commit hook that snapshots repo state, and a post-merge hook that syncs after pull.

## Commands

| Command             | Description                                                       |
| ------------------- | ----------------------------------------------------------------- |
| `git-sync sync`     | Clone missing repos and update all to their configured state      |
| `git-sync snapshot` | Record current branch and commit of each repo into .git-sync.yaml |
| `git-sync init`     | Install git hooks for automatic sync/snapshot                     |
| `git-sync uninit`   | Remove git-sync hooks                                             |
| `git-sync status`   | Show the current state of all managed repos                       |
