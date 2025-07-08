-- Cribbed from the Mod Configuration Menu

--- @class NetCommand A network command that can be executed.
--- @field callback function The callback function to be executed when the command is executed.
--- Represents a (net) command that can be executed.
NetCommand = {}
NetCommand.__index = NetCommand

--- Creates a new NetCommand instance.
--- @param callback function The callback function to be executed when the command is executed.
--- @return NetCommand
function NetCommand:new(callback)
    local cmd = setmetatable({}, self)
    cmd.callback = callback
    return cmd
end

--- Executes the command.
--- @param channel string The channel of the command.
--- @param payload string? The payload of the command.
--- @param peerId integer The peer ID of the command.
function NetCommand:execute(channel, payload, peerId)
    self.callback(channel, payload, peerId)
end

return NetCommand
