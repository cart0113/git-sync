---
description:
  How to read, write, and maintain this project's context-db — READ THIS FIRST
---

`context-db/` is this project's knowledge database — hierarchical Markdown with
on-demand TOCs via [context-db](https://github.com/cart0113/context-db).

## The prime directive

**Every insight dies with the session unless you write it down.** If you
discovered something non-obvious — an architecture constraint, a gotcha, a
design decision, a pattern — it belongs in context-db. No future agent should
have to rediscover what you already learned. Treat context-db updates as a
first-class deliverable of every session, not an afterthought.

## Reading

Run `bin/show_toc.sh context-db/` for the TOC. Each entry has a description and
path. `-toc.md` paths are subfolders — run `show_toc.sh` on them to go deeper.
Other paths are documents — read if relevant. Only fetch what you need.

## Writing — store what you learn

Every `.md` file requires YAML frontmatter with a `description` field — the
one-line summary shown in the TOC. **This is the only thing agents see before
deciding whether to open a file.** A vague or stale description is worse than no
file at all — it actively misleads every future agent.

- **Documents** have frontmatter + body.
- **Folder descriptions** (`<foldername>.md`) have frontmatter only — they
  register the folder in the TOC.
- Optional: `status: draft | stable | deprecated` (default: `stable`).

## Descriptions must be fully comprehensive and accurate

The `description` field is not a title — it is a **complete, precise summary**
of the file's content. It must tell an agent everything they need to decide
relevance _without opening the file_. After ANY change — new file, edit, rename,
delete — re-read every affected `description` and rewrite it to match the
current content exactly. A description that lags behind the body is a lie in the
TOC. Fix it immediately.

## Logarithmic progressive disclosure — the folder rule

The entire system depends on agents navigating the tree _without reading
everything_. This only works if each level of the hierarchy is small enough to
scan at a glance:

- **5–10 items per folder.** No exceptions.
- When a folder grows beyond this, **stop and refactor** — split content into
  subfolders that add a meaningful layer of hierarchy.
- When you update file contents, **also reconsider folder structure.** Does this
  file still belong here? Has the folder grown too large? Would a subfolder make
  the TOC clearer? Restructuring is not a chore — it is how the database stays
  navigable at scale.

Think of the folder tree as a decision tree: at each node an agent should face a
small, clear set of choices that halve the search space. If a TOC is too long to
scan in seconds, the structure is broken.

## The update checklist — run this before you finish

After every session where you touched the codebase or learned something new:

1. **Capture** — Write down new knowledge. Create or update documents.
2. **Summarize** — Rewrite every affected `description` to be fully accurate.
3. **Reorganize** — Check folder sizes. Split, merge, or move files so the tree
   stays balanced and each TOC stays at 5–10 items.
4. **Verify** — Run `bin/show_toc.sh` on affected folders and read the output.
   Does the TOC make sense to a cold reader? Would a new agent find what they
   need in two hops? If not, fix it now.
