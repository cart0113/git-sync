---
description:
  Why language package managers (uv, pip, Cargo, npm) are not substitutes for
  git-sync
---

# git-sync vs Package Managers

## They solve different problems

Package managers install _packages_. git-sync checks out _repositories_.

Tools like Python's `uv`, Rust's Cargo, or npm can declare git repos as
dependencies. But they cache the source internally — the code is not visible in
your project tree. You cannot grep, browse, or edit it alongside your code.

## Key limitations of uv/pip for this use case

- **Target must be a proper Python package** — requires `pyproject.toml` or
  `setup.py`. A folder of scripts, configs, or mixed-language code fails.
- **No source checkout in your tree** — code lives in `~/.cache/uv/` or
  `site-packages/`, not next to your project.
- **Editable git installs rejected** — uv explicitly refuses
  `uv add -e git+https://...`. You must clone the repo yourself first, then
  point uv at the local path — which is what git-sync does.
- **`[tool.uv.sources]` is uv-only** — pip, poetry, pdm ignore it. Lock-in to
  one toolchain.
- **Language-specific** — uv handles Python. Cargo handles Rust. Neither handles
  "I need this repo's bash scripts alongside my Python app."

## When package managers are the right choice

- Dependency is a **published package** with semver releases
- It has **deep transitive deps** that need automatic resolution
- Multiple teams consume it as a **black-box API**
- You never need to see or edit the source

## When git-sync is the right choice

- Shared repo is **not a proper package** (no setup.py/pyproject.toml)
- You need to **read/edit** the dependency source alongside your app
- **Mixed content** — Python + shell scripts + configs + docs
- **Co-developing** both repos simultaneously
- Shared repo has **no transitive dependencies**

## They compose well

Use both. uv manages published third-party packages (requests, numpy). git-sync
manages internal repos you actively co-develop. The integration pattern is
always the same: git-sync checks out the repo, the language's build tool
references the local path.

| Language   | Local dependency syntax                           |
| ---------- | ------------------------------------------------- |
| Python     | `sys.path.insert(0, "lib/acme-utils")`            |
| Rust       | `acme-core = { path = "lib/acme-core" }`          |
| Go         | `replace github.com/acme/core => ./lib/acme-core` |
| TypeScript | `"acme-ui": "file:lib/acme-ui"`                   |
| C/C++      | `add_subdirectory(lib/acme-core)`                 |
