#!/usr/bin/env bash
#
# config.sh - YAML config parsing for git-sync
#
# Reads .git-sync.yaml and provides functions to query repo entries.
# Requires yq (https://github.com/mikefarah/yq).

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
    yq 'keys | .[] | select(. != "_settings")' "$config"
}

config_get_setting_with_default() {
    local field="$1"
    local default_value="$2"
    local config
    config=$(config_file_path) || { echo "$default_value"; return; }
    local value
    value=$(yq ".\"_settings\".\"${field}\"" "$config" 2>/dev/null)
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

config_get() {
    local repo_name="$1"
    local field="$2"
    local config
    config=$(config_file_path) || return 1
    yq ".\"${repo_name}\".\"${field}\"" "$config"
}

config_set() {
    local repo_name="$1"
    local field="$2"
    local value="$3"
    local config
    config=$(config_file_path) || return 1
    yq -i ".\"${repo_name}\".\"${field}\" = \"${value}\"" "$config"
}

config_get_list() {
    local repo_name="$1"
    local field="$2"
    local config
    config=$(config_file_path) || return 1
    local value
    value=$(yq ".\"${repo_name}\".\"${field}\" // [] | .[]" "$config" 2>/dev/null)
    echo "$value"
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

check_yq_installed() {
    if ! command -v yq &>/dev/null; then
        echo "ERROR: yq is required but not installed." >&2
        echo "Install it: https://github.com/mikefarah/yq#install" >&2
        return 1
    fi
}
