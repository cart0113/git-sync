"""
test_sync.py - Tests for git-sync sync command.

Covers: clone on missing, update-branch mode, checkout-commit mode,
recursive sync (A -> B -> C), and create-on-missing=false.
"""

import pathlib
import subprocess

import tests.helpers as h


def _setup_single_repo(workspace, mode, create_on_missing=True, ensure_in_git_ignore=True):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"README.txt": "hello from C"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": mode,
            "current-branch": "main",
            "current-commit": commit_c,
            "create-on-missing": create_on_missing,
            "ensure-in-git-ignore": ensure_in_git_ignore,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)
    return project_a, bare_c, commit_c


def test_sync_clone_update_branch(workspace):
    project_a, bare_c, commit_c = _setup_single_repo(workspace, "update-branch")
    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    cloned = project_a / "external-repos" / "project_C"
    assert cloned.exists()
    assert (cloned / "README.txt").read_text() == "hello from C"

    actual_commit = h.run(["git", "rev-parse", "HEAD"], cwd=cloned).stdout.strip()
    assert actual_commit == commit_c


def test_sync_clone_checkout_commit(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    first_commit = h.populate_repo(bare_c, {"v1.txt": "version 1"})
    second_commit = h.add_commit_to_bare(bare_c, {"v2.txt": "version 2"})

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "checkout-commit",
            "current-branch": "main",
            "current-commit": first_commit,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)

    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    cloned = project_a / "external-repos" / "project_C"
    actual_commit = h.run(["git", "rev-parse", "HEAD"], cwd=cloned).stdout.strip()
    assert actual_commit == first_commit
    assert (cloned / "v1.txt").exists()
    assert not (cloned / "v2.txt").exists()


def test_sync_update_branch_pulls_new_commits(workspace):
    project_a, bare_c, commit_c = _setup_single_repo(workspace, "update-branch")
    h.run_git_sync(project_a, "sync")

    new_commit = h.add_commit_to_bare(bare_c, {"new_file.txt": "new content"})

    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    cloned = project_a / "external-repos" / "project_C"
    actual_commit = h.run(["git", "rev-parse", "HEAD"], cwd=cloned).stdout.strip()
    assert actual_commit == new_commit
    assert (cloned / "new_file.txt").read_text() == "new content"


def test_sync_create_on_missing_false_skips(workspace):
    project_a, bare_c, commit_c = _setup_single_repo(
        workspace, "update-branch", create_on_missing=False
    )
    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    cloned = project_a / "external-repos" / "project_C"
    assert not cloned.exists()
    assert "SKIP" in result.stdout


def test_sync_ensure_in_git_ignore(workspace):
    project_a, bare_c, commit_c = _setup_single_repo(
        workspace, "update-branch", ensure_in_git_ignore=True
    )
    h.run_git_sync(project_a, "sync")

    gitignore = (project_a / ".gitignore").read_text()
    assert "external-repos/project_C" in gitignore


def test_sync_ensure_in_git_ignore_false(workspace):
    project_a, bare_c, commit_c = _setup_single_repo(
        workspace, "update-branch", ensure_in_git_ignore=False
    )
    h.run_git_sync(project_a, "sync")

    gitignore_path = project_a / ".gitignore"
    if gitignore_path.exists():
        assert "project_C" not in gitignore_path.read_text()


def test_sync_recursive_a_b_c(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"c_file.txt": "content from C"})

    bare_b = h.make_bare_repo(workspace, "project_B")
    yaml_b = h.make_git_sync_yaml({
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
    commit_b = h.populate_repo(bare_b, {"b_file.txt": "content from B"}, git_sync_yaml=yaml_b)

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml_a = h.make_git_sync_yaml({
        "project-b": {
            "path": "external-repos/project_B",
            "git-repo": str(bare_b),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_b,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml_a)

    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    # B should be cloned inside A
    cloned_b = project_a / "external-repos" / "project_B"
    assert cloned_b.exists()
    assert (cloned_b / "b_file.txt").read_text() == "content from B"

    # C should be cloned inside B (recursive!)
    cloned_c = cloned_b / "external-repos" / "project_C"
    assert cloned_c.exists()
    assert (cloned_c / "c_file.txt").read_text() == "content from C"

    # Verify recursive mention in output
    assert "recursively" in result.stdout


def test_sync_recursive_checkout_commit_mode(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c_v1 = h.populate_repo(bare_c, {"version.txt": "v1"})
    commit_c_v2 = h.add_commit_to_bare(bare_c, {"version.txt": "v2"})

    bare_b = h.make_bare_repo(workspace, "project_B")
    yaml_b = h.make_git_sync_yaml({
        "project-c": {
            "path": "external-repos/project_C",
            "git-repo": str(bare_c),
            "mode": "checkout-commit",
            "current-branch": "main",
            "current-commit": commit_c_v1,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    commit_b = h.populate_repo(bare_b, {"b.txt": "B"}, git_sync_yaml=yaml_b)

    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    yaml_a = h.make_git_sync_yaml({
        "project-b": {
            "path": "external-repos/project_B",
            "git-repo": str(bare_b),
            "mode": "update-branch",
            "current-branch": "main",
            "current-commit": commit_b,
            "create-on-missing": True,
            "ensure-in-git-ignore": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml_a)

    result = h.run_git_sync(project_a, "sync")
    assert result.returncode == 0

    # C should be pinned to v1, not v2
    cloned_c = project_a / "external-repos" / "project_B" / "external-repos" / "project_C"
    assert cloned_c.exists()
    actual = h.run(["git", "rev-parse", "HEAD"], cwd=cloned_c).stdout.strip()
    assert actual == commit_c_v1
    assert (cloned_c / "version.txt").read_text() == "v1"
