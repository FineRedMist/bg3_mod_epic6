NetServerHandlers = {}

function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
    --MCMDebug(1, "User is spamming MCM button; showing troubleshooting notification")
    --local userId = MCMUtils:PeerToUserID(peerId)
    --local userCharacter = MCMUtils:GetUserCharacter(userId)
    --if userCharacter then
    --    local MCMModVars = Ext.Vars.GetModVariables(ModuleUUID)
    --    if updateNotificationStatus(userId, MCMModVars) then
    --        showTroubleshootingNotification(userCharacter)
    --    end
    --else
    --    MCMDebug(1, "Failed to show notification - userCharacter is nil")
    --end
end

return NetServerHandlers
