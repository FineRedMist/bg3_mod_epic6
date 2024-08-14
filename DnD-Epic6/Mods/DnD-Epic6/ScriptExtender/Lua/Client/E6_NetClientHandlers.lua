NetClientHandlers = {}

function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    _E6P("Showing feat selector UI: peer=" .. tostring(peerId) .. ", player id=" .. payload)
    local message = Ext.Json.Parse(payload)

    E6_FeatSelectorUI(message)

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
