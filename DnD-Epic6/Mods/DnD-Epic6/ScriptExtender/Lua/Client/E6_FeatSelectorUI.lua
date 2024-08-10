
---@type ExtuiWindow?
local win = nil

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

local function FeatDetailSelectUI()
    local win = Ext.IMGUI.NewWindow("Feat Detail")
    win.Closeable = true
    win.AlwaysAutoResize = true
    win:SetFocus()
    win.Visible = true
    win.Open = true
    win.UserData = nil
    return win
end
---Creates a button in the feat selection window for the feat.
---@param win ExtuiWindow The window to close on completion.
---@param buttonWidth number The width of the button.
---@param playerId string The player id for the feat.
---@param feat table The feat to create the button for.
---@return ExtuiButton The button created.
local function MakeFeatButton(win, buttonWidth, playerId, feat)
    local featButton = win:AddButton(feat.DisplayName)
    featButton.UserData = feat
    featButton.Size = {buttonWidth-30, 40}
    featButton:SetStyle("ButtonTextAlign", 0.5, 0.5)
    featButton.OnClick = function()
        win.Visible = false
        win.Open = false
        win.UserData = nil

        local payload = {
            PlayerId = playerId,
            Feat = {
                FeatId = feat.ID,
                PassivesAdded = feat.PassivesAdded
            }
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, payloadStr)
    end
    return featButton
end

---@param message table
function E6_FeatSelectorUI(message)
    local windowDimensions = {500, 1450}
    CalculateLayout()

    if win == nil then
        local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8")
        win = Ext.IMGUI.NewWindow(featTitle)
        win.Closeable = true
        win.NoMove = true
        win.NoResize = true
        win.NoCollapse = true
        win:SetSize(windowDimensions)
        win:SetPos({800, 100})
    else
        win.Visible = true
        win.Open = true
    end
    win.OnClose = function()
        win.UserData = nil
    end
    win:SetFocus()

    win.UserData = message
    local children = win.Children
    for _, child in ipairs(children) do
        win:RemoveChild(child)
        child:Destroy()
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
            MakeFeatButton(win, windowDimensions[1], message.PlayerId, feat)
        end
    end

end

