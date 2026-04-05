# git-sync

Compose independent git repositories into a pseudo-monorepo; an alternative to git submodule.

## Why not git submodule?

I've used git submodule across many projects and hit too many edge cases. Detached HEAD confusion, forgotten submodule pushes that break the repo for everyone, the `init && update` ceremony that trips up every new contributor, merge conflicts on submodule pointers that aren't real text conflicts — the list goes on.

Removing a submodule is a multi-step ritual (`git rm --cached`, edit `.gitmodules`, edit `.git/config`, delete `.git/modules/<name>`). Getting any step wrong leaves ghost state. CI pipelines need special handling. `git pull` doesn't update submodules unless you remember `--recurse-submodules`.

The problems are [well](https://stackoverflow.com/questions/12075809/git-submodules-workflow-issues) [documented](https://www.atlassian.com/git/tutorials/git-submodule).

I didn't need most of what submodule does. I just wanted to compose repos together and keep them in sync. So I wrote a tool that does exactly that — the core of what I wanted, in bash scripts I can read and fix when something goes wrong.

## What is git-sync?

git-sync manages a collection of independent git repos declared in a single YAML config file (`.git-sync.yaml`). Each sub-repo stays a real, independent git clone with its own full history. git-sync handles the cloning, pinning, and syncing.

Two sync modes:

- **update-branch** — track a branch, pull latest on sync
- **checkout-commit** — pin to an exact commit or tag for reproducible builds

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
