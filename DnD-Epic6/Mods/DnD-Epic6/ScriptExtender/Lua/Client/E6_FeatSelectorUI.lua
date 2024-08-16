
---@type ExtuiWindow?
local featUI = nil
---@type ExtuiWindow?
local featDetailUI = nil
---@type number
local uiHasFocusCount = 0

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

local abilityPassives = {
    Strength = {
        ShortName = "h1579d774gdbcdg4a97gb3fage409138d104d",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_1",
        Description = "haaf3959ag320eg4f68ga9c9gc143d7f64a8c",
        Icon = "E6_Ability_Strength" },
    Dexterity = {
        ShortName = "h8d7356d7g4c37g41e4gb8a2gef3459e12b97",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_2",
        Description = "hbf128ebdgdfffg4ea9gbf4bg1659ccefd287",
        Icon = "E6_Ability_Dexterity" },
    Constitution = {
        ShortName = "h20676a9ag9216g47dbgba3ag82bd734cfd53",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_3",
        Description = "h7a02f64dg4593g408fgbf93gb0dbabc182c9",
        Icon = "E6_Ability_Constitution" },
    Intelligence = {
        ShortName = "ha1a41e74g2804g4a70g9a85g6235163d41da",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_4",
        Description = "h411a732ag4b4cg4094g9a5egd325fecf4645",
        Icon = "E6_Ability_Intelligence" },
    Wisdom = {
        ShortName = "h2e9f1067g2dceg4640g8816gc6394e9f0303",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_5",
        Description = "h35233e68gf68ag461cgac5fgc15806be3dc7",
        Icon = "E6_Ability_Wisdom" },
    Charisma = {
        ShortName = "ha2fc9b3dg3305g404eg9256gf25a06d0b2aa",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_6",
        Description = "h441085efge3a5g4004gba8dgf2378e8986c8",
        Icon = "E6_Ability_Charisma" }
}

---Checks if both windows have lost focus. If so, closes them.
local function OnFocusChanged(_, _)
    if featUI and featUI.HasFocus then
        return
    end
    if featDetailUI and featDetailUI.HasFocus then
        return
    end
    if featUI then
        featUI.Visible = false
        featUI.Open = false
    end
    if featDetailUI then
        featDetailUI.Visible = false
        featDetailUI.Open = false
    end
end


---Adds the list of passives to the cell.
---@param cell ExtuiTableCell
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
local function AddPassivesToCell(cell, feat, extraPassives)
    local avoidDupes = {}
    for _,passive in ipairs(feat.PassivesAdded) do
        local passiveStat = Ext.Stats.Get(passive,  -1, true, true)
        local key = passiveStat.DisplayName .. "|" .. passiveStat.Description .. "|" .. passiveStat.Icon
        if not avoidDupes[key] then
            local icon = cell:AddImage(passiveStat.Icon)
            AddLocaTooltipTitled(icon, passiveStat.DisplayName, passiveStat.Description)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end
    for _,passive in ipairs(extraPassives) do
        local key = passive.DisplayName .. "|" .. passive.Description .. "|" .. passive.Icon
        if not avoidDupes[key] then
            local icon = cell:AddImage(passive.Icon)
            AddLocaTooltipTitled(icon, passive.DisplayName, passive.Description)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end
end

---Adds the passives to the feat details, if present.
---@param parent ExtuiTreeParent
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
local function AddPassivesToFeatDetailsUI(parent, feat, extraPassives)
    if #feat.PassivesAdded > 0 then
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()
        local passivesTitle = nil
        if #feat.PassivesAdded > 1 then
            passivesTitle = "h74d1322ag4c4dg42eag9272g066b84d0d374"
        else
            passivesTitle = "h099ebd82g6ea7g43b7gbf0fg69e32653f322"
        end
        AddLocaTitle(parent, passivesTitle)
        local passivesCell = CreateCenteredControlCell(parent, "Passives", parent.Size[1] - 60)
        AddPassivesToCell(passivesCell, feat, extraPassives)
    end
end

