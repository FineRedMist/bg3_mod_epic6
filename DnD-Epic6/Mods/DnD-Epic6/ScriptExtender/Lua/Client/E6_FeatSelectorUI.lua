
---@type ExtuiWindow?
local featUI = nil
local featDetailUI = nil

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

---comment
---@param feat table The feat to create the window for.
---@param playerInfo table The player id for the feat.
local function ShowFeatDetailSelectUI(feat, playerInfo)
    local windowDimensions = {1000, 1450}
    if not featDetailUI then
        local featDetails = Ext.Loca.GetTranslatedString("h43800b7agdc92g46b6g82dcg22fb987efe6c")
        featDetailUI = Ext.IMGUI.NewWindow(featDetails)
        featDetailUI.Closeable = true
        featDetailUI.NoMove = true
        featDetailUI.NoResize = true
        featDetailUI.NoCollapse = true
        featDetailUI:SetSize(windowDimensions)
        featDetailUI:SetPos({1400, 100})
    end

    featDetailUI.Visible = true
    featDetailUI.Open = true
    featDetailUI:SetFocus()

    local children = featDetailUI.Children
    for _, child in ipairs(children) do
        featDetailUI:RemoveChild(child)
    end

    local childWin = featDetailUI:AddChildWindow("Selection")
    childWin.Size = {windowDimensions[1], windowDimensions[2] - 150}
    childWin.PositionOffset = {0, 0}
    childWin.NoTitleBar = true
    local description = childWin:AddText(feat.Description)
    description.ItemWidth = windowDimensions[1] - 100
    local select = featDetailUI:AddButton(Ext.Loca.GetTranslatedString("h04f38549g65b8g4b72g834eg87ee8863fdc5"))
   
    select:SetStyle("ButtonTextAlign", 0.5, 0.5)
    -- Doesn't work :(
    select.OnActivate = function()
        local buttonWidth = select.ItemWidth
        local offset = select.PositionOffset
        if offset and buttonWidth then
            local newX = (windowDimensions[1] - 2 * offset[1] - buttonWidth) / 2
            select.PositionOffset = {newX, offset[2]}
        end
    end
    select.OnClick = function()
        featUI.Visible = false
        featUI.Open = false
        featDetailUI.Visible = false
        featDetailUI.Open = false

        local payload = {
            PlayerId = playerInfo.ID,
            Feat = {
                FeatId = feat.ID,
                PassivesAdded = feat.PassivesAdded
            }
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, payloadStr)
    end
end

---Creates a button in the feat selection window for the feat.
---@param win ExtuiWindow The window to close on completion.
---@param buttonWidth number The width of the button.
---@param playerInfo table The player id for the feat.
---@param feat table The feat to create the button for.
---@return ExtuiButton The button created.
local function MakeFeatButton(win, buttonWidth, playerInfo, feat)
    local featButton = win:AddButton(feat.DisplayName)
    featButton.Size = {buttonWidth-30, 48}
    featButton:SetStyle("ButtonTextAlign", 0.5, 0.5)
    featButton.OnClick = function()
        ShowFeatDetailSelectUI(feat, playerInfo)
    end
    return featButton
end

---@param message table
function E6_FeatSelectorUI(message)
    local windowDimensions = {500, 1450}
    CalculateLayout()

    if featUI == nil then
        local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8")
        featUI = Ext.IMGUI.NewWindow(featTitle)
        featUI.Closeable = true
        featUI.NoMove = true
        featUI.NoResize = true
        featUI.NoCollapse = true
        featUI:SetSize(windowDimensions)
        featUI:SetPos({800, 100})
    else
        featUI.Visible = true
        featUI.Open = true
    end
    featUI:SetFocus()

    local children = featUI.Children
    for _, child in ipairs(children) do
        featUI:RemoveChild(child)
    end

    local allFeats = E6_GatherFeats()

    local featList = {}
    local featMap = {}
    for _,featId in ipairs(message.SelectableFeats) do
        local feat = allFeats[featId]
        local featName = feat.DisplayName
        featMap[featName] = feat
        table.insert(featList, featName)
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
            MakeFeatButton(featUI, windowDimensions[1], { ID = message.PlayerId, Name = message.PlayerName, Abilities = message.Abilities }, feat)
        end
    end

end

