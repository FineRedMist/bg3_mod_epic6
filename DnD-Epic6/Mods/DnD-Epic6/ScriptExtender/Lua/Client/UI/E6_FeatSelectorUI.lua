
---@type ExtuiWindow?
local featUI = nil
---@type ExtuiWindow?
local featDetailUI = nil

local function E6_CloseFeatDetailsUI()
    if featDetailUI then
        featDetailUI.Open = false
    end
end

---Closes the UI
function E6_CloseUI()
    if featUI then
        featUI.Open = false
    end
    E6_CloseFeatDetailsUI()
end

---The details panel for the feat.
---@param feat FeatType The feat to create the window for.
---@param playerInfo PlayerInformationType The player id for the feat.
local function ShowFeatDetailSelectUI(feat, playerInfo)
    local windowDimensions = {1000, 1450}
    if not featDetailUI then
        featDetailUI = Ext.IMGUI.NewWindow("FeatDetailsWindow")
        featDetailUI.Closeable = true
        featDetailUI.NoMove = true
        featDetailUI.NoResize = true
        featDetailUI.NoCollapse = true
    end

    featDetailUI.Label = feat.DisplayName
    -- When the label changes, I need to reset the size and position of the window as it ends up moving.
    featDetailUI:SetSize(ScaleToViewport(windowDimensions))
    featDetailUI:SetPos(ScaleToViewport({1400, 100}))
    featDetailUI.Closeable = true
    featDetailUI.NoMove = true
    featDetailUI.NoResize = true
    featDetailUI.NoCollapse = true
    featDetailUI.Open = true

    featDetailUI:SetFocus()

    ClearChildren(featDetailUI)

    local childWin = featDetailUI:AddChildWindow("Selection")
    SetSizeToViewport(childWin, windowDimensions[1] - 30, windowDimensions[2] - 130)
    childWin.PositionOffset = {0, 0}
    childWin.NoTitleBar = true
    local description = childWin:AddText(TidyDescription(feat.Description))
    description.ItemWidth = ScaleToViewportWidth(windowDimensions[1] - 60)
    description.TextWrapPos = description.ItemWidth

    ---@type ExtraPassiveType[] Extra passives to apply as part of applying a feat.
    local extraPassives = {}
    ---@type table<string, SharedResource> Mapping of ability name to the shared resource for the ability, to track ability value changes for UI elements.
    local abilityResources = {}
    ---@type table<string, ProficiencyType> The skill states to apply when the feat is committed.
    local skillStates = {}
    ---@type table<string, boolean> The collection of selected passives.
    local selectedPassives = {}
    ---@type SelectSpellInfoUIType[][] The array of selected spells, for each spell group to select from.
    local selectedSpells = {}
    local abilityInfo = GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    AddFeaturesToFeatDetailsUI(childWin, feat, extraPassives)
    local sharedResources = AddAbilitySelectorToFeatDetailsUI(childWin, abilityInfo, abilityResources)
    local skillSharedResources = AddSkillSelectorToFeatDetailsUI(childWin, feat, playerInfo, abilityResources, skillStates)
    local passiveSharedResources = AddPassiveSelectorToFeatDetailsUI(childWin, feat, playerInfo, selectedPassives)
    local spellSharedResources = AddSpellSelectorToFeatDetailsUI(childWin, feat, playerInfo, selectedSpells)

    for _, resource in ipairs(skillSharedResources) do
        table.insert(sharedResources, resource)
    end
    for _, resource in ipairs(passiveSharedResources) do
        table.insert(sharedResources, resource)
    end
    for _, resource in ipairs(spellSharedResources) do
        table.insert(sharedResources, resource)
    end

    local centerCell = CreateCenteredControlCell(featDetailUI, "Select", windowDimensions[1] - 30)
    local select = centerCell:AddButton(Ext.Loca.GetTranslatedString("h04f38549g65b8g4b72g834eg87ee8863fdc5")) -- Select

    select:SetStyle("ButtonTextAlign", 0.5, 0.5)

    select.OnClick = function()
        E6_CloseUI()

        -- Gather the selected abilities and any boosts from passives that resolved to only one ability (so automatic selection)
        local boosts = {}
        for _, passive in ipairs(extraPassives) do
            table.insert(boosts, passive.Boost)
        end
        for _, abilitySelector in ipairs(abilityInfo) do
            for _, ability in ipairs(abilitySelector.State) do
                if ability.Current > ability.Initial then
                    local boost = "Ability(" .. JoinArgs({ability.Name, ability.Current - ability.Initial}) .. ")"
                    table.insert(boosts, boost)
                end
            end
        end

        -- Add the boosts for the skills
        for skillName, skillState in pairs(skillStates) do
            if skillState.Proficient then
                table.insert(boosts, "ProficiencyBonus(Skill," .. skillName .. ")")
            end
            if skillState.Expertise then
                table.insert(boosts, "ExpertiseBonus(" .. skillName .. ")")
            end
        end

        for _, spellGroup in ipairs(selectedSpells) do
            for _, spell in ipairs(spellGroup) do
                if spell.IsSelected then
                    table.insert(boosts, MakeBoost_UnlockSpell(spell, not spell.IsCantrip))
                end
            end
        end

        -- Gather the passives selected and from the feat itself
        local passivesForFeat = {}
        for _,passive in ipairs(feat.PassivesAdded) do
            table.insert(passivesForFeat, passive)
        end
        for passive,_ in pairs(selectedPassives) do
            table.insert(passivesForFeat, passive)
        end

        ---@type SelectedFeatPayloadType
        local payload = {
            PlayerId = playerInfo.ID,
            Feat = {
                FeatId = feat.ID,
                PassivesAdded = passivesForFeat,
                Boosts = boosts
            }
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, payloadStr)
    end

    ConfigureEnableOnAllResourcesAllocated(select, sharedResources)
