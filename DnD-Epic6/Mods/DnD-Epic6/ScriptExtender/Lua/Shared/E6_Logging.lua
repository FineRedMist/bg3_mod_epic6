---@param message string A normal log message.
function _E6P(message)
    local hostType = "Client"
    if(Ext.IsServer()) then
        hostType = "Server"
    end
    _P("E6[" .. hostType .. "]: " .. message)
end

---@param message string A warning message to log.
function _E6Warn(message)
    local hostType = "Client"
    if(Ext.IsServer()) then
        hostType = "Server"
    end
    Ext.Utils.PrintWarning("E6[" .. hostType .. "]: " .. message)
end

---@param message string An error message to log.
function _E6Error(message)
    local hostType = "Client"
    if(Ext.IsServer()) then
        hostType = "Server"
    end
    Ext.Utils.PrintError("E6[" .. hostType .. "]: " .. message)
end
