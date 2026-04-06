---
description: Discover and maintain project context via context-db
---

`context-db/` is this project's **context knowledge database** — hierarchical
Markdown files with on-demand tables of contents, managed by
[context-db](https://github.com/cart0113/context-db).

## Reading

Run `bin/show_toc.sh context-db/` to see the top-level table of contents. Each
TOC entry has a description and a path:

- Path ending in `-toc.md` → subfolder. Run `bin/show_toc.sh` on that subfolder
  to go deeper (e.g., `bin/show_toc.sh context-db/some-folder/`).
- Any other path → document. Read it if the description is relevant to your
  task.

Only fetch what you need. Use descriptions to skip irrelevant branches entirely.

## IMPORTANT: Writing Back to the Context-DB

**You are expected to update the context-db when you learn something
important.**

When you discover architecture decisions, non-obvious patterns, constraints,
gotchas, data model relationships, or anything a future agent would need to work
safely on this codebase — add it to the context-db. If you had to figure it out
the hard way, it belongs there.

When creating or updating context documents:

- **New document**: YAML frontmatter with `description`, then markdown content.
- **New folder**: create `<foldername>.md` with only YAML frontmatter:
  `description: <one-line summary>`. This marks the folder as a context node.
- **Descriptions are critical.** The description is the only thing an agent sees
  in the TOC. Write the most useful, concise summary possible.
- **Fix stale content.** If a context document contradicts the current code,
  correct it or remove it.
- TOC files are generated on the fly by `bin/show_toc.sh` — you do not need to
  regenerate anything after adding or editing documents.

Documents can optionally include `status: draft`, `status: stable`, or
`status: deprecated`. When omitted, the document is assumed stable. Non-stable
status appears in the TOC.
