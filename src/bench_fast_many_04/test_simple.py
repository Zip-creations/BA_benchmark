import pytest


@pytest.mark.parametrize("case", range(100))
def test_simple(case):
    index = 0
    for i in range(10):
        index += 1
    assert index == 10
