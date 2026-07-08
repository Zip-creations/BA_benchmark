import pytest


@pytest.mark.parametrize("case", range(9))
def test_simple(case):
    index = 0
    for i in range(100):
        index += 1
    assert index == 100
