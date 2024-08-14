
---@type ExtuiWindow?
local featUI = nil
local featDetailUI = nil

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

---Adds a tooltip to the target with the given text.
---@param target ExtuiStyledRenderable
---@param text string The text of the tooltip
local function AddTooltip(target, text)
    local tooltip = target:Tooltip()
    tooltip.IDContext = target.IDContext .. "_TOOLTIP"
    tooltip:AddText(text)
end

---Adds a tooltip to the target with a title and text.
---@param target ExtuiStyledRenderable
---@param title string The title of the tooltip
---@param text string The text of the tooltip
local function AddTooltipTitled(target, title, text)
    AddTooltip(target, title .. "\n\n" .. text)
end

---Adds a tooltip to the target with the given text.
---@param target ExtuiStyledRenderable
---@param textId string The id of the text in the localization system to lookup.
local function AddLocaTooltip(target, textId)
    local text = Ext.Loca.GetTranslatedString(textId)
    AddTooltip(target, TidyDescription(text))
end

---Adds a tooltip to the target with a title and text.
---@param target ExtuiStyledRenderable
---@param titleId string The title of the tooltip
---@param textId string The text of the tooltip
local function AddLocaTooltipTitled(target, titleId, textId)
    local title = Ext.Loca.GetTranslatedString(titleId)
    local text = Ext.Loca.GetTranslatedString(textId)
    AddTooltipTitled(target, TidyDescription(title), TidyDescription(text))
end

---Creates a table that facilitates centering an object through brute force.
---@param parent ExtuiTreeParent The container to add the table to
---@param uniqueName string A unique name for the table and columns.
---@param tableWidth number The width the table should be.
local function CreateCenteredControlCell(parent, uniqueName, tableWidth)
    local columnCount = 3
    local halfColumnCount = (columnCount - 1) / 2
    local table = parent:AddTable(uniqueName, columnCount)
    table.ItemWidth = tableWidth
    for i = 1, halfColumnCount do
        table:AddColumn(uniqueName .. "_" .. tostring(i), Ext.Enums.GuiTableColumnFlags.WidthStretch)
    end
    table:AddColumn(uniqueName .. "_center", Ext.Enums.GuiTableColumnFlags.WidthFixed)
    for i = halfColumnCount + 2, columnCount do
        table:AddColumn(uniqueName .. "_" .. tostring(i), Ext.Enums.GuiTableColumnFlags.WidthStretch)
    end
    local row = table:AddRow()
    for i = 1, halfColumnCount do
        row:AddCell()
    end
    local centerCell = row:AddCell()
    for i = halfColumnCount + 2, columnCount do
        row:AddCell()
    end
    return centerCell
end

---comment
---@param cell ExtuiTableCell
---@param feat table
local function AddPassivesToCell(cell, feat)
    local avoidDupes = {}
    for _,passive in ipairs(feat.PassivesAdded) do
        local passiveStat = Ext.Stats.Get(passive,  -1, true, true)
        local key = passiveStat.DisplayName .. "|" .. passiveStat.Description .. "|" .. passiveStat.Icon
        if not avoidDupes[key] then
            _E6P("Stat icon name for " .. feat.ShortName .. ": " .. passiveStat.Icon)
            local icon = cell:AddIcon(passiveStat.Icon)
            AddLocaTooltipTitled(icon, passiveStat.DisplayName, passiveStat.Description)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end
end

---The details panel for the feat.
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
    childWin.Size = {windowDimensions[1] - 30, windowDimensions[2] - 130}
    childWin.PositionOffset = {0, 0}
    childWin.NoTitleBar = true
    local description = childWin:AddText(TidyDescription(feat.Description))
    description.ItemWidth = windowDimensions[1] - 60
    pcall(function()
        -- This isn't in the standard bg3se yet. I have a PR for it at: https://github.com/Norbyte/bg3se/pull/431
        description.TextWrapPos = windowDimensions[1] - 60
    end)
    if #feat.PassivesAdded > 0 then
        childWin:AddSpacing()
        childWin:AddSeparator()
        childWin:AddSpacing()
        local passivesTitle = nil
        if #feat.PassivesAdded > 1 then
            passivesTitle = Ext.Loca.GetTranslatedString("h74d1322ag4c4dg42eag9272g066b84d0d374")
        else
            passivesTitle = Ext.Loca.GetTranslatedString("h099ebd82g6ea7g43b7gbf0fg69e32653f322")
        end
        local passiveTitleCell = CreateCenteredControlCell(childWin, "PassiveTitle", windowDimensions[1] - 60)
        passiveTitleCell:AddText(passivesTitle)
        local passivesCell = CreateCenteredControlCell(childWin, "Passives", windowDimensions[1] - 60)
        AddPassivesToCell(passivesCell, feat)
    end

    local centerCell = CreateCenteredControlCell(featDetailUI, "Select", windowDimensions[1] - 30)
    local select = centerCell:AddButton(Ext.Loca.GetTranslatedString("h04f38549g65b8g4b72g834eg87ee8863fdc5"))

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
    AddTooltip(featButton, TidyDescription(feat.Description))
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
        featUI.OnClose = function()
            if featDetailUI then
                featDetailUI.Visible = false
                featDetailUI.Open = false
            end
        end
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

