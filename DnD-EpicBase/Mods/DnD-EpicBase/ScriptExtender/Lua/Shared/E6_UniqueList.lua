-- Cribbed from the Mod Configuration Menu

---@class UniqueList A list that ensures all items are unique.
-- @field encountered table<any, boolean> A mapping of items to whether they have been added to the list.
---@field items List<any> The list of items added in the order they were added.
-- UniqueList, used to ensure that all items in the list are unique.
UniqueList = {}
UniqueList.__index = UniqueList

---@return UniqueList Creates a new UniqueList.
function UniqueList:new()
    local list = setmetatable({}, self)
    list.encountered = {}
    list.items = {}
    return list
end

---Adds an item uniquely to the list
---@param item any The item to add to the list.
function UniqueList:add(item)
    if self.encountered[item] == nil then
        self.encountered[item] = true
        table.insert(self.items, item)
    end
end

return UniqueList
