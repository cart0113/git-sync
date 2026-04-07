# git-sync vs Package Managers

A common question: why not use a language package manager (uv, pip, Cargo, npm)
to manage cross-repo dependencies instead of git-sync?

Short answer: they solve different problems. Package managers install
_packages_. git-sync checks out _repositories_.

## What uv/pip can do

Python's [uv](https://docs.astral.sh/uv/) can declare a git repo as a
dependency:

```toml
# pyproject.toml
[project]
dependencies = ["acme-utils"]

[tool.uv.sources]
acme-utils = { git = "https://github.com/acme/acme-utils", branch = "main" }
```

uv clones the repo internally, builds the package, and installs it into your
virtual environment. You can pin to a branch, tag, or commit SHA.

Cargo does the same for Rust:

```toml
[dependencies]
acme-core = { git = "ssh://git@github.com/acme/acme-core.git", rev = "a1b2c3d" }
```

## What they cannot do

### The repo must be a proper package

uv requires a `pyproject.toml` or `setup.py`. Cargo requires a `Cargo.toml`. If
the shared repo is a collection of scripts, configs, docs, or mixed-language
code, package managers won't touch it.

### No source checkout in your project tree

Both uv and Cargo cache the source internally (`~/.cache/uv/`, `~/.cargo/git/`).
The code is not visible alongside your project. You cannot grep across it,
browse it in your editor, or make quick local edits.

uv explicitly rejects editable installs from git URLs:

> _"Editable must refer to a local directory, not a Git URL."_

To get an editable install, you must clone the repo yourself first — which is
what git-sync does for you.

### `[tool.uv.sources]` is uv-only

The git source configuration lives in a uv-specific section of `pyproject.toml`.
Other tools (pip, poetry, pdm) ignore it. This creates lock-in to uv's toolchain
for anyone consuming your project.

### Language-specific

uv handles Python. Cargo handles Rust. npm handles JavaScript. None of them
handle "I need this repo's bash scripts alongside my Python app." git-sync is
language-agnostic.

## When each tool is the right choice

| Scenario                                                      | Use          |
| ------------------------------------------------------------- | ------------ |
| Shared repo is not a proper package                           | **git-sync** |
| You need to read/edit the dependency source                   | **git-sync** |
| Mixed content (Python + scripts + configs)                    | **git-sync** |
| Shared repo has no transitive dependencies                    | **git-sync** |
| Co-developing both repos simultaneously                       | **git-sync** |
| Dependency has deep transitive deps (requests, pydantic, ...) | **uv / pip** |
| Dependency is published with semver releases                  | **uv / pip** |
| Multiple teams consume it as a black-box API                  | **uv / pip** |
| You never look at the dependency source                       | **uv / pip** |

## They compose well together

git-sync and package managers are not mutually exclusive. A typical setup:

- **uv** manages published third-party packages (requests, numpy, etc.)
- **git-sync** manages internal repos you actively co-develop

```yaml
# .git-sync.yaml — internal shared code
acme-utils:
  path: lib/acme-utils
  git-repo: git@github.com:acme-corp/acme-utils.git
  mode: checkout-commit
  current-commit: a1b2c3d
```

```toml
# pyproject.toml — published third-party deps
[project]
dependencies = ["requests", "pydantic"]
```

```python
# paths.py — make git-sync checkouts importable
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib" / "acme-utils"))
```

Use both. Let each tool do what it is good at.
