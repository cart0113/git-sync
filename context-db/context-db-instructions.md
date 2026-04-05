---
description:
  How to navigate and maintain this project's context knowledge database
---

## context-db

`context-db/` is this project's **context knowledge database** — hierarchical
Markdown files with auto-generated tables of contents, managed by
[context-db](https://github.com/cart0113/context-db).

### Structure

Example structure below. All folder and file names are abstract placeholders —
name yours to match your content:

```
context-db/
├── context-db-instructions.md      ← you are here
├── context-db-toc.md               ← generated — never edit
├── my-project/
│   ├── my-project.md               ← folder description
│   ├── my-project-toc.md           ← generated
│   ├── topic-a/
│   │   ├── topic-a.md              ← folder description
│   │   ├── topic-a-toc.md          ← generated
│   │   ├── document-1.md           ← document (frontmatter + body)
│   │   └── document-2.md
│   └── topic-b/
│       ├── topic-b.md
│       ├── topic-b-toc.md
│       └── ...
└── standards/
    ├── standards.md
    ├── standards-toc.md
    └── ...
```

Every `.md` file has YAML frontmatter with a `description` — a one-line summary
of what it covers. Every folder with a description file gets an auto-generated
`-toc.md` listing its contents by description and path.

The `description` is the only thing shown in the TOC. It is how an agent decides
whether to read a file without opening it. Write descriptions that make this
decision easy.

### Reading

Start at `context-db-toc.md`. Each TOC entry has a description and a path:

- Path ending in `-toc.md` → subfolder. Read that TOC to go deeper.
- Any other path → document. Read it if the description is relevant to your
  task.

Only fetch what you need. Use descriptions to skip irrelevant branches entirely.

### Writing

There are two kinds of `.md` files in the context tree:

**Documents** — frontmatter plus a markdown body. When you create or edit a
document, keep its `description` accurate so future reads are correctly
filtered.

```yaml
---
description: What this covers and why you'd read it
---
# Title

(content)
```

**Folder descriptions** — `<foldername>.md` with frontmatter only, no body.
These register the folder as a context node so it appears in the parent TOC.

```yaml
---
description: What this folder covers
---
```

**Never edit `-toc.md` files.** They are built automatically from descriptions
by `bin/build_toc.sh`.

### Optional: status

Documents can include a `status` field: `draft`, `stable`, or `deprecated`. When
omitted, the document is assumed stable. Non-stable status appears in the TOC so
agents can see it without opening the file.

```yaml
---
description: Legacy payment processing flow
status: deprecated
---
```

### IMPORTANT: Maintaining the context knowledge database

**This is not optional.** The context-db is a living knowledge base, not a
snapshot. You are expected to keep it current. Stale context is worse than
missing context — a future agent will act on outdated information with
confidence.

**Update the context-db when you learn something important.** Architecture
decisions, non-obvious patterns, constraints, gotchas, data model relationships,
service boundaries, deployment quirks — if you had to figure it out the hard
way, it belongs here. When you finish a task that revealed something a future
agent would need, add or update the relevant context document. Keep descriptions
in frontmatter accurate so the TOC stays useful.

**Flag and fix stale content.** When you read a context document that
contradicts the current code, describes something that no longer exists, or
would lead an agent to a wrong decision — correct it or remove it immediately.

**Reorganize when needed.** When a document covers multiple distinct topics or a
folder's TOC has grown past a quick scan, move content into a subfolder. This
creates a new TOC node — a new level of progressive disclosure. This directly
improves how well a future agent can filter what it reads.

**After any change** to context files:

1. Make sure the `description` in its frontmatter still matches the content.
2. If you created a new folder, add the `<foldername>.md` description file.
3. If a document was deleted or moved, update any references to it in other
   documents.
