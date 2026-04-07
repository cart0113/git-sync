#!/usr/bin/env bash
#
# show_toc.sh — Print the table of contents for any folder to stdout.
#
# Scans a directory for Markdown files with YAML frontmatter `description`
# fields and prints them as a TOC. No gate checks — works on any folder.
#
# Usage:
#   show_toc.sh context-db/                     Top-level TOC
#   show_toc.sh context-db/some-folder/         Subfolder TOC
#
# Subfolders are listed if they contain <folder-name>.md with frontmatter.
# Files are listed if they have a `description` in their frontmatter.
# Files named <dirname>.md are skipped (they are folder descriptions).
#
# Output format:
#   ## Subfolders
#   - description: ...
#     path: subfolder/
#
#   ## Files
#   - description: ...
#     path: filename.md
#
# Requirements: bash 3.2+, awk

set -eo pipefail

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

    # Subfolder entries — look for <subfolder>/<subfolder>.md
    local folder_lines=""
    for subdir in "$dir"/*/; do
        [ -d "$subdir" ] || continue
        local subname
        subname=$(basename "$subdir")
        should_skip "$subname" && continue

        local sub_desc_file="$subdir/${subname}.md"
        [ -f "$sub_desc_file" ] || continue

        local sdesc sstatus
        sdesc=$(read_desc "$sub_desc_file")
        [ -z "$sdesc" ] && sdesc="(no description)"
        sstatus=$(read_status "$sub_desc_file")
        if [ -n "$sstatus" ] && [ "$sstatus" != "stable" ]; then
            sdesc="${sdesc} [${sstatus}]"
        fi
        folder_lines="${folder_lines}"$'\n'"- description: ${sdesc}"$'\n'"  path: ${subname}/"
    done

    # File entries — any .md with frontmatter, skip <dirname>.md (folder desc)
    local dirname
    dirname=$(basename "$(cd "$dir" && pwd -P)")
    local file_lines=""
    for md_file in "$dir"/*.md; do
        [ -f "$md_file" ] || continue
        local fname
        fname=$(basename "$md_file")
        [ "$fname" = "${dirname}.md" ] && continue
        should_skip "$fname" && continue

        local fdesc
        fdesc=$(read_desc "$md_file")
        [ -z "$fdesc" ] && continue

        local fstatus
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
