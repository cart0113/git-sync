---
description: How to add documents and folders — frontmatter rules, descriptions
---

Every `.md` file requires YAML frontmatter with a `description` field:

```yaml
---
description: One-line summary shown in the TOC
---
```

Optional: `status: draft | stable | deprecated` (default: `stable`).

## File types

- **Documents** — frontmatter + body.
- **Folder descriptions** (`<folder-name>.md`) — frontmatter only, no body.
  Registers the folder in the parent's TOC.

## Descriptions must be accurate

The `description` is a **complete, precise summary** — not a title. It must let
an agent decide relevance without opening the file. After any change, rewrite
affected descriptions to match current content exactly.
