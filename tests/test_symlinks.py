"""
test_symlinks.py - Tests for symlink support.

Covers: symlinked git-sync binary, symlinked repo paths.
"""

import os

import tests.helpers as h


def test_symlinked_binary(workspace):
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

    # Create a symlink to git-sync in a different location
    symlink_dir = workspace / "symlinked_bin"
    symlink_dir.mkdir()
    symlink_path = symlink_dir / "git-sync"
    os.symlink(h.GIT_SYNC_BIN, str(symlink_path))

    # Run via the symlink
    result = h.run([str(symlink_path), "sync"], cwd=project_a, check=False)
    assert result.returncode == 0

    cloned = project_a / "external-repos" / "project_C"
    assert cloned.exists()
    assert (cloned / "file.txt").read_text() == "content"


def test_symlinked_binary_snapshot(workspace):
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

    symlink_dir = workspace / "symlinked_bin"
    symlink_dir.mkdir()
    symlink_path = symlink_dir / "git-sync"
    os.symlink(h.GIT_SYNC_BIN, str(symlink_path))

    # Sync then snapshot via symlink
    h.run([str(symlink_path), "sync"], cwd=project_a, check=False)
    result = h.run([str(symlink_path), "snapshot"], cwd=project_a, check=False)
    assert result.returncode == 0

    yaml_content = (project_a / ".git-sync.yaml").read_text()
    assert commit_c in yaml_content


def test_symlinked_binary_status(workspace):
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

    symlink_dir = workspace / "symlinked_bin"
    symlink_dir.mkdir()
    symlink_path = symlink_dir / "git-sync"
    os.symlink(h.GIT_SYNC_BIN, str(symlink_path))

    h.run([str(symlink_path), "sync"], cwd=project_a, check=False)
    result = h.run([str(symlink_path), "status"], cwd=project_a, check=False)
    assert result.returncode == 0
    assert "project-c" in result.stdout
