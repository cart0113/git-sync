# Usage Guide

## Typical Workflow

### Initial Setup

1. Create `.git-sync.yaml` in your project root
2. Run `git-sync sync` to clone all dependencies
3. Run `git-sync init` to install git hooks

### Day-to-Day

With hooks installed, git-sync runs automatically:

- **On commit**: The pre-commit hook runs `git-sync snapshot`, recording each dependency's current branch and commit SHA into `.git-sync.yaml`. This gets included in your commit so collaborators know the exact state.
- **On pull/merge**: The post-merge hook runs `git-sync sync`, cloning any new dependencies and updating existing ones to the state recorded in `.git-sync.yaml`.

### Manual Commands

You can always run commands manually:

```bash
# Pull latest for all update-branch repos, checkout pinned commits for checkout-commit repos
git-sync sync

# Record current state of all repos into .git-sync.yaml
git-sync snapshot

# Check what state everything is in
git-sync status
```

## Sync Modes

### update-branch

Tracks a branch. On `git-sync sync`, it checks out the branch and runs `git pull`.

Best for dependencies you want to stay current with, like a shared config repo or a library under active development by your team.

### checkout-commit

Pins to an exact commit or tag. On `git-sync sync`, it fetches all refs and checks out the specified commit.

Best for stable dependencies where you want reproducible builds. Use tags like `v1.2.3` for readability.

## Dirty Repo Handling

git-sync warns you when a managed repo has uncommitted changes:

- During **snapshot**: A warning is printed but the snapshot proceeds (recording the current HEAD, which may not match the working tree).
- During **sync**: A warning is printed. Pull operations may fail if there are conflicts.

This is intentional — git-sync tells you about the problem but does not silently discard your work.

## Hooks

### Installing

```bash
git-sync init
```

This adds:

- A **pre-commit** hook that runs `git-sync snapshot`
- A **post-merge** hook that runs `git-sync sync`

If you already have hooks, git-sync appends to them rather than overwriting.

### Removing

```bash
git-sync uninit
```

This removes only the git-sync sections from your hooks, leaving any other hook content intact.

## Troubleshooting

### "yq is required but not installed"

Install yq from [https://github.com/mikefarah/yq](https://github.com/mikefarah/yq).

### Clone fails

Check that the `git-repo` URL is accessible and that you have the right SSH keys or tokens configured.

### Pull fails with conflicts

Your managed repo has local changes that conflict with upstream. Navigate to the repo path and resolve manually, then run `git-sync sync` again.

### Repo shows as "NOT CLONED" in status

Run `git-sync sync` to clone it, or set `create-on-missing: true` in the config.
