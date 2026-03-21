#!/usr/bin/env bash
#
# hooks.sh - Git hook installation for git-sync
#
# Installs pre-commit and post-merge hooks that automatically
# run snapshot (on commit) and sync (on pull/merge).

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

    # Find the git-sync binary relative to this project
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
        # Append to existing hook
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
        # Remove the git-sync block from the hook
        sed -i.bak "/${HOOK_MARKER}/,\$d" "$hook_file"
        rm -f "${hook_file}.bak"
        echo "  Removed git-sync from $(basename "$hook_file")"
    fi
}

find_git_sync_bin() {
    # Check if git-sync is in PATH
    if command -v git-sync &>/dev/null; then
        echo "git-sync"
        return
    fi
    # Fallback: look relative to the config file
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -f "${project_root}/bin/git-sync" ]]; then
        echo "${project_root}/bin/git-sync"
        return
    fi
    echo "git-sync"
}
