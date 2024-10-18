-- Cribbed from the Mod Configuration Menu

---@class CommandRegistry A mapping of network channels to commands to execute.
---@field commands table<string,NetCommand> A mapping of the network channel to the command to execute.
-- Command registry, used to register and execute commands over network channels.
CommandRegistry = {}
CommandRegistry.__index = CommandRegistry

---@return CommandRegistry Creates a new CommandRegistry.
function CommandRegistry:new()
    local registry = setmetatable({}, self)
    registry.commands = {}
    return registry
end

---Registers a command function to apply when on a given channel is received.
---@param channel string The channel to listen for.
---@param command NetCommand The function to call when the channel receives a message.
function CommandRegistry:register(channel, command)
    self.commands[channel] = command
end

---Executes the registered command for the given channel with the provided payload and peerId.
---@param channel string The channel the message was received for.
---@param payload string The data received.
---@param peerId integer The peer id that sent the message. 
function CommandRegistry:execute(channel, payload, peerId)
    if self.commands[channel] then
        self.commands[channel]:execute(channel, payload, peerId)
    end
end

---Registers the command registry to listen for all of the registered channels.
---@param registry CommandRegistry
function RegisterNetListeners(registry)
    local function handleNetMessage(channel, payload, peerId)
        registry:execute(channel, payload, peerId)
    end

    for channel, _ in pairs(registry.commands) do
        Ext.RegisterNetListener(channel, handleNetMessage)
    end
end

return CommandRegistry
