#!/usr/bin/env bash
#
# show_toc.sh — Print the table of contents for a context-db folder to stdout.
#
# Usage:
#   bin/show_toc.sh context-db/                     Top-level TOC
#   bin/show_toc.sh context-db/some-folder/         Subfolder TOC
#
# The agent calls this on the root context-db/ folder first, then recursively
# on subfolders as it navigates deeper — same browsing pattern as reading
# static -toc.md files, but generated on the fly so symlinked/private folders
# appear automatically without committing anything.
#
# Output format matches the existing -toc.md format:
#   ## Subfolders
#   - description: ...
#     path: subfolder/subfolder-toc.md
#
#   ## Files
#   - description: ...
#     path: filename.md
#
# Requirements: bash 3.2+, awk

set -eo pipefail

DESC_NAMES="SKILL.md CONTEXT.md AGENT.md AGENTS.md"

# ── Parsing ───────────────────────────────────────────────────────────────────

read_field() {
    local file="$1" field="$2"
    local val
    val=$(awk -v key="$field" '
        /^---$/ { fc++; next }
        fc == 1 && found && /^[[:space:]]/ {
            sub(/^[[:space:]]+/, "")
            if (val != "") val = val " "
            val = val $0
            next
        }
        fc == 1 && found { gsub(/^["'"'"']|["'"'"']$/, "", val); print val; done=1; exit }
        fc == 1 && $0 ~ "^" key ":" {
            sub("^" key ":[[:space:]]*", "")
            if ($0 != "") { gsub(/^["'"'"']|["'"'"']$/, ""); print; done=1; exit }
            found = 1; val = ""
        }
        fc >= 2 { if (found) { gsub(/^["'"'"']|["'"'"']$/, "", val); print val }; done=1; exit }
        END { if (!done && found) { gsub(/^["'"'"']|["'"'"']$/, "", val); print val } }
    ' "$file")
    [ -z "$val" ] && val=$(awk -v key="$field" '
        /^```yaml description/ { in_b=1; next }
        in_b && /^```/ { if (found) { gsub(/^["'"'"']|["'"'"']$/, "", val); print val }; done=1; exit }
        in_b && found && /^[[:space:]]/ {
            sub(/^[[:space:]]+/, "")
            if (val != "") val = val " "
            val = val $0
            next
        }
        in_b && found { gsub(/^["'"'"']|["'"'"']$/, "", val); print val; done=1; exit }
        in_b && $0 ~ "^" key ":" {
            sub("^" key ":[[:space:]]*", "")
            if ($0 != "") { gsub(/^["'"'"']|["'"'"']$/, ""); print; done=1; exit }
            found = 1; val = ""
        }
        END { if (!done && found) { gsub(/^["'"'"']|["'"'"']$/, "", val); print val } }
    ' "$file")
    echo "$val"
}

read_desc() { read_field "$1" "description"; }
read_status() { read_field "$1" "status"; }

find_desc_file() {
    local dir="$1" name
    name=$(basename "$(cd "$dir" && pwd -P)")
    [ -f "$dir/${name}.md" ] && { echo "$dir/${name}.md"; return 0; }
    [ -f "$dir/${name}-instructions.md" ] && { echo "$dir/${name}-instructions.md"; return 0; }
    local f
    for f in $DESC_NAMES; do
        [ -f "$dir/$f" ] && { echo "$dir/$f"; return 0; }
    done
    return 1
}

should_skip() {
    case "$1" in _*|.*) return 0 ;; esac
    return 1
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    local dir="${1:-.}"
    # Strip trailing slash for consistency
    dir="${dir%/}"

    if [ ! -d "$dir" ]; then
        echo "Error: '$dir' is not a directory" >&2
        exit 1
    fi

    local desc_file
    desc_file=$(find_desc_file "$dir") || {
        echo "Error: '$dir' is not a context-db folder (no description file found)" >&2
        exit 1
    }

    local foldername desc_fname
    foldername=$(basename "$dir")
    desc_fname=$(basename "$desc_file")

    # Subfolder entries
    local folder_lines=""
    for subdir in "$dir"/*/; do
        [ -d "$subdir" ] || continue
        local subname
        subname=$(basename "$subdir")
        should_skip "$subname" && continue

        local sub_desc
        sub_desc=$(find_desc_file "$subdir") || continue

        local sdesc sstatus
        sdesc=$(read_desc "$sub_desc")
        [ -z "$sdesc" ] && sdesc="(no description)"
        sstatus=$(read_status "$sub_desc")
        if [ -n "$sstatus" ] && [ "$sstatus" != "stable" ]; then
            sdesc="${sdesc} [${sstatus}]"
        fi
        folder_lines="${folder_lines}"$'\n'"- description: ${sdesc}"$'\n'"  path: ${subname}/${subname}-toc.md"
    done

    # File entries (skip description file and any existing toc file)
    local file_lines=""
    for md_file in "$dir"/*.md; do
        [ -f "$md_file" ] || continue
        local fname
        fname=$(basename "$md_file")
        [ "$fname" = "$desc_fname" ] && continue
        [ "$fname" = "${foldername}-toc.md" ] && continue
        should_skip "$fname" && continue

        local fdesc fstatus
        fdesc=$(read_desc "$md_file")
        [ -z "$fdesc" ] && fdesc="(no description)"
        fstatus=$(read_status "$md_file")
        if [ -n "$fstatus" ] && [ "$fstatus" != "stable" ]; then
            fdesc="${fdesc} [${fstatus}]"
        fi

        file_lines="${file_lines}"$'\n'"- description: ${fdesc}"$'\n'"  path: ${fname}"
    done

    # Print
    if [ -n "$folder_lines" ]; then
        printf '%s\n%s\n' "## Subfolders" "$folder_lines"
    fi
    if [ -n "$file_lines" ]; then
        [ -n "$folder_lines" ] && printf '\n'
        printf '%s\n%s\n' "## Files" "$file_lines"
    fi
}

main "$@"
