# acme-engine: Using git-sync with Rust (Cargo path dependency)

This example shows a Rust application (`acme-engine`) that depends on a shared
crate (`acme-core`) living in a separate git repo. git-sync manages the
checkout; Cargo's `path` dependency makes it compilable.

## Project layout

```
acme-engine/                  # <-- main project (this repo)
├── .git-sync.yaml            # declares external repos
├── Cargo.toml                # workspace or package manifest
├── src/
│   └── main.rs
└── lib/                      # <-- git-sync puts checkouts here
    └── acme-core/            # cloned by git-sync (gitignored)
        ├── Cargo.toml
        └── src/
            └── lib.rs
```

## Step 1: .git-sync.yaml

```yaml
acme-core:
  path: lib/acme-core
  git-repo: git@github.com:acme-corp/acme-core.git
  mode: checkout-commit
  current-branch: main
  current-commit: d4e5f6a
  ensure-in-git-ignore: true
```

## Step 2: Cargo.toml — point at the local checkout

```toml
[package]
name = "acme-engine"
version = "0.1.0"
edition = "2021"

[dependencies]
acme-core = { path = "lib/acme-core" }
```

That's it. No sys.path hacks needed — Cargo natively supports path dependencies.
The local path takes priority over any crates.io version.

## Step 3: Use the crate (main.rs)

```rust
use acme_core::Config;

fn main() {
    let config = Config::load("settings.toml").unwrap();
    println!("Engine started: {}", config.name());
}
```

## Cargo also has native git dependencies — why use git-sync?

Cargo can pull git repos directly:

```toml
[dependencies]
acme-core = { git = "ssh://git@github.com/acme-corp/acme-core.git", branch = "main" }
```

**But this has the same problem as uv:** the source is cached internally
(`~/.cargo/git/`), not visible in your project tree. You can't browse, edit, or
grep it alongside your code.

| Concern                         | git-sync + path dep      | Cargo git dep                 |
| ------------------------------- | ------------------------ | ----------------------------- |
| **Source in your tree?**        | Yes, at `lib/acme-core/` | No — in `~/.cargo/git/`       |
| **Edit & recompile instantly?** | Yes                      | No — must publish or override |
| **Pin to exact commit?**        | Yes (`.git-sync.yaml`)   | Yes (`rev = "..."`)           |
| **Works with non-Rust repos?**  | Yes                      | No — must be a Cargo crate    |
| **Dependency resolution?**      | Manual for transitive    | Automatic via Cargo           |

## The pattern generalizes to any language

The git-sync approach is always the same two steps:

1. **git-sync checkouts** the repo into a known path (e.g., `lib/<name>/`)
2. **The language's build tool** references that local path

| Language   | Build tool     | Local dependency syntax                                                             |
| ---------- | -------------- | ----------------------------------------------------------------------------------- |
| Python     | sys.path / pip | `sys.path.insert(0, "lib/acme-utils")`                                              |
| Rust       | Cargo          | `acme-core = { path = "lib/acme-core" }`                                            |
| Go         | go.mod         | `replace github.com/acme/core => ./lib/acme-core`                                   |
| TypeScript | package.json   | `"acme-ui": "file:lib/acme-ui"`                                                     |
| C/C++      | CMake          | `add_subdirectory(lib/acme-core)`                                                   |
| Java       | Gradle         | `include ':acme-core'` + `project(':acme-core').projectDir = file('lib/acme-core')` |

The key insight: **git-sync handles the git operations (clone, pin, sync) while
the language's native build system handles the compilation/import.** Each tool
does what it's good at.

## When Cargo git deps are better

- The crate is **published on crates.io** with proper semver
- It has **deep transitive dependency trees** that Cargo should resolve
- You never edit the source — you just consume the API
- CI needs reproducible builds without cloning extra repos