end

---Creates a button in the feat selection window for the feat.
---@param win ExtuiWindow The window to close on completion.
---@param buttonWidth number The width of the button.
---@param playerInfo PlayerInformationType The player id for the feat.
---@param feat FeatType The feat to create the button for.
---@return ExtuiButton The button created.
local function MakeFeatButton(win, buttonWidth, playerInfo, feat)
    local featButton = win:AddButton(feat.DisplayName)
    SetSizeToViewport(featButton, buttonWidth - 30, 48)
    featButton:SetStyle("ButtonTextAlign", 0.5, 0.5)
    AddTooltip(featButton, TidyDescription(feat.Description))
    featButton.OnClick = function()
        ShowFeatDetailSelectUI(feat, playerInfo)
    end
    return featButton
end

---Generates the feat buttons to add to the window.
---@param win ExtuiWindow The window to add the feat buttons to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddFeatButtons(win, windowDimensions, playerInfo)
    local allFeats = E6_GatherFeats()

    local featList = {}
    local featMap = {}
    for _,featId in ipairs(playerInfo.SelectableFeats) do
        local feat = allFeats[featId]
        local featName = feat.DisplayName
        featMap[featName] = feat
        table.insert(featList, featName)
    end

    table.sort(featList, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    for _, featName in ipairs(featList) do
        local feat = featMap[featName]
        if feat == nil then
            _E6Error("Failed to find feat for name: " .. featName)
        else
            MakeFeatButton(win, windowDimensions[1], playerInfo, feat)
        end
    end
end

---Adds a button to export the character to the file system.
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddExportCharacterButton(win, windowDimensions, playerInfo)
    local centerCell = CreateCenteredControlCell(win, "ExportCharacterCell", windowDimensions[1] - 30)
    local exportButton = centerCell:AddButton(Ext.Loca.GetTranslatedString("h3b4438fbg6a49g46c0g8346g372def6b2b77")) -- Export Character
    AddLocaTooltip(exportButton, "h7b3c6823g7bf9g4eaag8078g644e1ba33f33") -- Where to find the exported character
    exportButton.OnClick = function()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_EXPORT_CHARACTER, playerInfo.PlayerId)
    end
end

