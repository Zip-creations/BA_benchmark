from classes.ToDoList import ToDoList, ToDoItem
import pytest

def test_add_item(record_property):
    todo_list = ToDoList()
    item1 = ToDoItem("Item 1")
    item2 = ToDoItem("Item 2")
    todo_list.addItem(item1)
    todo_list.addItem(item2)
    assert len(todo_list.items) == 2
    assert todo_list.items[0] == item1
    assert todo_list.items[1] == item2

    record_property("example_key", 1)  # adds a custom property inside the <testcase> element in the JUnit XML report
    # output in JUnit XML:
    # <properties>
    #   <property name="example_key" value="1" />
    # </properties>

def test_removing_items():
    todo_list = ToDoList()
    item1 = ToDoItem("Item 1")
    item2 = ToDoItem("Item 2")
    todo_list.addItem(item1)
    assert todo_list.items[0] == item1
    todo_list.addItem(item2)
    assert todo_list.items[1] == item2
    todo_list.removeItemByID(0)
    with pytest.raises(KeyError):
        _ = todo_list.items[0]
    assert len(todo_list.items) == 1
    assert 0 not in todo_list.items
    assert 1 in todo_list.items

@pytest.mark.skip(reason="this test will be skipped, to see how pytest handles skipped tests in JUnit XML reports")
def test_skipping():
    assert True

def test_simple():
    assert "foo" != "bar"

def test_simple_two():
    assert 1 + 1 == 2
