NetClientHandlers = {}

function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    _E6P("Showing feat selector UI: peer=" .. tostring(peerId) .. ", player id=" .. payload)
    local ent = Ext.Entity.Get(payload)
    if ent == nil then
        _E6Error("Failed to get entity for player id: " .. payload)
        return
    end

    local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8")
    local win = Ext.IMGUI.NewWindow(featTitle)
    win.Closeable = true
    win.AlwaysAutoResize = true
    win:AddText("Select a feat to learn for: " .. ent.CharacterCreationStats.Name)
    local button = win:AddButton("Close")
    button.OnClick = function()
       win:Destroy()
    end
    win:SetFocus()

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
