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

### Frontmatter Is Required — Always Keep It Updated

Every file and folder in context-db has YAML frontmatter with a `description`
field. **This is not optional.** The description is the only thing agents see in
the TOC — it determines whether they read or skip a document.

**When you change anything in context-db, you MUST update the frontmatter:**

- **Editing a document**: If the content's scope or focus changed, update the
  `description` to match. A stale description is worse than no description —
  it actively misleads future agents.
- **Creating a new document**: Always include YAML frontmatter with
  `description`, then markdown content.
- **Creating a new folder**: Create `<foldername>.md` with only YAML
  frontmatter: `description: <one-line summary>`. This marks the folder as a
  context node.
- **Renaming or moving**: Update descriptions in the moved items and in any
  parent folder description files if scope changed.
- **Deleting**: Remove the corresponding description file if it becomes empty
  or irrelevant.

### Content Maintenance

- **Descriptions are critical.** Write the most useful, concise summary
  possible — this is the agent's only signal for relevance.
- **Fix stale content.** If a context document contradicts the current code,
  correct it or remove it.
- Documents can optionally include `status: draft`, `status: stable`, or
  `status: deprecated`. When omitted, the document is assumed stable. Non-stable
  status appears in the TOC.
- TOC files are generated on the fly by `bin/show_toc.sh` — you do not need to
  regenerate anything after adding or editing documents.
