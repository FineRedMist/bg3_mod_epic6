NetClientHandlers = {}

function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    _E6P("Showing feat selector UI: peer=" .. tostring(peerId) .. ", player id=" .. payload)
    local ent = Ext.Entity.Get(payload)
    if ent == nil then
        _E6Error("Failed to get entity for player id: " .. payload)
        return
    end
    --if userCharacter then
    --    local MCMModVars = Ext.Vars.GetModVariables(ModuleUUID)
    --    if updateNotificationStatus(userId, MCMModVars) then
    --        showTroubleshootingNotification(userCharacter)
    --    end
    --else
    --    MCMDebug(1, "Failed to show notification - userCharacter is nil")
    --end
end

return NetClientHandlers
