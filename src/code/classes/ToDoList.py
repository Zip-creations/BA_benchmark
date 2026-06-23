class ToDoItem:
    def __init__(self, item: str):
        self.item = item
    
    def __eq__(self, other):
        if not isinstance(other, ToDoItem):
            return NotImplemented
        return self.item == other.item

class ToDoList:
    def __init__(self):
        self.items: dict[int, ToDoItem] = {}
        self.id = -1

    def newID(self):
        self.id += 1
        return self.id

    def addItem(self, item: ToDoItem):
        self.items[self.newID()] = item

    def removeItemByID(self, id: int):
        del self.items[id]
    
    def copy(self):
        new_list = ToDoList()
        for item in self.items.values():
            new_list.addItem(item)
        return new_list

    def __eq__(self, other):
        if not isinstance(other, ToDoList):
            return NotImplemented
        return self.items == other.items
    
    def __ne__(self, other):
        if not isinstance(other, ToDoList):
            return NotImplemented
        return not self.__eq__(other)
