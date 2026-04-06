# Configuration Reference

git-sync is configured via a `.git-sync.yaml` file at the root of your project.

## File Format

Each top-level key is a logical name for a dependency. The name is used in status output and log messages.

```yaml
_settings:
  parent-commit-message: <prefix template> # optional, default: "[via {parent}]"

<repo-name>:
  path: <relative path from project root>
  git-repo: <git clone URL or path>
  mode: <update-branch|checkout-commit>
  current-branch: <branch name>
  current-commit: <sha or tag>
  create-on-missing: <true|false>
  ensure-in-git-ignore: <true|false>
  commit-tracked-files-on-parent-commit: <true|false>
  push-after-auto-commit: <true|false>
  parent-commit-message: <prefix template> # optional per-repo override
```

## Fields

### path

The directory where the repo will be cloned, relative to your project root.

```yaml
path: external/my-lib
```

### git-repo

The git URL or local path to clone from. Any valid `git clone` target works.

```yaml
git-repo: https://github.com/org/repo.git
git-repo: git@github.com:org/repo.git
git-repo: /home/user/local-repo/.git
```

### mode

Controls how the repo is updated during `git-sync sync`.

- **`update-branch`** — Checks out the configured branch and runs `git pull`. Use this when you want to track the latest on a branch.
- **`checkout-commit`** — Fetches all refs and checks out the exact commit or tag specified in `current-commit`. Use this when you want to pin to a specific version.

### current-branch

The branch name to track (used by `update-branch` mode and recorded by `snapshot`).

### current-commit

The commit SHA or tag to pin to. Updated automatically by `git-sync snapshot`. In `checkout-commit` mode, this is the ref that gets checked out.

### create-on-missing

When `true` (the default), `git-sync sync` will clone the repo if the target path does not exist. When `false`, missing repos are skipped.

### ensure-in-git-ignore

When `true` (the default), git-sync automatically adds the repo path to your project's `.gitignore` so the cloned repo is not tracked by the parent project.

### commit-tracked-files-on-parent-commit

When `true`, dirty sub-repos have their tracked file changes automatically committed during `git-sync snapshot`. Defaults to `false`.

This is useful when you actively co-edit files in sub-repos alongside the parent project. When you commit the parent (and the pre-commit hook runs snapshot), any modified tracked files in the sub-repo are committed first, and the resulting SHA is recorded in `.git-sync.yaml`.

Only tracked files are committed (`git add -u`). Untracked files are left alone.

The commit message is prepended with a configurable prefix (see `parent-commit-message`). Use `-m` with snapshot to set the message body:

```bash
git-sync snapshot -m "update shared config for new feature"
# Sub-repo commit message: [via my-parent-project] update shared config for new feature
```

Without `-m`, the default message body is `git-sync: auto-commit tracked changes`.

### parent-commit-message

A prefix template prepended to auto-commit messages in sub-repos. The `{parent}` token expands to the parent project name. Defaults to `[via {parent}]`.

Can be set at two levels:

- **Per-repo** — overrides the prefix for that specific sub-repo
- **Global** — set in `_settings.parent-commit-message` to override the default for all repos

Per-repo takes priority over global, which takes priority over the hardcoded default.

```yaml
_settings:
  parent-commit-message: "[sync from {parent}]"

chart-lib:
  commit-tracked-files-on-parent-commit: true
  parent-commit-message: "[chart-lib auto]" # overrides _settings for this repo
```

### push-after-auto-commit

When `true`, the sub-repo is pushed after an auto-commit (requires `commit-tracked-files-on-parent-commit: true`). Defaults to `false`.

This is useful when you want sub-repo changes to be immediately available to collaborators. The sub-repo is pushed to its current upstream branch after the auto-commit succeeds.

## Global Settings (\_settings)

The reserved `_settings` key holds options that apply to all repos in the config file. Currently supported:

- **parent-commit-message** — default prefix template for auto-commit messages (see above)

## Private Config (.git-sync-private.yaml)

git-sync also reads `.git-sync-private.yaml` from the project root. This file uses the exact same format as `.git-sync.yaml` but is intended to be gitignored — it holds personal dependencies that only you need.

**Motivation:** The shared `.git-sync.yaml` is committed so every collaborator gets the same deps. But personal preferences — coding standards, reference docs from other projects, tool configs — don't belong in the shared config. The private config keeps them out of version control while still being managed by git-sync.

```yaml
# .git-sync-private.yaml
my-coding-standards:
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

**Setup:**

1. Add `.git-sync-private.yaml` to your `.gitignore`
2. Create the file at your project root with your personal deps
3. Run `git-sync sync` — both configs are processed automatically

All commands (`sync`, `snapshot`, `status`) process both config files. The main config runs first, then the private config. Private repos appear under a "Private config" header in status output.

A project can have either file, both, or neither. git-sync handles all combinations.

## Symlinks

git-sync resolves symlinks when locating its own scripts, so you can symlink `bin/git-sync` into your PATH or into other projects. Repo paths in `.git-sync.yaml` that are symlinks are followed transparently.

## Multiple Repos

You can manage any number of repos in a single config file:

```yaml
lib-a:
  path: external/lib-a
  git-repo: https://github.com/org/lib-a.git
  mode: update-branch
  current-branch: main
  current-commit: abc1234

lib-b:
  path: vendor/lib-b
  git-repo: https://github.com/org/lib-b.git
  mode: checkout-commit
  current-branch: release
  current-commit: v1.2.3
```