---Adds configuration settings under a collapsible header.
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddSettings(win, windowDimensions, playerInfo)
    win:AddSpacing()
    win:AddSeparator()
    win:AddSpacing()

    local settings = win:AddCollapsingHeader(Ext.Loca.GetTranslatedString("h9945dd99g22e4g4111ga988g05974feeba28")) -- Settings
    settings.Bullet = true
    settings.DefaultOpen = false
    settings.SpanFullWidth = true

    local slider = settings:AddSliderInt("", playerInfo.XPPerFeat, 100, 20000)
    AddLocaTooltip(slider, "hcbbf8d49g36fbg496bga9beg275c367f94c0")
    slider.AlwaysClamp = true
    slider.OnChange = function()
        local rounded = 100 * math.floor(slider.Value[1]/100 + 0.5)
        slider.Value = {rounded, rounded, rounded, rounded}
    end

    local saveSlider = settings:AddButton(Ext.Loca.GetTranslatedString("h21681079gab67g4ea5ga4dfg88f40d38818a")) -- Save
    AddLocaTooltip(saveSlider, "hf2b3a061gbf90g48cbg8defg30ec6aef6159")
    saveSlider.SameLine = true
    saveSlider.OnClick = function()
        local payload = {
            PlayerId = playerInfo.ID,
            XPPerFeat = slider.Value[1]
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SET_XP_PER_FEAT, payloadStr)

        -- If the slider value increases more than the XPPerFeat, the player may end up without
        -- having enough XP for the next feat, so we should close, just in case.
        if(slider.Value[1] > playerInfo.XPPerFeat) then
            E6_CloseUI()
        end
    end

    win:AddSpacing()
    win:AddSpacing()
    AddExportCharacterButton(settings, windowDimensions, playerInfo)
end

local windowTitle = Ext.Loca.GetTranslatedString("hb09763begcf50g4351gb1f1gd39ec792509b") -- Feats: {CharacterName}
local function SetWindowTitle(playerInfo)
    local playerEntity = Ext.Entity.Get(playerInfo.ID)
    local playerName = GetCharacterName(playerEntity, false)
    featUI.Label = SubstituteParameters(windowTitle, {CharacterName = playerName})
end

---Creates/Gets the Feat Selector UI
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
---@return ExtuiWindow The window to display.
local function ConfigureFeatSelectorUI(windowDimensions, playerInfo)
    if featUI then
        SetWindowTitle(playerInfo)
        E6_CloseFeatDetailsUI() -- Close the detail window if it's open so it doesn't get used.
        return featUI
    end
    featUI = Ext.IMGUI.NewWindow("FeatSelector")
    SetWindowTitle(playerInfo)
    featUI.Closeable = true
    featUI.NoMove = true
    featUI.NoResize = true
    featUI.NoCollapse = true
    featUI:SetSize(ScaleToViewport(windowDimensions))
    featUI:SetPos(ScaleToViewport({800, 100}))
    featUI.OnClose = E6_CloseFeatDetailsUI
    return featUI
end

local registeredForCloseUI = false

---Shows the Feat Selector UI
---@param playerInfo PlayerInformationType
function E6_FeatSelectorUI(playerInfo)
    if not registeredForCloseUI then
        --RegisterForCloseUIEvents(E6_CloseUI) -- Doesn't seem to work on the client to register for events.
        registeredForCloseUI = true
    end

    local windowDimensions = {500, 1450}
    
    ---@type ExtuiWindow
    local win = ConfigureFeatSelectorUI(windowDimensions, playerInfo)

    win.Open = true
    win:SetFocus()

    ClearChildren(win)

    AddFeatButtons(win, windowDimensions, playerInfo)

    if playerInfo.IsHost then
        AddSettings(win, windowDimensions, playerInfo)
    end
end

---@param e EclLuaGameStateChangedEvent
local function E6_ManageUI(e)
    if e.ToState ~= Ext.Enums.ServerGameState.Running then
        E6_CloseUI() -- Close the UI if we are changing state and not running.
    end
end

Ext.Events.GameStateChanged:Subscribe(E6_ManageUI)
