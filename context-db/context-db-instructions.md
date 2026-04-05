---
description: Discover and maintain project context via context-db TOC files
---

`context-db/` is this project's **context knowledge database** — hierarchical
Markdown files with auto-generated tables of contents, managed by
[context-db](https://github.com/cart0113/context-db).

## Reading

Start at `context-db/context-db-toc.md`. Each TOC entry has a description and a
path:

- Path ending in `-toc.md` → subfolder. Read that TOC to go deeper.
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
- Run `bin/build_toc.sh context-db/` to regenerate TOC files after changes.
  **Always pass `context-db/` as the argument.** Running without it scans the
  entire repo and generates spurious TOC files in any directory that has a
  `<dirname>.md` file (e.g., `docs/src/overview/overview.md`).
- **Never edit `-toc.md` files.** They are generated automatically.

Documents can optionally include `status: draft`, `status: stable`, or
`status: deprecated`. When omitted, the document is assumed stable. Non-stable
status appears in the TOC.
