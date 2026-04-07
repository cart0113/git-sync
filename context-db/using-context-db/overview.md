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

## Integration Paths

There are three ways to wire context-db into a project. Each one needs to tell
the agent where `show_toc.sh` lives and to run it before starting work.

**AGENTS.md** — Put an `AGENTS.md` in the project root. The script lives at
`bin/show_toc.sh`. This is the simplest option and works with any agent that
reads `AGENTS.md`. See `templates/AGENTS.md`.

**Rule** — Add a `.claude/rules/context-db.md` file. Same as AGENTS.md but
loaded automatically by Claude Code without needing AGENTS.md. The script lives
at `bin/show_toc.sh`. See `templates/rules/context-db.md`.

**Skill** — Add a `context-db` skill under `.claude/skills/`. The script lives
at `${CLAUDE_SKILL_DIR}/scripts/show_toc.sh` (bundled with the skill). This is
the most self-contained option — no `bin/` directory needed. See
`templates/skills/context-db/`.

All three approaches are equivalent. Pick whichever fits your project. You can
combine them (e.g., AGENTS.md for general agents + skill for Claude Code).
