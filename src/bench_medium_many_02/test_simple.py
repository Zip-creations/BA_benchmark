import pytest


@pytest.mark.parametrize("case", range(1000))
def test_simple(case):
    index = 0
    for i in range(10000):
        index += 1
    assert index == 10000
