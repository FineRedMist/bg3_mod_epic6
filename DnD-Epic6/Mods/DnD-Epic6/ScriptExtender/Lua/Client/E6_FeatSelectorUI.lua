
---@type ExtuiWindow?
local win = nil

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

---@param message table
function E6_FeatSelectorUI(message)

    CalculateLayout()

    if win == nil then
        local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8")
        win = Ext.IMGUI.NewWindow(featTitle)
        win.Closeable = true
        win.AlwaysAutoResize = true
    else
        win.Visible = true
        win.Open = true
    end
    win:SetFocus()

    win.UserData = message
    local children = win.Children
    for _, child in ipairs(children) do
        win:RemoveChild(child)
    end

    local allFeats = E6_GatherFeats()

    local featList = {}
    local featMap = {}
    for featId, feat in pairs(allFeats) do
        if feat.CanBeTakenMultipleTimes or message.PlayerFeats[featId] == nil then
            local featName = feat.DisplayName
            featMap[featName] = feat
            table.insert(featList, featName)
        end
    end

    message.FeatMap = featMap

    table.sort(featList, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    for _, featName in ipairs(featList) do
        local feat = featMap[featName]
        if feat == nil then
            _E6Error("Failed to find feat for name: " .. featName)
        else
            local featButton = win:AddButton(featName)
            local featId = feat.ID
            featButton.OnClick = function()
                win.Visible = false
                win.Open = false
                win.UserData = nil


                local payload = {
                    PlayerId = message.PlayerId,
                    Feat = {
                        FeatId = featId,
                        PassivesAdded = feat.PassivesAdded
                    }
                }
                local payloadStr = Ext.Json.Stringify(payload)
                Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, payloadStr)
            end
        end
    end
end