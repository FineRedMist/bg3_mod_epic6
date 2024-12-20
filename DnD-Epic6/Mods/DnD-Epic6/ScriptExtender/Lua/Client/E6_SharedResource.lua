--- @class SharedResource A resource shared between multiple options to determine when the resource still has pending choices or is completely consumed.
--- @field count number The current count of the shared resource.
--- @field capacity number The initial count of the shared resource.
--- @field callbacks function[] The callbacks to be executed when the shared resource changes.
--- Represents a shared resource that notifies when the shared resource changes.
SharedResource = {}
SharedResource.__index = SharedResource

--- Creates a new SharedResource instance.
--- @param count number The initial count of the shared resource.
--- @param max number? The maximum count of the shared resource, or nil to use the count
--- @return SharedResource
function SharedResource:new(count, max)
    local res = setmetatable({}, self)
    res.count = count
    if max then
        res.capacity = max
    else
        res.capacity = count
    end
    res.callbacks = {}
    return res
end

--- Executes the command.
--- @param func function A function that takes two booleans: hasResources and resourcesAtCapacity.
function SharedResource:add(func)
    table.insert(self.callbacks, func)
end

---Triggers the callbacks regardless of whether the state has changed (useful for initialization).
function SharedResource:trigger()
    local hasResources = self.count > 0
    local resourcesAtCapacity = self.count == self.capacity
    for _,callback in ipairs(self.callbacks) do
        callback(hasResources, resourcesAtCapacity)
    end
end

---Acquires a resource from the shared resource. Triggers callbacks if the value changes.
---@return boolean Whether the resource was acquired.
function SharedResource:AcquireResource()
    if self.count > 0 then
        self.count = self.count - 1
        self:trigger()
        return true
    end
    return false
end

---Releases a resource to the shared resource. Triggers callbacks if the value changes.
---@return boolean Whether the resource was released.
function SharedResource:ReleaseResource()
    if self.count < self.capacity then
        self.count = self.count + 1
        self:trigger()
        return true
    end
    return false
end

return SharedResource
