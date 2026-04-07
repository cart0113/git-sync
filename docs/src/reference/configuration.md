# Reference

git-sync is configured via `.git-sync.yaml` at the root of your project.

## File Format

Each top-level key is a logical name for a dependency. The name is used in
status output and log messages.

```yaml
my-dependency:
  path: external/my-dependency
  git-repo: https://github.com/org/repo.git
  mode: update-branch
  current-branch: main
  current-commit: abc1234
```

## Fields

### path

The directory where the repo will be cloned, relative to your project root.

### git-repo

The git URL or local path to clone from. Any valid `git clone` target works:
`https://`, `git@`, or a local path.

### mode

Controls how the repo is updated during `git-sync sync`.

- **`update-branch`** — checks out the configured branch and runs `git pull`.
  Best for dependencies you want to stay current with.
- **`checkout-commit`** — fetches all refs and checks out the exact commit or
  tag in `current-commit`. Best for pinning to a specific version.

### current-branch

Branch name to track (used by `update-branch` mode, recorded by `snapshot`).

### current-commit

Commit SHA or tag to pin to. Updated automatically by `git-sync snapshot`.

### create-on-missing

Clone the repo if the target path does not exist. Default: `true`.

### ensure-in-git-ignore

Auto-add the repo path to `.gitignore`. Default: `true`.

### read-only

Pull-only mode. Errors if the working tree is dirty during sync. Skips the repo
entirely during snapshot. Default: `false`.

### sparse-paths

List of paths for partial checkout via `git sparse-checkout`. Only these
directories are materialized in the working tree. The repo still has full
history but blobs are fetched lazily.

```yaml
my-repo:
  sparse-paths:
    - src/shared/
    - docs/
```

### commit-tracked-files-on-parent-commit

Auto-commit tracked file changes in the sub-repo during `git-sync snapshot`.
Default: `false`.

Useful when you co-edit files in sub-repos alongside the parent project. Only
tracked files are committed (`git add -u`). Use `-m` with snapshot to set the
message:

```bash
git-sync snapshot -m "update shared config"
# Sub-repo message: [via my-project] update shared config
```

### push-after-auto-commit

Push the sub-repo after auto-commit. Requires
`commit-tracked-files-on-parent-commit: true`. Default: `false`.

### parent-commit-message

Prefix template for auto-commit messages. `{parent}` expands to the parent
project name. Default: `[via {parent}]`.

Set per-repo or globally via `_settings`. Per-repo takes priority.

## Global Settings (\_settings)

The reserved `_settings` key holds options that apply to all repos:

```yaml
_settings:
  parent-commit-message: '[sync from {parent}]'
```

## Private Config (.git-sync-private.yaml)

Same format as `.git-sync.yaml` but gitignored. Holds personal dependencies that
only you need — coding standards, reference docs, tool configs.

```yaml
# .git-sync-private.yaml
my-standards:
  path: context-db/my-standards
  git-repo: https://github.com/me/my-standards.git
  mode: update-branch
  current-branch: main
  current-commit: null
  read-only: true
  sparse-paths:
    - context-db/
```

Add `.git-sync-private.yaml` to your `.gitignore`. All commands (`sync`,
`snapshot`, `status`) process both config files automatically.

## Dirty Repo Handling

git-sync warns when a managed repo has uncommitted changes but does not discard
your work:

- **sync** — warning printed, pull may fail if there are conflicts
- **snapshot** — warning printed, snapshot proceeds (HEAD may not match working
  tree)
- **read-only repos** — sync errors out, snapshot skips entirely

## Troubleshooting

### Clone fails

Check that the `git-repo` URL is accessible and you have the right SSH keys or
tokens configured.

### Pull fails with conflicts

Navigate to the repo path, resolve manually, then run `git-sync sync` again.

### Repo shows as "NOT CLONED"

Run `git-sync sync` to clone it, or check that `create-on-missing` is `true`.
