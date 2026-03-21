import pytest


@pytest.fixture
def workspace(tmp_path):
    return tmp_path
