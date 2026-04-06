#!/usr/bin/env bash
#
# snapshot.sh - Capture current state of all managed repos
#
# Reads each repo's current branch and commit, then writes them
# back into .git-sync.yaml. Intended to run before committing
# the parent project so the config always reflects the pinned state.
#
# commit-tracked-files-on-parent-commit:
#   When true on a repo entry, dirty sub-repos have their tracked file
#   changes auto-committed during snapshot. Pass -m to set the message.
#
# parent-commit-message:
#   Prefix prepended to auto-commit messages. Set per-repo or globally
#   via _settings.parent-commit-message. Default: "[via {parent}]".
#   The {parent} token expands to the parent project name.
#
# push-after-auto-commit:
#   When true (and commit-tracked-files-on-parent-commit is also true),
#   the sub-repo is pushed after auto-committing.

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

GIT_SYNC_MAX_DEPTH="${GIT_SYNC_MAX_DEPTH:-10}"
GIT_SYNC_COMMIT_MESSAGE="${GIT_SYNC_COMMIT_MESSAGE:-git-sync: auto-commit tracked changes}"

auto_commit_tracked_files() {
    local repo_name="$1"
    local full_path="$2"
    local message="$3"
    local should_push="$4"
    local prefix="$5"

    cd "$full_path" || return 1

    # Only proceed if there are tracked file changes (staged or unstaged)
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        return 0
    fi

    local prefixed_message="${prefix} ${message}"

    echo "  Auto-committing tracked changes in ${full_path}..."
    git add -u
    local commit_output
    commit_output=$(git commit -m "$prefixed_message" 2>&1) || {
        report_subrepo_error "$repo_name" "auto-commit tracked changes" "$commit_output"
        return 1
    }
    echo "  Auto-committed."

    if [[ "$should_push" == "true" ]]; then
        echo "  Pushing ${full_path}..."
        local push_output
        push_output=$(git push 2>&1) || {
            report_subrepo_error "$repo_name" "push after auto-commit" "$push_output"
            return 1
        }
        echo "  Pushed."
    fi
}

snapshot_repo() {
    local repo_name="$1"
    local commit_message="$2"
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

    local path read_only
    path=$(config_get "$repo_name" "path")
    read_only=$(config_get_with_default "$repo_name" "read-only" "false")
    local full_path="${project_root}/${path}"

    if [[ "$read_only" == "true" ]]; then
        echo "  SKIP: ${repo_name} - read-only"
        return 0
    fi

    if [[ ! -d "$full_path/.git" ]]; then
        echo "  SKIP: ${repo_name} - not cloned at ${path}"
        return 0
    fi

    echo "--- Snapshot: ${repo_name} (${path}) ---"

    local auto_commit
    auto_commit=$(config_get_with_default "$repo_name" "commit-tracked-files-on-parent-commit" "false")
    local should_push
    should_push=$(config_get_with_default "$repo_name" "push-after-auto-commit" "false")

    # Resolve commit message prefix: per-repo > _settings > hardcoded default
    local prefix
    prefix=$(config_get_with_default "$repo_name" "parent-commit-message" "")
    if [[ -z "$prefix" ]]; then
        prefix=$(config_get_setting_with_default "parent-commit-message" "[via {parent}]")
    fi
    local parent_name
    parent_name=$(basename "$project_root")
    prefix="${prefix//\{parent\}/$parent_name}"

    cd "$full_path" || return 1

    local is_dirty=false
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        is_dirty=true
    fi

    if [[ "$is_dirty" == "true" ]]; then
        if [[ "$auto_commit" == "true" ]]; then
            auto_commit_tracked_files "$repo_name" "$full_path" "$commit_message" "$should_push" "$prefix"
        else
            echo "  WARNING: ${repo_name} has uncommitted changes - snapshot may not reflect clean state"
        fi
    fi

    # Read git state while in the sub-repo
    cd "$full_path" || return 1
    local branch commit tag
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    commit=$(git rev-parse HEAD 2>/dev/null)
    tag=$(git describe --exact-match --tags HEAD 2>/dev/null)

    # cd back to parent BEFORE calling config_set, because config_set uses
    # git rev-parse --show-toplevel which must resolve to the parent project
    cd "$project_root"

    if [[ "$branch" != "HEAD" ]]; then
        echo "  Branch: ${branch}"
        config_set "$repo_name" "current-branch" "$branch"
    else
        echo "  Detached HEAD - keeping existing branch value"
    fi

    echo "  Commit: ${commit}"
    config_set "$repo_name" "current-commit" "$commit"

    if [[ -n "$tag" ]]; then
        echo "  Tag: ${tag}"
    fi

    # Recursive snapshot: if the sub-repo has its own .git-sync.yaml, snapshot it too
    local current_depth="${GIT_SYNC_CURRENT_DEPTH:-0}"
    if [[ -f "${full_path}/${GIT_SYNC_CONFIG}" ]]; then
        local next_depth=$((current_depth + 1))
        if [[ $next_depth -le $GIT_SYNC_MAX_DEPTH ]]; then
            echo "  Found .git-sync.yaml in ${repo_name}, snapshotting recursively (depth ${next_depth})..."
            (
                cd "$full_path"
                export GIT_SYNC_CURRENT_DEPTH=$next_depth
                export GIT_SYNC_COMMIT_MESSAGE="$commit_message"
                snapshot_all "$commit_message"
            )
        else
            echo "  WARNING: max recursion depth (${GIT_SYNC_MAX_DEPTH}) reached for ${repo_name}" >&2
        fi
    fi

    echo "  Done."
}

snapshot_all() {
    local commit_message="${1:-$GIT_SYNC_COMMIT_MESSAGE}"
    local config_files had_errors=0
    config_files=$(all_config_files)

    if [[ -z "$config_files" ]]; then
        echo "No config files found."
        return 1
    fi

    while IFS= read -r config_name; do
        local saved_config="$GIT_SYNC_CONFIG"
        GIT_SYNC_CONFIG="$config_name"

        if [[ "$config_name" == "$GIT_SYNC_PRIVATE_CONFIG" ]]; then
            echo ""
            echo "=== Private config: ${config_name} ==="
        fi

        local repos
        repos=$(config_list_repos) || { GIT_SYNC_CONFIG="$saved_config"; continue; }

        while IFS= read -r repo_name; do
            snapshot_repo "$repo_name" "$commit_message" || had_errors=1
        done <<< "$repos"

        GIT_SYNC_CONFIG="$saved_config"
    done <<< "$config_files"

    if [[ $had_errors -ne 0 ]]; then
        echo ""
        echo "WARNING: some repos had errors during snapshot"
        return 1
    fi

    echo ""
    echo "Snapshot complete. Review config files and commit."
}
