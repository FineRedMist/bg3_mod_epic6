
---@type ExtuiWindow?
local featUI = nil
---@type ExtuiWindow?
local featDetailUI = nil

---The details panel for the feat.
---@param feat table The feat to create the window for.
---@param playerInfo table The player id for the feat.
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
    featDetailUI:SetSize(windowDimensions)
    featDetailUI:SetPos({1400, 100})
    featDetailUI.Closeable = true
    featDetailUI.NoMove = true
    featDetailUI.NoResize = true
    featDetailUI.NoCollapse = true
    featDetailUI.Open = true

    featDetailUI:SetFocus()

    ClearChildren(featDetailUI)

    local childWin = featDetailUI:AddChildWindow("Selection")
    childWin.Size = {windowDimensions[1] - 30, windowDimensions[2] - 130}
    childWin.PositionOffset = {0, 0}
    childWin.NoTitleBar = true
    local description = childWin:AddText(TidyDescription(feat.Description))
    description.ItemWidth = windowDimensions[1] - 60
    description.TextWrapPos = windowDimensions[1] - 60

    local extraPassives = {}
    local abilityResources = {}
    local skillStates = {}
    local selectedPassives = {}
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
        featUI.Open = false
        featDetailUI.Open = false

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
                if spell.IsEnabled then
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

---Generates the feat buttons to add to the window.
---@param win ExtuiWindow
---@param windowDimensions table
---@param message table
local function AddFeatButtons(win, windowDimensions, message)
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
            MakeFeatButton(win, windowDimensions[1], { ID = message.PlayerId, Name = message.PlayerName, Abilities = message.Abilities, PlayerPassives = message.PlayerPassives, Proficiencies = message.Proficiencies, ProficiencyBonus = message.ProficiencyBonus }, feat)
        end
    end
end

local function AddExportCharacterButton(win, windowDimensions, message)
    win:AddSpacing()
    win:AddSeparator()
    win:AddSpacing()

    local centerCell = CreateCenteredControlCell(win, "ExportCharacterCell", windowDimensions[1] - 30)
    local exportButton = centerCell:AddButton(Ext.Loca.GetTranslatedString("h3b4438fbg6a49g46c0g8346g372def6b2b77")) -- Export Character
    AddLocaTooltip(exportButton, "h7b3c6823g7bf9g4eaag8078g644e1ba33f33") -- Where to find the exported character
    exportButton.OnClick = function()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_EXPORT_CHARACTER, message.PlayerId)
    end
end

local function ConfigureFeatSelectorUI(windowDimensions)
    if featUI then
        return featUI
    end
    local win = Ext.IMGUI.NewWindow("FeatSelector")
    win.Label = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8") -- Feats
    win.Closeable = true
    win.NoMove = true
    win.NoResize = true
    win.NoCollapse = true
    win:SetSize(windowDimensions)
    win:SetPos({800, 100})
    win.OnClose = function()
        if featDetailUI then
            featDetailUI.Open = false
        end
    end
    featUI = win
    return win
end
---Shows the Feat Selector UI
---@param message table
function E6_FeatSelectorUI(message)
    local windowDimensions = {500, 1450}
    
    ---@type ExtuiWindow
    local win = ConfigureFeatSelectorUI(windowDimensions)

    win.Open = true
    win:SetFocus()

    ClearChildren(win)

    AddFeatButtons(win, windowDimensions, message)

    AddExportCharacterButton(win, windowDimensions, message)
end
