# acme-app: Using git-sync with Python (sys.path approach)

This example shows a main Python application (`acme-app`) that depends on a
shared library (`acme-utils`) living in a separate git repo. git-sync manages
the checkout; `sys.path` makes it importable.

## Project layout

```
acme-app/                    # <-- main project (this repo)
├── .git-sync.yaml           # declares external repos
├── pyproject.toml            # optional — for acme-app's own deps
├── src/
│   └── app/
│       ├── __init__.py
│       ├── paths.py          # sys.path bootstrap
│       └── main.py           # application entry point
└── lib/                      # <-- git-sync puts checkouts here
    └── acme-utils/           # cloned by git-sync (gitignored)
        ├── acme_utils/
        │   ├── __init__.py
        │   └── formatting.py
        └── ...
```

## Step 1: .git-sync.yaml

```yaml
acme-utils:
  path: lib/acme-utils
  git-repo: git@github.com:acme-corp/acme-utils.git
  mode: checkout-commit
  current-branch: main
  current-commit: a1b2c3d
  ensure-in-git-ignore: true
```

## Step 2: Bootstrap sys.path (paths.py)

```python
"""
Add git-sync managed repos to sys.path.

Import this module before any external-repo imports.
Keeps path manipulation in one place so the rest of the
codebase uses normal imports.
"""
import sys
from pathlib import Path

_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # acme-app/
_EXTERNAL_LIBS = [
    _PROJECT_ROOT / "lib" / "acme-utils",
    # add more git-sync repos here
]

for lib in _EXTERNAL_LIBS:
    lib_str = str(lib)
    if lib_str not in sys.path:
        sys.path.insert(0, lib_str)
```

## Step 3: Use normal imports (main.py)

```python
import app.paths  # noqa: F401  — bootstraps sys.path

from acme_utils.formatting import bold, header

def main():
    print(header("ACME Report"))
    print(bold("Status:"), "all systems nominal")

if __name__ == "__main__":
    main()
```

## Day-to-day workflow

```bash
# First time (or after pulling changes that update .git-sync.yaml):
git-sync sync

# Work normally — imports just work:
python -m app.main

# Pin to a new version of acme-utils:
cd lib/acme-utils && git pull && cd ../..
git-sync snapshot   # records new commit SHA in .git-sync.yaml
git add .git-sync.yaml && git commit -m "bump acme-utils"
```

## Why not uv / pip for this?

| Concern                              | sys.path + git-sync                         | uv git dep                                      |
| ------------------------------------ | ------------------------------------------- | ----------------------------------------------- |
| **acme-utils needs pyproject.toml?** | No — any directory with `__init__.py` works | Yes — must be a proper package                  |
| **Source visible in your tree?**     | Yes, at `lib/acme-utils/`                   | No — buried in uv cache                         |
| **Can edit & test changes locally?** | Yes — just edit the files                   | Must clone separately, then `uv pip install -e` |
| **Works if acme-utils is private?**  | Yes — git-sync uses your git credentials    | Yes — but uv needs SSH/token config too         |
| **Dependency resolution?**           | Manual — you manage transitive deps         | Automatic — uv resolves the full graph          |

## When this approach is the right call

- The shared repo is **not a proper Python package** (no
  setup.py/pyproject.toml)
- You want to **read and edit** the dependency source alongside your app
- The dependency is **internal/small** — a handful of utility modules, not a
  framework with 50 transitive deps
- You're sharing **mixed content** (Python + configs + scripts + docs)

## When uv/pip is better

- The dependency is a **real published package** with its own release cycle
- It has **transitive dependencies** that need resolution (e.g., it depends on
  `requests`, `pydantic`, etc.)
- You never need to see or edit the source — you just want to `import` it
- Multiple teams consume it and need **semver compatibility guarantees**
