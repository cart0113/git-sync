"""
test_edge_cases.py - Tests for edge cases and config options.

Covers: dirty repos during sync, status command, gitignore idempotency,
unknown mode, missing config, multiple repos in one config.
"""

import tests.helpers as h


def test_sync_dirty_repo_warns(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)
    h.run_git_sync(project_a, "sync")

    # Make the cloned repo dirty
    cloned = project_a / "external-repos" / "project_C"
    (cloned / "dirty.txt").write_text("dirty")
    h.run(["git", "add", "dirty.txt"], cwd=cloned)

    result = h.run_git_sync(project_a, "sync")
    assert "WARNING" in result.stdout
    assert "uncommitted" in result.stdout


def test_status_shows_cloned_repos(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)
    h.run_git_sync(project_a, "sync")

    result = h.run_git_sync(project_a, "status")
    assert result.returncode == 0
    assert "project-c" in result.stdout
    assert "main" in result.stdout
    assert commit_c[:7] in result.stdout


def test_status_not_cloned(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)

    result = h.run_git_sync(project_a, "status")
    assert result.returncode == 0
    assert "NOT CLONED" in result.stdout


def test_status_dirty_repo(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)
    h.run_git_sync(project_a, "sync")

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "dirty.txt").write_text("dirty")
    h.run(["git", "add", "dirty.txt"], cwd=cloned)

    result = h.run_git_sync(project_a, "status")
    assert "dirty" in result.stdout


def test_gitignore_idempotent(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)

    h.run_git_sync(project_a, "sync")
    h.run_git_sync(project_a, "sync")
    h.run_git_sync(project_a, "sync")

    gitignore = (project_a / ".gitignore").read_text()
    count = gitignore.count("external-repos/project_C")
    assert count == 1


def test_multiple_repos_in_config(workspace):
    bare_b = h.make_bare_repo(workspace, "project_B")
    commit_b = h.populate_repo(bare_b, {"b.txt": "B content"})

    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"c.txt": "C content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-b": {
            "path": "external-repos/project_B",
            "git-repo": str(bare_b),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_b,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        },
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "checkout-commit",
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        },
    })
    (project_a / ".git-sync.yaml").write_text(yaml)

    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    assert (project_a / "external-repos" / "project_B" / "b.txt").read_text() == "B content"
    assert (project_a / "external-repos" / "project_C" / "c.txt").read_text() == "C content"


def test_no_config_file_errors(workspace):
    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    result = h.run_git_sync(project_a, "sync")
    assert result.returncode != 0
    assert "No .git-sync.yaml found" in result.stdout


def test_sync_then_snapshot_roundtrip(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": "placeholder",
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)

    h.run_git_sync(project_a, "sync")
    h.run_git_sync(project_a, "snapshot")

    yaml_after = (project_a / ".git-sync.yaml").read_text()
    assert commit_c in yaml_after
    assert "placeholder" not in yaml_after
