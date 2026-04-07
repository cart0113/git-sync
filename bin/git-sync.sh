#!/usr/bin/env bash
#
# git-sync.sh - Compose independent git repositories into a pseudo-monorepo
#
# A single-file tool that manages external repository dependencies declared
# in .git-sync.yaml. Only requires bash and git. No other dependencies.
#
# Two sync modes:
#   update-branch   - track a branch, pull latest on sync
#   checkout-commit - pin to a specific commit or tag
#
# Sections (search for "── <name>" to jump):
#   Config     - Pure awk YAML parser. Read/write .git-sync.yaml fields.
#   Gitignore  - Auto-add managed repo paths to .gitignore.
#   Sync       - Clone, fetch, checkout, pull. Handles both modes + recursion.
#   Snapshot   - Record current branch/commit back into config. Auto-commit.
#   Hooks      - Install/remove pre-commit (snapshot) and post-merge (sync).
#   CLI        - Usage text, status display, argument parsing, main dispatch.
#

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
#
# Pure awk parser for .git-sync.yaml. No yq or external YAML tools.
#
# The config format is a constrained YAML subset:
#   - Top-level keys are section names (repo names or _settings)
#   - Values are 2-space indented: "  key: value"
#   - Lists are 4-space indented: "    - item"
#   - Values can contain colons (URLs) — parser splits on first ": " only
#   - Comments (#) and blank lines are ignored
#
# Functions:
#   config_file_path            - resolve path to .git-sync.yaml via git root
#   config_exists               - check if .git-sync.yaml exists
#   all_config_files            - list both main and private config filenames
#   config_list_repos           - list all top-level keys except _settings
#   config_get REPO FIELD       - read a scalar value (returns "null" if missing)
#   config_set REPO FIELD VAL   - write a scalar value in-place
#   config_get_list REPO FIELD  - read list items as newline-separated output
#   config_get_with_default     - config_get with fallback for null/empty
#   config_get_setting_with_default - read from _settings with fallback
#   report_subrepo_error        - formatted error output for sub-repo failures

GIT_SYNC_CONFIG=".git-sync.yaml"
GIT_SYNC_PRIVATE_CONFIG=".git-sync-private.yaml"

config_file_path() {
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$project_root" ]]; then
        echo "ERROR: not inside a git repository" >&2
        return 1
    fi
    echo "${project_root}/${GIT_SYNC_CONFIG}"
}

config_exists() {
    local config
    config=$(config_file_path) || return 1
    [[ -f "$config" ]]
}

private_config_file_path() {
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$project_root" ]]; then
        echo "ERROR: not inside a git repository" >&2
        return 1
    fi
    echo "${project_root}/${GIT_SYNC_PRIVATE_CONFIG}"
}

private_config_exists() {
    local config
    config=$(private_config_file_path) || return 1
    [[ -f "$config" ]]
}

all_config_files() {
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    local main="${project_root}/${GIT_SYNC_CONFIG}"
    local private="${project_root}/${GIT_SYNC_PRIVATE_CONFIG}"
    if [[ -f "$main" ]]; then
        echo "$GIT_SYNC_CONFIG"
    fi
    if [[ -f "$private" ]]; then
        echo "$GIT_SYNC_PRIVATE_CONFIG"
    fi
}

config_list_repos() {
    local config
    config=$(config_file_path) || return 1
    awk '/^[^[:space:]#]/ && !/^_settings:/ { sub(/:.*/, ""); print }' "$config"
}

