
--- @class Dequeue
--- @field first number The index of first entry in the queue
--- @field last number The index of the last entry in the queue
---A double-ended queue.
Dequeue = {}
Dequeue.__index = Dequeue

function Dequeue:new()
    local list = setmetatable({}, self)
    list.first = 0
    list.last = -1
    return list
end

function Dequeue:count()
    return self.last - self.first + 1
end

function Dequeue:pushleft(value)
    local first = self.first - 1
    self.first = first
    self[first] = value
end

function Dequeue:pushright(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

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