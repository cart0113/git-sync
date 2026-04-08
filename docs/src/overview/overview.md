# git-sync

Compose independent git repositories into a pseudo-monorepo; an alternative to
git submodule.

> [!NOTE] This project is in the concept phase and is lightly tested.

## What is git-sync?

git-sync manages a collection of independent git repos declared in a single YAML
config file (`.git-sync.yaml`). Each sub-repo stays a real, independent git
clone with its own full history. git-sync handles the cloning, pinning, and
syncing.

Two sync modes:

- **update-branch** — track a branch, pull latest on sync
- **checkout-commit** — pin to an exact commit or tag for reproducible builds

Only requires `bash` and `git`. No other dependencies. It's one file.

## Why not git submodule?

The problems are well documented:

- [Ask HN: Why are Git submodules so bad?](https://news.ycombinator.com/item?id=31792303)
  (2022) — devs describe needing five separate commits across nested repos for
  one feature, clone not pulling submodules by default, and every git operation
  requiring parallel submodule bookkeeping
- [Git Submodules are awful but occasionally necessary](https://www.feoh.org/posts/git-submodules-are-awful-but-occasionally-necessary.html)
  (2024) — calls submodules "a fractal of bad UX" that leave you "trapped in an
  unendingly frustrating purgatory of bad error messages, unclear working
  states"
- [Reasons to avoid Git submodules](https://blog.timhutt.co.uk/against-submodules/)
  (2024) — git worktrees don't work reliably with submodules, switching branches
  leaves ghost files requiring manual cleanup, and submodule URLs hurt repo
  portability

This is not meant to be an exhaustive substitute for git submodule; rather, this
is a focused tool that covers common work patterns, in a bash script that is
easy to read and fix when something goes wrong.

## Quick Start

### 1. Copy `bin/git-sync.sh` into your project

```bash
cp git-sync/bin/git-sync.sh your-project/bin/
```

### 2. Create `.git-sync.yaml`

```yaml
my-dependency:
  path: external/my-dependency
  git-repo: https://github.com/example/my-dependency.git
  mode: update-branch
  current-branch: main
  current-commit: abc1234
```

### 3. Sync and install hooks

```bash
bin/git-sync.sh sync
bin/git-sync.sh init
```

With hooks installed, `git-sync snapshot` runs on commit (recording dependency
state) and `git-sync sync` runs on pull (updating dependencies).

## Commands

| Command             | Description                                                       |
| ------------------- | ----------------------------------------------------------------- |
| `git-sync sync`     | Clone missing repos and update all to their configured state      |
| `git-sync snapshot` | Record current branch and commit of each repo into .git-sync.yaml |
| `git-sync init`     | Install git hooks for automatic sync/snapshot                     |
| `git-sync uninit`   | Remove git-sync hooks                                             |
| `git-sync status`   | Show the current state of all managed repos                       |

Full docs: https://cart0113.github.io/git-sync/
