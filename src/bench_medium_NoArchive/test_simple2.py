import pytest


@pytest.mark.parametrize("case", range(10))
def test_simple(case):
    index = 0
    for i in range(1000000):
        index += 1
    assert index == 1000000
