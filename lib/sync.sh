#!/usr/bin/env bash
#
# sync.sh - Clone, pull, and checkout operations for git-sync
#
# Handles the actual git operations for each managed repository:
# - Cloning missing repos
# - Checking out specific commits/tags (checkout-commit mode)
# - Pulling latest on a branch (update-branch mode)

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/gitignore.sh"

GIT_SYNC_MAX_DEPTH="${GIT_SYNC_MAX_DEPTH:-10}"

sync_repo() {
    local repo_name="$1"
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

    local path git_repo mode current_branch current_commit create_on_missing ensure_ignore read_only
    path=$(config_get "$repo_name" "path")
    git_repo=$(config_get "$repo_name" "git-repo")
    mode=$(config_get "$repo_name" "mode")
    current_branch=$(config_get "$repo_name" "current-branch")
    current_commit=$(config_get "$repo_name" "current-commit")
    create_on_missing=$(config_get_with_default "$repo_name" "create-on-missing" "true")
    ensure_ignore=$(config_get_with_default "$repo_name" "ensure-in-git-ignore" "true")
    read_only=$(config_get_with_default "$repo_name" "read-only" "false")

    local full_path="${project_root}/${path}"

    echo "--- Syncing: ${repo_name} (${path}) ---"

    # Ensure path is in .gitignore if configured
    if [[ "$ensure_ignore" == "true" ]]; then
        ensure_in_gitignore "$path"
    fi

    # Read sparse-paths config (YAML list -> newline-separated)
    local sparse_paths
    sparse_paths=$(config_get_list "$repo_name" "sparse-paths")

    # Clone if missing
    if [[ ! -d "$full_path/.git" ]]; then
        if [[ "$create_on_missing" != "true" ]]; then
            echo "  SKIP: ${full_path} does not exist and create-on-missing is false"
            return 0
        fi
        if [[ -n "$sparse_paths" ]]; then
            echo "  Cloning ${git_repo} -> ${full_path} (sparse)"
            local clone_output
            clone_output=$(git clone --filter=blob:none --sparse "$git_repo" "$full_path" 2>&1) || {
                report_subrepo_error "$repo_name" "sparse clone from ${git_repo}" "$clone_output"
                return 1
            }
            cd "$full_path" || return 1
            local sparse_output
            sparse_output=$(git sparse-checkout set $sparse_paths 2>&1) || {
                report_subrepo_error "$repo_name" "sparse-checkout set" "$sparse_output"
                cd "$project_root"
                return 1
            }
            cd "$project_root"
        else
            echo "  Cloning ${git_repo} -> ${full_path}"
            local clone_output
            clone_output=$(git clone "$git_repo" "$full_path" 2>&1) || {
                report_subrepo_error "$repo_name" "clone from ${git_repo}" "$clone_output"
                return 1
            }
        fi
    fi

    cd "$full_path" || return 1

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        if [[ "$read_only" == "true" ]]; then
            report_subrepo_error "$repo_name" "read-only repo has uncommitted changes" ""
            cd "$project_root"
            return 1
        fi
        echo "  WARNING: ${repo_name} has uncommitted changes"
    fi

    case "$mode" in
        checkout-commit)
            echo "  Mode: checkout-commit"
            git fetch --all --tags --quiet
            if [[ -n "$current_commit" && "$current_commit" != "null" ]]; then
                echo "  Checking out: ${current_commit}"
                local checkout_output
                checkout_output=$(git checkout "$current_commit" 2>&1) || {
                    report_subrepo_error "$repo_name" "checkout ${current_commit}" "$checkout_output"
                    cd "$project_root"
                    return 1
                }
            fi
            ;;
        update-branch)
            echo "  Mode: update-branch (${current_branch})"
            git fetch --all --tags --quiet
            local current
            current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [[ "$current" != "$current_branch" ]]; then
                echo "  Switching to branch: ${current_branch}"
                local branch_output
                branch_output=$(git checkout "$current_branch" 2>&1) || {
                    report_subrepo_error "$repo_name" "checkout branch ${current_branch}" "$branch_output"
                    cd "$project_root"
                    return 1
                }
            fi
            echo "  Pulling latest..."
            local pull_output
            pull_output=$(git pull 2>&1) || {
                report_subrepo_error "$repo_name" "pull (resolve conflicts manually)" "$pull_output"
                cd "$project_root"
                return 1
            }
            ;;
        *)
            report_subrepo_error "$repo_name" "unknown mode '${mode}'" ""
            cd "$project_root"
            return 1
            ;;
    esac

    cd "$project_root"

    # Recursive sync: if the sub-repo has its own .git-sync.yaml, sync it too
    local current_depth="${GIT_SYNC_CURRENT_DEPTH:-0}"
    if [[ -f "${full_path}/${GIT_SYNC_CONFIG}" ]]; then
        local next_depth=$((current_depth + 1))
        if [[ $next_depth -le $GIT_SYNC_MAX_DEPTH ]]; then
            echo "  Found .git-sync.yaml in ${repo_name}, syncing recursively (depth ${next_depth})..."
            (
                cd "$full_path"
                export GIT_SYNC_CURRENT_DEPTH=$next_depth
                sync_all
            )
        else
            echo "  WARNING: max recursion depth (${GIT_SYNC_MAX_DEPTH}) reached for ${repo_name}" >&2
        fi
    fi

    echo "  Done."
}

sync_all() {
    local repos
    repos=$(config_list_repos) || return 1
    local had_errors=0

    while IFS= read -r repo_name; do
        sync_repo "$repo_name" || had_errors=1
    done <<< "$repos"

    if [[ $had_errors -ne 0 ]]; then
        echo ""
        echo "WARNING: some repos had errors during sync"
        return 1
    fi
}
