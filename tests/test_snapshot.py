"""
test_snapshot.py - Tests for git-sync snapshot command.

Covers: recording branch/commit, dirty repo warnings, detached HEAD.
"""

import subprocess

import tests.helpers as h


def _setup_with_cloned_repo(workspace):
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
    return project_a, bare_c, commit_c


def test_snapshot_records_branch_and_commit(workspace):
    project_a, bare_c, commit_c = _setup_with_cloned_repo(workspace)

    new_commit = h.add_commit_to_bare(bare_c, {"new.txt": "new"})
    cloned = project_a / "external-repos" / "project_C"
    h.run(["git", "pull"], cwd=cloned)

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0

    yaml_content = (project_a / ".git-sync.yaml").read_text()
    assert new_commit in yaml_content
    assert "main" in yaml_content


def test_snapshot_dirty_repo_warns(workspace):
    project_a, bare_c, commit_c = _setup_with_cloned_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "dirty_file.txt").write_text("uncommitted changes")
    h.run(["git", "add", "dirty_file.txt"], cwd=cloned)

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "uncommitted changes" in result.stdout


def test_snapshot_detached_head_keeps_branch(workspace):
    project_a, bare_c, commit_c = _setup_with_cloned_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    h.run(["git", "checkout", "--detach"], cwd=cloned)

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "Detached HEAD" in result.stdout

    yaml_content = (project_a / ".git-sync.yaml").read_text()
    assert "main" in yaml_content


def test_snapshot_not_cloned_skips(workspace):
    project_a = workspace / "project_A"
    project_a.mkdir()
    h.run(["git", "init"], cwd=project_a)
    h.run(["git", "commit", "--allow-empty", "-m", "init"], cwd=project_a)

    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "content"})

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

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "SKIP" in result.stdout


def test_snapshot_recursive(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"c.txt": "C"})

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
    h.run_git_sync(project_a, "sync")

    # Add a new commit to C, pull it in B's clone, then snapshot from A
    new_commit_c = h.add_commit_to_bare(bare_c, {"c_new.txt": "C new"})
    cloned_c = project_a / "external-repos" / "project_B" / "external-repos" / "project_C"
    h.run(["git", "pull"], cwd=cloned_c)

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "recursively" in result.stdout

    # Check that B's .git-sync.yaml was updated with C's new commit
    b_yaml = (project_a / "external-repos" / "project_B" / ".git-sync.yaml").read_text()
    assert new_commit_c in b_yaml