---Creates a control for manipulating the ability scores
---@param parent ExtuiTreeParent
---@param id string
---@param sharedResource SharedResource
---@param abilityName string
---@param abilityInfo table
---@param maxPoints number
---@return table?
local function AddAbilityControl(parent, id, sharedResource, abilityName, abilityInfo, maxPoints)
    if abilityInfo.Current >= abilityInfo.Maximum then
        return nil
    end

    local state = { Ability = abilityName, Initial = abilityInfo.Current, Current = abilityInfo.Current, Maximum = abilityInfo.Maximum }

    local win = parent:AddChildWindow(abilityName .. id .. "_Window")
    win.Size = {100, 300}
    win.SameLine = true
    local passiveInfo = abilityPassives[abilityName]
    AddLocaTooltipTitled(win, passiveInfo.DisplayName, passiveInfo.Description)
    AddLocaTitle(win, abilityPassives[abilityName].ShortName)

    local addButtonCell = CreateCenteredControlCell(win, abilityName .. id .. "_+", win.Size[1] - 40)
    local addButton = addButtonCell:AddImageButton("", "ico_plus_h")

    local currentScoreCell = CreateCenteredControlCell(win, abilityName .. id .. "_Current", win.Size[1] - 40)
    local currentScore = currentScoreCell:AddText(tostring(state.Current))

    local minButtonCell = CreateCenteredControlCell(win, abilityName .. id .. "_-", win.Size[1] - 40)
    local minButton = minButtonCell:AddImageButton("", "ico_min_h")

    local updateButtons = function()
        addButton.Enabled = sharedResource.count > 0 and state.Current < state.Maximum and state.Current - state.Initial < maxPoints
        minButton.Enabled = state.Current > state.Initial and sharedResource.count < sharedResource.capacity
    end

    addButton.OnClick = function()
        if sharedResource:AcquireResource() then
            state.Current = state.Current + 1
            currentScore.Label = tostring(state.Current)
        end
        updateButtons()
    end

    minButton.OnClick = function()
        if sharedResource:ReleaseResource() then
            state.Current = state.Current - 1
            currentScore.Label = tostring(state.Current)
        end
        updateButtons()
    end

    sharedResource:add(function(hasResources, resourcesAtCapacity)
        updateButtons()
    end)

    return state
end

---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param feat table The feat with the ability selector to process.
---@param playerInfo table Information about the player (in particular, ability scores).
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
local function AddAbilitySelectorToFeatDetailsUI(parent, feat, playerInfo, extraPassives)
    local resources = {}
    for _,abilityListSelector in ipairs(feat.SelectAbilities) do
        local abilityList = Ext.StaticData.Get(abilityListSelector.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if abilityList then
            parent:AddSpacing()
            parent:AddSeparator()
            parent:AddSpacing()

            local pointCount = SharedResource:new(abilityListSelector.Count)
            table.insert(resources, pointCount)
            local pointText = AddLocaTitle(parent, "h8cb5f019g91b8g4873ga7c4g2c79d5579a78")

            pointCount:add(function(_, _)
                local text = Ext.Loca.GetTranslatedString("h8cb5f019g91b8g4873ga7c4g2c79d5579a78")
                text = SubstituteParameters(text, { Count = pointCount.count, Max = abilityListSelector.Count })
                pointText.Label = text
            end)
            local abilitiesCell = CreateCenteredControlCell(parent, abilityListSelector.SourceId, parent.Size[1] - 60)
            
            for _,abilityEnum in ipairs(abilityList.Spells) do -- TODO: Will likely get renamed in the future
                local abilityName = abilityEnum.Label
                local abilityInfo = playerInfo.Abilities[abilityName]
                AddAbilityControl(abilitiesCell, abilityListSelector.SourceId, pointCount, abilityName, abilityInfo, abilityListSelector.Max)
            end

            pointCount:trigger()
        end
    end
    return resources
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
        featDetailUI.OnFocusChanged = OnFocusChanged
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

    local extraPassives = {}
    AddAbilitySelectorToFeatDetailsUI(childWin, feat, playerInfo, extraPassives)
    AddPassivesToFeatDetailsUI(childWin, feat, extraPassives)

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
        featUI.OnFocusChanged = OnFocusChanged
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

