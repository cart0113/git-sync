---
description: How to read, write, and maintain this project's context-db
---

`context-db/` is this project's knowledge database — hierarchical Markdown with
on-demand TOCs via [context-db](https://github.com/cart0113/context-db).

## Reading

Run `bin/show_toc.sh context-db/` for the TOC. Each entry has a description and
path. `-toc.md` paths are subfolders — run `show_toc.sh` on them to go deeper.
Other paths are documents — read if relevant. Only fetch what you need.

## Writing — store what you learn

**This is a living knowledge base, not a snapshot.** When you discover
architecture decisions, non-obvious patterns, constraints, or gotchas during a
session — store them here. Think of it like persistent memory: if you figured
something out the hard way, a future agent shouldn't have to.

Every `.md` file requires YAML frontmatter with `description` — the one-line
summary shown in the TOC. This is how agents decide what to read without opening
files.

**Documents** have frontmatter + body. **Folder descriptions**
(`<foldername>.md`) have frontmatter only — they register the folder in the TOC.

## Frontmatter must stay current

After ANY change — new file, edit, rename, delete — ensure every affected file's
`description` accurately reflects its content. Stale descriptions actively
mislead future agents. This is the most important maintenance rule.

Optional: `status: draft | stable | deprecated` (default: `stable`).
