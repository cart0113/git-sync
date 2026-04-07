#!/usr/bin/env bash
#
# config.sh - Config parsing for git-sync
#
# Reads .git-sync.yaml using pure bash/awk. No external dependencies.
#
# The config format is a constrained YAML subset:
#   - Top-level keys are section names (repo names or _settings)
#   - Each section has flat key: value pairs (2-space indent)
#   - One list type: key:\n    - item (4-space indent with dash)
#   - No nested objects, anchors, aliases, or flow syntax

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

# List top-level keys (repo names), excluding _settings and comments
config_list_repos() {
    local config
    config=$(config_file_path) || return 1
    awk '/^[^[:space:]#]/ && !/^_settings:/ { sub(/:.*/, ""); print }' "$config"
}

# Get a scalar value: section.field
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

# Set a scalar value in-place: section.field = value
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

# Get list items (e.g., sparse-paths) as newline-separated values
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
