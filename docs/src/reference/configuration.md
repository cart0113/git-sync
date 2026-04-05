# Configuration Reference

git-sync is configured via a `.git-sync.yaml` file at the root of your project.

## File Format

Each top-level key is a logical name for a dependency. The name is used in status output and log messages.

```yaml
<repo-name>:
  path: <relative path from project root>
  git-repo: <git clone URL or path>
  mode: <update-branch|checkout-commit>
  current-branch: <branch name>
  current-commit: <sha or tag>
  create-on-missing: <true|false>
  ensure-in-git-ignore: <true|false>
  commit-tracked-files-on-parent-commit: <true|false> # experimental
  push-after-auto-commit: <true|false> # experimental
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

### commit-tracked-files-on-parent-commit (experimental)

When `true`, dirty sub-repos have their tracked file changes automatically committed during `git-sync snapshot`. Defaults to `false`.

This is useful when you actively co-edit files in sub-repos alongside the parent project. When you commit the parent (and the pre-commit hook runs snapshot), any modified tracked files in the sub-repo are committed first, and the resulting SHA is recorded in `.git-sync.yaml`.

Only tracked files are committed (`git add -u`). Untracked files are left alone.

The commit message is automatically prepended with `[via <parent-project>]` so it's clear the parent repo triggered the commit. Use `-m` with snapshot to set the message body:

```bash
git-sync snapshot -m "update shared config for new feature"
# Sub-repo commit message: [via my-parent-project] update shared config for new feature
```

Without `-m`, the default message body is `git-sync: auto-commit tracked changes`.

### push-after-auto-commit (experimental)

When `true`, the sub-repo is pushed after an auto-commit (requires `commit-tracked-files-on-parent-commit: true`). Defaults to `false`.

This is useful when you want sub-repo changes to be immediately available to collaborators. The sub-repo is pushed to its current upstream branch after the auto-commit succeeds.

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
