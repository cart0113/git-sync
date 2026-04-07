---
description: git-sync internals — how sync, snapshot, and hooks work
---

git-sync is a bash-only tool for composing independent git repositories into a
pseudo-monorepo, requiring only bash 4+ and git. Read `overview.md` for what it
is and why it exists, then `architecture.md` for the sync/snapshot/hooks
pipeline. `config-format.md` documents every `.git-sync.yaml` field and mode.
`design-principles.md` explains the zero-dependency philosophy, and
`bash-conventions.md` covers the single-file coding patterns. See
`private-config.md` for personal gitignored dependencies and
`vs-package-managers.md` for when to use git-sync versus uv/pip/Cargo/npm.
