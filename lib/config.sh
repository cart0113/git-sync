#!/usr/bin/env bash
#
# config.sh - YAML config parsing for git-sync
#
# Reads .git-sync.yaml and provides functions to query repo entries.
# Requires yq (https://github.com/mikefarah/yq).

GIT_SYNC_CONFIG=".git-sync.yaml"

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

config_list_repos() {
    local config
    config=$(config_file_path) || return 1
    yq 'keys | .[]' "$config"
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

check_yq_installed() {
    if ! command -v yq &>/dev/null; then
        echo "ERROR: yq is required but not installed." >&2
        echo "Install it: https://github.com/mikefarah/yq#install" >&2
        return 1
    fi
}
