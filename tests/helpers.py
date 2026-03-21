"""
helpers.py - Shared fixtures for git-sync tests.

Provides helpers to create bare repos, populate them with content and
.git-sync.yaml configs, and run git-sync commands against them.
"""

import os
import shutil
import subprocess
import pathlib

import pytest


PROJECT_ROOT = pathlib.Path(__file__).parent.parent
GIT_SYNC_BIN = str(PROJECT_ROOT / "bin" / "git-sync")


def run(cmd, cwd, check=True, capture=True):
    result = subprocess.run(
        cmd,
        cwd=str(cwd),
        capture_output=capture,
        text=True,
        check=False,
        env={**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@test.com",
             "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@test.com"},
    )
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(
            result.returncode, cmd, result.stdout, result.stderr
        )
    return result


def make_bare_repo(base_path, name):
    bare_path = base_path / "bare" / f"{name}.git"
    bare_path.mkdir(parents=True, exist_ok=True)
    run(["git", "init", "--bare"], cwd=bare_path)
    return bare_path


def populate_repo(bare_path, files, git_sync_yaml=None):
    tmp_work = bare_path.parent / f"_populate_{bare_path.stem}"
    if tmp_work.exists():
        shutil.rmtree(tmp_work)
    run(["git", "clone", str(bare_path), str(tmp_work)], cwd=bare_path.parent)

    for name, content in files.items():
        filepath = tmp_work / name
        filepath.parent.mkdir(parents=True, exist_ok=True)
        filepath.write_text(content)

    if git_sync_yaml:
        (tmp_work / ".git-sync.yaml").write_text(git_sync_yaml)

    run(["git", "add", "-A"], cwd=tmp_work)
    run(["git", "commit", "-m", "initial commit"], cwd=tmp_work)
    run(["git", "push"], cwd=tmp_work)
    commit_sha = run(["git", "rev-parse", "HEAD"], cwd=tmp_work).stdout.strip()
    shutil.rmtree(tmp_work)
    return commit_sha


def add_commit_to_bare(bare_path, files):
    tmp_work = bare_path.parent / f"_addcommit_{bare_path.stem}"
    if tmp_work.exists():
        shutil.rmtree(tmp_work)
    run(["git", "clone", str(bare_path), str(tmp_work)], cwd=bare_path.parent)
    for name, content in files.items():
        filepath = tmp_work / name
        filepath.parent.mkdir(parents=True, exist_ok=True)
        filepath.write_text(content)
    run(["git", "add", "-A"], cwd=tmp_work)
    run(["git", "commit", "-m", "additional commit"], cwd=tmp_work)
    run(["git", "push"], cwd=tmp_work)
    commit_sha = run(["git", "rev-parse", "HEAD"], cwd=tmp_work).stdout.strip()
    shutil.rmtree(tmp_work)
    return commit_sha


def run_git_sync(cwd, command):
    return run([GIT_SYNC_BIN, command], cwd=cwd, check=False)


def make_git_sync_yaml(entries):
    lines = []
    for name, fields in entries.items():
        lines.append(f"{name}:")
        for k, v in fields.items():
            if isinstance(v, bool):
                lines.append(f"  {k}: {'true' if v else 'false'}")
            else:
                lines.append(f"  {k}: {v}")
    return "\n".join(lines) + "\n"


@pytest.fixture
def workspace(tmp_path):
    return tmp_path
