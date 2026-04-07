---
description: 'READ THIS FIRST — what context-db is and how to navigate it'
---

`context-db/` is a hierarchical Markdown knowledge base. Every `.md` file has
YAML frontmatter with a `description` field — the one-line summary shown in the
TOC.

## Navigating

Run `show_toc.sh` on any folder to see its contents:

```
show_toc.sh context-db/
show_toc.sh context-db/some-folder/
```

Each entry shows a description and path. Subfolder paths end with `/` — run
`show_toc.sh` on them to go deeper. Only open files whose descriptions are
relevant to your task.
