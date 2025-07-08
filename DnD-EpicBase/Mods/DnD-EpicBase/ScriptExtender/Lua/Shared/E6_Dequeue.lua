
--- @class Dequeue A double-ended queue.
--- @field first number The index of first entry in the queue
--- @field last number The index of the last entry in the queue
---A double-ended queue.
Dequeue = {}
Dequeue.__index = Dequeue

---Creates a new double-ended queue.
---@return Dequeue The double ended queue.
function Dequeue:new()
    local list = setmetatable({}, self)
    list.first = 0
    list.last = -1
    return list
end

---The number of elements in the queue.
---@return number The number of elements in the queue.
function Dequeue:count()
    return self.last - self.first + 1
end

---Pushes a value onto the left side of the queue.
---@param value any The value to push onto the left side of the queue.
function Dequeue:pushleft(value)
    local first = self.first - 1
    self.first = first
    self[first] = value
end

---Pushes a value onto the right side of the queue.
---@param value any The value to push onto the right side of the queue.
function Dequeue:pushright(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

---Pops an entry from the left side of the queue.
---@return any The value popped from the left side of the queue.
function Dequeue:popleft()
    local first = self.first
    if first > self.last then
        error "list is empty"
    end
    local value = self[first]
    self[first] = nil        -- to allow garbage collection
    self.first = first + 1
    return value
end

---Pops an entry from the right side of the queue.
---@return any The value popped from the right side of the queue.
function Dequeue:popright()
    local last = self.last
    if self.first > last then
        error "list is empty"
    end
    local value = self[last]
    self[last] = nil         -- to allow garbage collection
    self.last = last - 1
    return value
end

return Dequeue