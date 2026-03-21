#!/usr/bin/env bash
#
# gitignore.sh - .gitignore management for git-sync
#
# Ensures that synced repo paths are listed in the project's .gitignore
# when ensure-in-git-ignore is true.

ensure_in_gitignore() {
    local path_to_ignore="$1"
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    local gitignore="${project_root}/.gitignore"

    # Normalize: strip trailing slash, ensure leading slash for root-relative path
    path_to_ignore="${path_to_ignore%/}"
    local ignore_entry="/${path_to_ignore}"

    if [[ -f "$gitignore" ]]; then
        # Check if already present (with or without leading slash)
        if grep -qxF "$ignore_entry" "$gitignore" || grep -qxF "$path_to_ignore" "$gitignore"; then
            return 0
        fi
    fi

    echo "" >> "$gitignore"
    echo "# Added by git-sync" >> "$gitignore"
    echo "$ignore_entry" >> "$gitignore"
    echo "  Added ${ignore_entry} to .gitignore"
}
