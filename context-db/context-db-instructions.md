---
description:
  How to read, write, and maintain this project's context-db — READ THIS FIRST
---

`context-db/` is this project's knowledge database — hierarchical Markdown with
on-demand TOCs via [context-db](https://github.com/cart0113/context-db).

## Reading

Run `bin/show_toc.sh context-db/` for the TOC. Each entry has a description and
path. `-toc.md` paths are subfolders — run `show_toc.sh` on them to go deeper.
Other paths are documents — read if relevant. Only fetch what you need.

## Writing

**Every insight dies with the session unless you write it down.** Non-obvious
knowledge — constraints, gotchas, decisions, patterns — belongs in context-db.
Treat updates as a first-class deliverable, not an afterthought.

Every `.md` file needs YAML frontmatter with a `description` field — the
one-line summary shown in the TOC. **This is the only thing agents see before
deciding to open a file.** Vague or stale descriptions actively mislead.

- **Documents**: frontmatter + body.
- **Folder descriptions** (`<foldername>.md`): frontmatter only — registers the
  folder in the TOC.
- Optional: `status: draft | stable | deprecated` (default: `stable`).

### Descriptions must be accurate

The `description` is a **complete, precise summary** — not a title. It must let
an agent decide relevance without opening the file. After any change, rewrite
affected descriptions to match current content exactly.

### Folder rule — 5–10 items per folder

The system depends on agents navigating the tree without reading everything.
Each level must be small enough to scan at a glance.

- **5–10 items per folder.** No exceptions.
- When a folder exceeds this, split into subfolders with meaningful hierarchy.
- On any update, reconsider whether the file still belongs and whether the
  folder has grown too large.

The folder tree is a decision tree: each node should halve the search space.

## Update checklist

After every session where you touched the codebase or learned something new:

1. **Capture** — Create or update documents with new knowledge.
2. **Summarize** — Rewrite every affected `description` to be accurate.
3. **Reorganize** — Check folder sizes; split or merge to stay at 5–10 items.
4. **Verify** — Run `bin/show_toc.sh` on affected folders. Does the TOC make
   sense to a cold reader in two hops? If not, fix it.