config_get() {
    local repo_name="$1"
    local field="$2"
    local config
    config=$(config_file_path) || return 1

    local result
    result=$(awk -v section="$repo_name" -v field="$field" '
        /^[^[:space:]#]/ { s = $0; sub(/:.*/, "", s); cur = s }
        cur == section {
            prefix = "  " field ": "
            if (index($0, prefix) == 1) {
                print substr($0, length(prefix) + 1)
                exit
            }
        }
    ' "$config")

    if [[ -z "$result" ]]; then
        echo "null"
    else
        echo "$result"
    fi
}

config_set() {
    local repo_name="$1"
    local field="$2"
    local value="$3"
    local config
    config=$(config_file_path) || return 1

    local prefix="  ${field}: "
    awk -v section="$repo_name" -v prefix="$prefix" -v value="$value" '
        /^[^[:space:]#]/ { s = $0; sub(/:.*/, "", s); cur = s }
        cur == section && index($0, prefix) == 1 {
            print prefix value
            next
        }
        { print }
    ' "$config" > "${config}.tmp" && mv "${config}.tmp" "$config"
}

config_get_list() {
    local repo_name="$1"
    local field="$2"
    local config
    config=$(config_file_path) || return 1

    awk -v section="$repo_name" -v field="$field" '
        /^[^[:space:]#]/ { s = $0; sub(/:.*/, "", s); cur = s; in_list = 0 }
        cur == section && $0 == "  " field ":" { in_list = 1; next }
        in_list && /^    - / { val = $0; sub(/^    - /, "", val); print val; next }
        in_list && /^  [^ ]/ { in_list = 0 }
        in_list && /^[^ ]/ { in_list = 0 }
    ' "$config"
}

config_get_setting_with_default() {
    local field="$1"
    local default_value="$2"
    local config
    config=$(config_file_path) || { echo "$default_value"; return; }

    local value
    value=$(awk -v field="$field" '
        /^[^[:space:]#]/ { s = $0; sub(/:.*/, "", s); cur = s }
        cur == "_settings" {
            prefix = "  " field ": "
            if (index($0, prefix) == 1) {
                print substr($0, length(prefix) + 1)
                exit
            }
        }
    ' "$config")

    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

config_get_with_default() {
    local repo_name="$1"
    local field="$2"
    local default_value="$3"
    local value
    value=$(config_get "$repo_name" "$field")
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

report_subrepo_error() {
    local repo_name="$1"
    local summary="$2"
    local git_output="$3"

    local header="git-sync: sub-repo '${repo_name}' failed: ${summary}"
    local separator
    separator=$(printf '%*s' "${#header}" '' | tr ' ' '-')

    echo "" >&2
    echo "  ${header}" >&2
    echo "  ${separator}" >&2
    echo "" >&2
    if [[ -n "$git_output" ]]; then
        echo "$git_output" >&2
        echo "" >&2
    fi
}

# ── Gitignore ────────────────────────────────────────────────────────────────
#
# Auto-adds managed repo paths to .gitignore so cloned repos are not
# tracked by the parent project. Called by sync when ensure-in-git-ignore
# is true (the default). Idempotent — skips if already present.

ensure_in_gitignore() {
    local path_to_ignore="$1"
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    local gitignore="${project_root}/.gitignore"

    path_to_ignore="${path_to_ignore%/}"
    local ignore_entry="/${path_to_ignore}"

    if [[ -f "$gitignore" ]]; then
        if grep -qxF "$ignore_entry" "$gitignore" || grep -qxF "$path_to_ignore" "$gitignore"; then
            return 0
        fi
    fi

    echo "" >> "$gitignore"
    echo "# Added by git-sync" >> "$gitignore"
    echo "$ignore_entry" >> "$gitignore"
    echo "  Added ${ignore_entry} to .gitignore"
}

# ── Sync ─────────────────────────────────────────────────────────────────────
#
# Clone missing repos and update existing ones to their configured state.
#
# For each repo in config:
#   1. Add path to .gitignore (if ensure-in-git-ignore is true)
#   2. Clone if missing (sparse clone when sparse-paths is set)
#   3. Check for dirty state (error if read-only, warn otherwise)
#   4. Apply mode: checkout-commit (fetch + checkout SHA) or
#      update-branch (checkout branch + pull)
#   5. Recurse into sub-repos that have their own .git-sync.yaml
#
# Functions:
#   sync_repo REPO_NAME  - sync a single repo
#   sync_all             - iterate all repos in all config files

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

    if [[ "$ensure_ignore" == "true" ]]; then
        ensure_in_gitignore "$path"
    fi

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

    # Recursive sync
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
            sync_repo "$repo_name" || had_errors=1
        done <<< "$repos"

        GIT_SYNC_CONFIG="$saved_config"
    done <<< "$config_files"

    if [[ $had_errors -ne 0 ]]; then
        echo ""
        echo "WARNING: some repos had errors during sync"
        return 1
    fi
}

# ── Snapshot ─────────────────────────────────────────────────────────────────
#
# Record the current branch and HEAD commit of each managed repo back into
# .git-sync.yaml. Runs automatically via the pre-commit hook so the config
# always reflects the pinned state when you commit.
#
# Repos with read-only: true are skipped entirely.
#
# When commit-tracked-files-on-parent-commit is true, dirty sub-repos have
# their tracked changes auto-committed (and optionally pushed) before the
# snapshot records their state.
#
# Functions:
#   auto_commit_tracked_files  - git add -u && commit in a sub-repo
#   snapshot_repo REPO MSG     - snapshot a single repo
#   snapshot_all [MSG]         - iterate all repos in all config files

GIT_SYNC_COMMIT_MESSAGE="${GIT_SYNC_COMMIT_MESSAGE:-git-sync: auto-commit tracked changes}"

auto_commit_tracked_files() {
    local repo_name="$1"
    local full_path="$2"
    local message="$3"
    local should_push="$4"
    local prefix="$5"

    cd "$full_path" || return 1

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

    cd "$full_path" || return 1
    local branch commit tag
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    commit=$(git rev-parse HEAD 2>/dev/null)
    tag=$(git describe --exact-match --tags HEAD 2>/dev/null)

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

    # Recursive snapshot
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

# ── Hooks ────────────────────────────────────────────────────────────────────
#
# Install/remove git hooks that automate sync and snapshot:
#   pre-commit  - runs "git-sync snapshot" (records state before each commit)
#   post-merge  - runs "git-sync sync" (updates deps after pull/merge)
#
# Appends to existing hooks rather than overwriting. Uses a marker comment
# to detect whether git-sync hooks are already installed.
#
# Functions:
#   install_hooks              - install both hooks
#   uninstall_hooks            - remove git-sync sections from both hooks
#   install_pre_commit_hook    - install/append pre-commit hook
#   install_post_merge_hook    - install/append post-merge hook
#   remove_hook FILE           - remove git-sync block from a hook file
#   find_git_sync_bin          - locate this script for hook references

HOOK_MARKER="# git-sync managed hook"

install_hooks() {
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    local hooks_dir="${project_root}/.git/hooks"

    install_pre_commit_hook "$hooks_dir"
    install_post_merge_hook "$hooks_dir"

    echo "Git hooks installed."
}

uninstall_hooks() {
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    local hooks_dir="${project_root}/.git/hooks"

    remove_hook "$hooks_dir/pre-commit"
    remove_hook "$hooks_dir/post-merge"

    echo "Git hooks removed."
}

install_pre_commit_hook() {
    local hooks_dir="$1"
    local hook_file="${hooks_dir}/pre-commit"

    if [[ -f "$hook_file" ]] && grep -q "$HOOK_MARKER" "$hook_file"; then
        echo "  pre-commit hook already installed"
        return 0
    fi

    local git_sync_bin
    git_sync_bin=$(find_git_sync_bin)

    local hook_content
    hook_content=$(cat <<'HOOKEOF'
#!/usr/bin/env bash
# git-sync managed hook
# Snapshots all managed repos before commit

HOOKEOF
)
    hook_content+=$'\n'"${git_sync_bin} snapshot"

    if [[ -f "$hook_file" ]]; then
        echo "" >> "$hook_file"
        echo "$hook_content" >> "$hook_file"
    else
        echo "$hook_content" > "$hook_file"
        chmod +x "$hook_file"
    fi

    echo "  Installed pre-commit hook"
}

install_post_merge_hook() {
    local hooks_dir="$1"
    local hook_file="${hooks_dir}/post-merge"

    if [[ -f "$hook_file" ]] && grep -q "$HOOK_MARKER" "$hook_file"; then
        echo "  post-merge hook already installed"
        return 0
    fi

    local git_sync_bin
    git_sync_bin=$(find_git_sync_bin)

    local hook_content
    hook_content=$(cat <<'HOOKEOF'
#!/usr/bin/env bash
# git-sync managed hook
# Syncs all managed repos after pull/merge

HOOKEOF
)
    hook_content+=$'\n'"${git_sync_bin} sync"

    if [[ -f "$hook_file" ]]; then
        echo "" >> "$hook_file"
        echo "$hook_content" >> "$hook_file"
    else
        echo "$hook_content" > "$hook_file"
        chmod +x "$hook_file"
    fi

    echo "  Installed post-merge hook"
}

remove_hook() {
    local hook_file="$1"
    if [[ -f "$hook_file" ]] && grep -q "$HOOK_MARKER" "$hook_file"; then
        sed -i.bak "/${HOOK_MARKER}/,\$d" "$hook_file"
        rm -f "${hook_file}.bak"
        echo "  Removed git-sync from $(basename "$hook_file")"
    fi
}

find_git_sync_bin() {
    if command -v git-sync &>/dev/null; then
        echo "git-sync"
        return
    fi
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -f "${project_root}/bin/git-sync.sh" ]]; then
        echo "${project_root}/bin/git-sync.sh"
        return
    fi
    echo "git-sync"
}

# ── CLI ──────────────────────────────────────────────────────────────────────
#
# Command-line interface: usage text, status display, and main dispatch.
#
# Commands: sync, snapshot, init, uninit, status, help
#
# Functions:
#   usage       - print help text
#   cmd_status  - display state of all managed repos
#   main        - parse args and dispatch to command handlers

usage() {
    cat <<EOF
git-sync - compose independent git repositories into a pseudo-monorepo

Usage: git-sync <command> [options]

Commands:
  sync              Clone missing repos and update all to configured state
  snapshot [-m msg]  Record current branch/commit into .git-sync.yaml
  init              Install git hooks (pre-commit snapshot, post-merge sync)
  uninit            Remove git-sync git hooks
  status            Show current state of all managed repos
  help              Show this help message

Configuration:
  Place a .git-sync.yaml file at your project root.
EOF
}

cmd_status() {
    local config_files
    config_files=$(all_config_files)

    if [[ -z "$config_files" ]]; then
        echo "No config files found in project root."
        return 1
    fi

    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

    while IFS= read -r config_name; do
        local saved_config="$GIT_SYNC_CONFIG"
        GIT_SYNC_CONFIG="$config_name"

        if [[ "$config_name" == "$GIT_SYNC_PRIVATE_CONFIG" ]]; then
            echo "=== Private config: ${config_name} ==="
            echo ""
        fi

        local repos
        repos=$(config_list_repos) || { GIT_SYNC_CONFIG="$saved_config"; continue; }

        while IFS= read -r repo_name; do
            local path mode read_only sparse_paths
            path=$(config_get "$repo_name" "path")
            mode=$(config_get "$repo_name" "mode")
            read_only=$(config_get_with_default "$repo_name" "read-only" "false")
            sparse_paths=$(config_get_list "$repo_name" "sparse-paths")
            local full_path="${project_root}/${path}"

            echo "--- ${repo_name} ---"
            echo "  Path: ${path}"
            echo "  Mode: ${mode}"
            if [[ "$read_only" == "true" ]]; then
                echo "  Read-only: yes"
            fi
            if [[ -n "$sparse_paths" ]]; then
                echo "  Sparse paths: ${sparse_paths//$'\n'/, }"
            fi

            if [[ ! -d "$full_path/.git" ]]; then
                echo "  State: NOT CLONED"
            else
                cd "$full_path"
                local branch commit dirty=""
                branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
                commit=$(git rev-parse --short HEAD 2>/dev/null)
                if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                    dirty=" (dirty)"
                fi
                echo "  Branch: ${branch}"
                echo "  Commit: ${commit}${dirty}"
                cd "$project_root"
            fi
            echo ""
        done <<< "$repos"

        GIT_SYNC_CONFIG="$saved_config"
    done <<< "$config_files"
}

main() {
    local command="${1:-help}"

    case "$command" in
        sync)
            config_exists || private_config_exists || { echo "No .git-sync.yaml or .git-sync-private.yaml found."; exit 1; }
            sync_all
            ;;
        snapshot)
            config_exists || private_config_exists || { echo "No .git-sync.yaml or .git-sync-private.yaml found."; exit 1; }
            shift
            local snapshot_message="$GIT_SYNC_COMMIT_MESSAGE"
            if [[ "${1:-}" == "-m" && -n "${2:-}" ]]; then
                snapshot_message="$2"
            fi
            snapshot_all "$snapshot_message"
            ;;
        init)
            install_hooks
            ;;
        uninit)
            uninstall_hooks
            ;;
        status)
            cmd_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
