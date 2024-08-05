NetClientHandlers = {}

function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    _E6P("Showing feat selector UI: peer=" .. tostring(peerId) .. ", player id=" .. payload)
    local userId = PeerToUserID(peerId)
    local userCharacter = GetUserCharacter(userId)
    local ent = Ext.Entity.Get(userCharacter)
    if ent == nil then
        _E6Error("Failed to get entity for player id: " .. payload)
        return
    end

    E6_FeatSelectorUI(ent)
    
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
