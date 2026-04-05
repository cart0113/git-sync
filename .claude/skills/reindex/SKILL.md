---
name: reindex
description: Rebuild all context-db TOC files for the project
---

Rebuild the context-db table-of-contents index files.

Run:

```bash
/Users/ajcarter/workspace/GIT_CONTEXT_DB/bin/build_toc.sh context-db/
```

**Always pass `context-db/` as the argument.** Running without it scans the
entire repo and generates spurious TOC files in non-context-db directories.

Report which TOC files were rebuilt.
