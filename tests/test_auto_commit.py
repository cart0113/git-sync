"""
test_auto_commit.py - Tests for commit-tracked-files-on-parent-commit feature.

Covers: auto-commit dirty tracked files, custom message via -m,
default false behavior, untracked files left alone, recursive auto-commit.
"""

import tests.helpers as h


def _setup_auto_commit_repo(workspace, auto_commit=True):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"file.txt": "original content", "other.txt": "keep"})

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
            "commit-tracked-files-on-parent-commit": auto_commit,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml)
    h.run_git_sync(project_a, "sync")
    return project_a, bare_c, commit_c


def test_auto_commit_dirty_tracked_files(workspace):
    project_a, bare_c, original_commit = _setup_auto_commit_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "file.txt").write_text("modified content")

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "Auto-committing" in result.stdout
    assert "Auto-committed" in result.stdout

    # The sub-repo should now be clean
    status = h.run(["git", "status", "--porcelain"], cwd=cloned)
    assert status.stdout.strip() == ""

    # The .git-sync.yaml should have a NEW commit (not the original)
    yaml_content = (project_a / ".git-sync.yaml").read_text()
    new_commit = h.run(["git", "rev-parse", "HEAD"], cwd=cloned).stdout.strip()
    assert new_commit in yaml_content
    assert new_commit != original_commit


def test_auto_commit_with_custom_message(workspace):
    project_a, bare_c, _ = _setup_auto_commit_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "file.txt").write_text("changed for feature X")

    result = h.run(
        [h.GIT_SYNC_BIN, "snapshot", "-m", "feat: update for feature X"],
        cwd=project_a, check=False,
    )
    assert result.returncode == 0

    # Verify the sub-repo commit has the custom message with [via parent] prefix
    log = h.run(["git", "log", "-1", "--format=%s"], cwd=cloned)
    assert "feat: update for feature X" in log.stdout.strip()
    assert "[via " in log.stdout.strip()


def test_auto_commit_default_message(workspace):
    project_a, bare_c, _ = _setup_auto_commit_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "file.txt").write_text("some change")

    h.run_git_sync(project_a, "snapshot")

    log = h.run(["git", "log", "-1", "--format=%s"], cwd=cloned)
    assert "git-sync: auto-commit tracked changes" in log.stdout.strip()
    assert "[via " in log.stdout.strip()


def test_auto_commit_false_does_not_commit(workspace):
    project_a, bare_c, original_commit = _setup_auto_commit_repo(workspace, auto_commit=False)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "file.txt").write_text("dirty change")

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "Auto-committing" not in result.stdout
    assert "WARNING" in result.stdout
    assert "uncommitted" in result.stdout

    # The sub-repo should still be dirty
    status = h.run(["git", "status", "--porcelain"], cwd=cloned)
    assert status.stdout.strip() != ""

    # The .git-sync.yaml should still have the original commit
    yaml_content = (project_a / ".git-sync.yaml").read_text()
    assert original_commit in yaml_content


def test_auto_commit_ignores_untracked_files(workspace):
    project_a, bare_c, original_commit = _setup_auto_commit_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "brand_new_file.txt").write_text("untracked content")

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0

    # The untracked file should still be there and untracked
    status = h.run(["git", "status", "--porcelain"], cwd=cloned)
    assert "brand_new_file.txt" in status.stdout
    assert status.stdout.strip().startswith("??")

    # Commit should be the same (no tracked changes to commit)
    yaml_content = (project_a / ".git-sync.yaml").read_text()
    assert original_commit in yaml_content


def test_auto_commit_with_staged_and_unstaged(workspace):
    project_a, bare_c, original_commit = _setup_auto_commit_repo(workspace)

    cloned = project_a / "external-repos" / "project_C"
    (cloned / "file.txt").write_text("staged change")
    h.run(["git", "add", "file.txt"], cwd=cloned)
    (cloned / "other.txt").write_text("unstaged change to tracked file")

    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "Auto-committed" in result.stdout

    # Both tracked changes should be committed (git add -u catches both)
    status = h.run(["git", "status", "--porcelain"], cwd=cloned)
    assert status.stdout.strip() == ""

    new_commit = h.run(["git", "rev-parse", "HEAD"], cwd=cloned).stdout.strip()
    assert new_commit != original_commit


def test_auto_commit_clean_repo_no_commit(workspace):
    project_a, bare_c, original_commit = _setup_auto_commit_repo(workspace)

    # Don't dirty the repo — it should stay clean
    result = h.run_git_sync(project_a, "snapshot")
    assert result.returncode == 0
    assert "Auto-committing" not in result.stdout

    yaml_content = (project_a / ".git-sync.yaml").read_text()
    assert original_commit in yaml_content


def test_auto_commit_recursive(workspace):
    bare_c = h.make_bare_repo(workspace, "project_C")
    commit_c = h.populate_repo(bare_c, {"c.txt": "C content"})

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
            "commit-tracked-files-on-parent-commit": True,
        }
    })
    commit_b = h.populate_repo(bare_b, {"b.txt": "B content"}, git_sync_yaml=yaml_b)

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
            "commit-tracked-files-on-parent-commit": True,
        }
    })
    (project_a / ".git-sync.yaml").write_text(yaml_a)
    h.run_git_sync(project_a, "sync")

    # Dirty both B and C
    cloned_b = project_a / "external-repos" / "project_B"
    cloned_c = cloned_b / "external-repos" / "project_C"
    (cloned_b / "b.txt").write_text("B modified")
    (cloned_c / "c.txt").write_text("C modified")

    result = h.run(
        [h.GIT_SYNC_BIN, "snapshot", "-m", "chore: sync all"],
        cwd=project_a, check=False,
    )
    assert result.returncode == 0

    # Both should be auto-committed
    status_b = h.run(["git", "status", "--porcelain"], cwd=cloned_b)
    status_c = h.run(["git", "status", "--porcelain"], cwd=cloned_c)
    # B might show .git-sync.yaml as modified (snapshot updated it), that's expected
    # C should be fully clean
    assert "c.txt" not in status_c.stdout

    # C's commit message should contain the custom message with [via parent] prefix
    log_c = h.run(["git", "log", "-1", "--format=%s"], cwd=cloned_c)
    assert "chore: sync all" in log_c.stdout.strip()
    assert "[via " in log_c.stdout.strip()
