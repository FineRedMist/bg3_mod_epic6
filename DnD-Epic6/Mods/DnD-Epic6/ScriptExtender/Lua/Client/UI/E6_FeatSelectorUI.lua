---@type ExtuiWindow?
local featUI = nil
local featUIClosed = true
---@type string?
local featPlayerUI = nil
---@type ExtuiWindow?
local featDetailUI = nil
---@type boolean Whether to show the filtered feats.
local ShowFilteredFeats = false

local FeatUIDimensions = {500, 1450}
local FeatUIPosition = {1000, 100}
local FeatUIDetailsDimensions = {1000, 1450}
local FeatUIDetailsPosition = {1600, 100}

---Close feat detail UI and set focus on the feat UI.
local function E6_CloseFeatDetailsUI()
    if featDetailUI and featDetailUI.Open then
        featDetailUI.Open = false
        if not featUIClosed then
            featUI:SetFocus()
        end
    end
end

---Closes the UI
function E6_CloseUI()
    if featUI and not featUIClosed then
        -- Instead of actually closing the window, we are going to empty it and move it elsewhere.
        -- This way it is around to for interactions, but uninteractible.
        ClearChildren(featUI)
        featUI:SetSize({1, 1})
        featUI:SetPos(Ext.IMGUI.GetViewportSize())
        featUI.NoBackground = true
        featUI.NoTitleBar = true
        featUI.Closeable = false
        featUI.Open = true
        featUIClosed = true
        featPlayerUI = nil
    end
    E6_CloseFeatDetailsUI()
end

---The details panel for the feat.
---@param feat FeatType The feat to create the window for.
---@param playerInfo PlayerInformationType The player id for the feat.
local function ShowFeatDetailSelectUI(feat, playerInfo)
    local windowDimensions = FeatUIDetailsDimensions
    if not featDetailUI then
        featDetailUI = Ext.IMGUI.NewWindow("FeatDetailsWindow")
    end

    featDetailUI.Label = feat.DisplayName
    -- When the label changes, I need to reset the size and position of the window as it ends up moving.
    featDetailUI:SetSize(ScaleToViewport(windowDimensions))
    featDetailUI:SetPos(ScaleToViewport(FeatUIDetailsPosition))
    featDetailUI.Closeable = true
    featDetailUI.NoMove = true
    featDetailUI.NoResize = true
    featDetailUI.NoCollapse = true
    featDetailUI.Open = true

    ClearChildren(featDetailUI)

    local childWin = featDetailUI:AddChildWindow("Selection")
    SetSizeToViewport(childWin, windowDimensions[1] - 30, windowDimensions[2] - 130)
    childWin.PositionOffset = {0, 0}
    childWin.NoTitleBar = true
    local description = TextBuilder:new(childWin, windowDimensions[1] - 60)
    description:AddText(TidyDescription(feat.Description))

    local playerEntity = Ext.Entity.Get(playerInfo.UUID)
    local reqs = GatherFailedFeatRequirements(feat, playerEntity, playerInfo)
    AddTooltipMessageDetails(description, reqs, MakeWarningText)


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
    ---@type AbilityInfoUIType[] The ability information to display in the UI.
    local abilityInfo = GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    AddFeaturesToFeatDetailsUI(childWin, playerInfo, feat, extraPassives)
    local sharedResources = AddAbilitySelectorToFeatDetailsUI(childWin, abilityInfo, abilityResources)
    local passiveSharedResources = AddPassiveSelectorToFeatDetailsUI(childWin, feat, playerInfo, selectedPassives)
    local spellSharedResources = AddSpellSelectorToFeatDetailsUI(childWin, feat, playerInfo, selectedSpells)
    local skillSharedResources = AddSkillSelectorToFeatDetailsUI(childWin, feat, playerInfo, abilityResources, skillStates)

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
        -- If we'll have more feat points after applying the feat, then close the detail window, but keep the selector window
        -- open so the player can select another feat. We'll get an update from the server, however, to update feat status.
        if playerInfo.FeatPoints > 1 then
            playerInfo.FeatPoints = playerInfo.FeatPoints - 1
            E6_CloseFeatDetailsUI()
            E6_FeatSelectorUI(playerInfo) -- Refresh the UI to potentially filter out the selected feat.
        else
            E6_CloseUI()
        end

        -- Gather the selected abilities and any boosts from passives that resolved to only one ability (so automatic selection)
        local boosts = {}
        for _, passive in ipairs(extraPassives) do
            if passive.Boosts then
                for _, boost in ipairs(passive.Boosts) do
                    table.insert(boosts, boost)
                end
            end
        end
        for _, abilitySelector in ipairs(abilityInfo) do
            for _, ability in ipairs(abilitySelector.State) do
                if ability.Current > ability.Initial then
                    table.insert(boosts, GetAbilityBoostPassive(ability.Name, ability.Current - ability.Initial))
                end
            end
        end

        -- Add proficiency first, then expertise to ensure order.
        for skillName, skillState in pairs(skillStates) do
            if skillState.Proficient then
                table.insert(boosts, GetProficiencyBoostPassive(skillName))
            end
        end
        for skillName, skillState in pairs(skillStates) do
            if skillState.Expertise then
                table.insert(boosts, GetExpertiseBoostPassive(skillName))
            end
        end

        ---@type SpellGrantMapType The added spells for the feat.
        local featAddSpellInfo = {}
        for _, addSpells in ipairs(feat.AddSpells) do
            featAddSpellInfo[addSpells.SpellsId] = {SourceId = feat.ID, ResourceId = addSpells.ActionResource, AbilityId = addSpells.Ability, CooldownType = addSpells.CooldownType, PrepareType = addSpells.PrepareType}
        end

        ---A mapping of spell list id to the spells granted for that list.
        ---@type table<string, SpellGrantMapType>
        local featSelectedSpellInfo = {}
        for _, spellGroup in ipairs(selectedSpells) do
            for _, spell in ipairs(spellGroup) do
                if spell.IsSelected then
                    if featSelectedSpellInfo[spell.SpellsId] == nil then
                        featSelectedSpellInfo[spell.SpellsId] = {}
                    end
                    featSelectedSpellInfo[spell.SpellsId][spell.SpellId] = { SourceId = feat.ID, ResourceId = spell.ActionResource, AbilityId = spell.Ability, CooldownType = spell.CooldownType, PrepareType = spell.PrepareType}
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
            PlayerId = playerInfo.UUID,
            Feat = {
                FeatId = feat.ID,
                Boosts = boosts,
                PassivesAdded = passivesForFeat,
                AddedSpells = featAddSpellInfo,
                SelectedSpells = featSelectedSpellInfo
            }
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, payloadStr)
    end

    ConfigureEnableOnAllResourcesAllocated(select, sharedResources)

    featDetailUI:SetFocus()
end

---Creates a button in the feat selection window for the feat.
---@param win ExtuiWindow The window to close on completion.
---@param buttonWidth number The width of the button.
---@param playerInfo PlayerInformationType The player id for the feat.
---@param feat FeatType The feat to create the button for.
---@param isFiltered boolean Whether the feat is filtered.
---@return ExtuiButton The button created.
local function MakeFeatButton(win, buttonWidth, playerInfo, feat, isFiltered)
    local featButton = win:AddButton(feat.DisplayName)
    SetSizeToViewport(featButton, buttonWidth - 30, 48)
    featButton:SetStyle("ButtonTextAlign", 0.5, 0.5)
    local tooltip = AddTooltip(featButton):AddText(feat.Description)
    local transform = MakeErrorText
    if isFiltered then
        UI_Disable(featButton)
    else
        transform = MakeWarningText
        featButton.OnClick = function()
            ShowFeatDetailSelectUI(feat, playerInfo)
        end
    end

    local playerEntity = Ext.Entity.Get(playerInfo.UUID)
    local reqs = GatherFailedFeatRequirements(feat, playerEntity, playerInfo)
    AddTooltipMessageDetails(tooltip, reqs, transform)

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
    local featsToShow = DeepCopy(playerInfo.SelectableFeats)
    local isFiltered = {}
    if ShowFilteredFeats then
        for _, featId in ipairs(playerInfo.FilteredFeats) do
            isFiltered[featId] = true
            table.insert(featsToShow, featId)
        end
    end
    for _,featId in ipairs(featsToShow) do
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
            MakeFeatButton(win, windowDimensions[1], playerInfo, feat, isFiltered[feat.ID])
        end
    end
end

---Adds a button to reset the character's feats.
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddResetFeatsButton(win, windowDimensions, playerInfo)
    local centerCell = CreateCenteredControlCell(win, "ResetFeatsCell", windowDimensions[1] - 30)
    local resetFeatsButton = centerCell:AddButton(Ext.Loca.GetTranslatedString("h3b4438fbg6a49g46c0g8346g372def6b2b77")) -- Reset Feats
    AddTooltip(resetFeatsButton):AddText("h7b3c6823g7bf9g4eaag8078g644e1ba33f33") -- Reset all feats and feat points for the character.
    resetFeatsButton.OnClick = function()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_RESET_FEATS, playerInfo.UUID)
    end
end

---Adds a button to export the character's Epic 6 information.
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddExportCharacterEpic6Button(win, windowDimensions, playerInfo)
    local centerCell = CreateCenteredControlCell(win, "ExportEpic6Cell", windowDimensions[1] - 30)
    local exportButton = centerCell:AddButton(Ext.Loca.GetTranslatedString("hc1014814g1ab8g4a6dg93e9g0e4667bb18b7")) -- Export Character Epic 6 Data
    AddTooltip(exportButton):AddText("he6d7a765g378ag4eceg9618ge42bf8c7878d") -- Export the character to a file.
    exportButton.OnClick = function()
        E6_CloseUI()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_EXPORT_EPIC6, playerInfo.UUID)
    end
end

---Adds a button to export the character entity data.
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddExportCharacterGameButton(win, windowDimensions, playerInfo)
    local centerCell = CreateCenteredControlCell(win, "ExportGameCell", windowDimensions[1] - 30)
    local exportButton = centerCell:AddButton(Ext.Loca.GetTranslatedString("h27d08b54g94d5g405cga8c6g57231379a05f")) -- Export Character Game Data
    AddTooltip(exportButton):AddText("h5cb70d0agc32bg49d6g96f1gdd2daa2ac545") -- Export the character to a file.
    exportButton.OnClick = function()
        E6_CloseUI()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_EXPORT_EPIC6, playerInfo.UUID)
    end
end

---Adds a button to test some functionality (varies with usage/need).
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddRunTestButton(win, windowDimensions, playerInfo)
    local centerCell = CreateCenteredControlCell(win, "RunTest", windowDimensions[1] - 30)
    local runTestButton = centerCell:AddButton("Run Test")
    AddTooltip(runTestButton):AddText("Runs a test regarding Minsc and Jaheira")
    runTestButton.OnClick = function()
        E6_CloseUI()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_RUN_TEST, playerInfo.UUID)
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
    settings.DefaultOpen = #playerInfo.SelectableFeats == 0
    settings.SpanFullWidth = true

    local slider = settings:AddSliderInt("", playerInfo.XPPerFeat, 100, 20000)
    AddTooltip(slider):AddText("hcbbf8d49g36fbg496bga9beg275c367f94c0")
    slider.AlwaysClamp = true
    slider.OnChange = function()
        local rounded = 100 * math.floor(slider.Value[1]/100 + 0.5)
        slider.Value = {rounded, rounded, rounded, rounded}
    end

    local saveSlider = settings:AddButton(Ext.Loca.GetTranslatedString("h21681079gab67g4ea5ga4dfg88f40d38818a")) -- Save
    AddTooltip(saveSlider):AddText("hf2b3a061gbf90g48cbg8defg30ec6aef6159")
    saveSlider.SameLine = true
    saveSlider.OnClick = function()
        local payload = {
            PlayerId = playerInfo.UUID,
            XPPerFeat = slider.Value[1]
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SET_XP_PER_FEAT, payloadStr)

        -- If the slider value increases more than the XPPerFeat, the player may end up without having enough
        -- XP for the next feat, so we should close if there are feats to select, just in case.
        if #playerInfo.SelectableFeats > 0 and slider.Value[1] > playerInfo.XPPerFeat then
            E6_CloseUI()
        end
    end

    -- Only the host can modify the amount of XP per feat.
    if not playerInfo.IsHost then
        UI_Disable(slider)
        UI_Disable(saveSlider)
    end

    win:AddSpacing()
    win:AddSpacing()

    local showFilteredCheckbox = SpicyCheckbox(settings, Ext.Loca.GetTranslatedString("hbc9684d8gca58g4210gb373gb55e83cc0081")) -- Show filtered feats
    AddTooltip(showFilteredCheckbox):AddText("ha087585cgc6beg407ega903g92b69efc6e9b") -- Show feats that were filtered because requirements were not met.
    showFilteredCheckbox.Checked = ShowFilteredFeats
    showFilteredCheckbox.OnChange = function()
        ShowFilteredFeats = not ShowFilteredFeats
        E6_FeatSelectorUI(playerInfo) -- Refresh the UI
    end
    win:AddSpacing()
    win:AddSpacing()
    AddResetFeatsButton(settings, windowDimensions, playerInfo)

    win:AddSpacing()
    win:AddSpacing()
    AddExportCharacterEpic6Button(settings, windowDimensions, playerInfo)

    win:AddSpacing()
    win:AddSpacing()
    AddExportCharacterGameButton(settings, windowDimensions, playerInfo)

    --win:AddSpacing()
    --win:AddSpacing()
    --AddRunTestButton(settings, windowDimensions, playerInfo)
end

local windowTitle = Ext.Loca.GetTranslatedString("hb09763begcf50g4351gb1f1gd39ec792509b") -- Feats: {CharacterName}
local function SetWindowTitle(playerInfo)
    local playerEntity = Ext.Entity.Get(playerInfo.UUID)
    local playerName = GetCharacterName(playerEntity, false)
    featUI.Label = SubstituteParameters(windowTitle, {CharacterName = playerName})
end

---Creates/Gets the Feat Selector UI
---@param windowDimensions integer[] The dimensions of the window.
---@return ExtuiWindow The window to display.
local function ConfigureFeatSelectorUI(windowDimensions)
    if featUI then
        E6_CloseFeatDetailsUI() -- Close the detail window if it's open so it doesn't get used.
    else
        featUI = Ext.IMGUI.NewWindow("FeatSelector")
        featUI.OnClose = function()
            E6_CloseFeatDetailsUI()
            E6_CloseUI()
        end
    end

    featUI.NoBackground = false
    featUI.NoTitleBar = false
    featUI.Closeable = true
    featUI.NoMove = true
    featUI.NoResize = true
    featUI.NoCollapse = true
    featUI.Open = true
    featUIClosed = false
    featUI:SetSize(ScaleToViewport(windowDimensions))
    featUI:SetPos(ScaleToViewport(FeatUIPosition))

    return featUI
end

---Adds information about how much experience is left to the next feat.
---@param win ExtuiTreeParent The parent to add the button to.
---@param windowDimensions integer[] The dimensions of the window.
---@param playerInfo PlayerInformationType The player information.
local function AddExpInfo(win, windowDimensions, playerInfo)
    local centerCell = CreateCenteredControlCell(win, "ExpInfo", windowDimensions[1] - 30)

    local ent = Ext.Entity.Get(playerInfo.UUID)
    local level6Exp = E6_GetLevel6XP()
    local xpDiff = level6Exp - ent.Experience.TotalExperience
    local progressText = nil
    if ent.EocLevel.Level >= 6 then
        local xpToNextLevel = ent.Experience.CurrentLevelExperience
        local remainingExp = playerInfo.XPPerFeat - math.fmod(xpToNextLevel, playerInfo.XPPerFeat)
        progressText = GetParameterizedLoca("hbd475c8ega2dcg4491ga9a9gabbe7a9c8216", {string.format("%.0f", remainingExp)}) -- Level 6: [1] XP
    else
        if xpDiff < 0 then
            xpDiff = 0
        end
        progressText = GetParameterizedLoca("h95f979dcg69e9g464fgb943gf2559470bcc1", {string.format("%.0f", xpDiff)}) -- Next feat: [1] XP
    end

    centerCell:AddText(progressText)
end

local function AddResolver(playerInfo)
    playerInfo.Resolver = ParameterResolver:new(playerInfo, playerInfo.ResolveMap)
    playerInfo.Resolve = function(text)
        return playerInfo.Resolver:Resolve(text)
    end
end

---Shows the Feat Selector UI
---@param playerInfo PlayerInformationType
function E6_FeatSelectorUI(playerInfo)
    local windowDimensions = FeatUIDimensions

    AddResolver(playerInfo)

    ---@type ExtuiWindow
    local win = ConfigureFeatSelectorUI(windowDimensions)

    SetWindowTitle(playerInfo)

    featPlayerUI = playerInfo.UUID
    win:SetFocus()

    ClearChildren(win)

    AddExpInfo(win, windowDimensions, playerInfo)

    AddFeatButtons(win, windowDimensions, playerInfo)

    AddSettings(win, windowDimensions, playerInfo)
end

-- Tracks whether it is safe to be trying to update the feat count or not.
-- We only do this in the Running state of the game.
local E6_CanCheckWin = false

---@param e EclLuaGameStateChangedEvent
local function E6_ManageUI(e)
    if e.ToState ~= Ext.Enums.ClientGameState.Running then
        E6_CloseUI() -- Close the UI if we are changing state and not running.
        E6_CanCheckWin = false
    elseif not E6_CanCheckWin then
        E6_CanCheckWin = true
    end
end

---Updates the Feat UI if the character has changed. It also closes if any selected character is not a player.
---@param tickParams any ignored
local function E6_OnTick_UpdateFeatUI(tickParams)
    if not E6_CanCheckWin then
        return
    end
    if featUIClosed then
        return
    end

    local entity = GetLocallyControlledCharacter()
    if not entity then
        E6_CloseUI()
        return
    end

    -- Close when we enter dialog
    if entity.Vars.E6_InCombat or entity.Vars.E6_InDialog then
        E6_CloseUI()
        return
    end

    local host = GetEntityID(entity)

    -- Request the UI to switch to the newly selected character.
    if host ~= featPlayerUI then
        E6_CloseFeatDetailsUI()
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SWITCH_CHARACTER, host)
        featPlayerUI = host -- to prevent retriggering this until we get a message back.
    end
end

local function E6_OnCloseWindow()
    if featDetailUI and featDetailUI.Open then
        E6_CloseFeatDetailsUI()
    else
        E6_CloseUI()
    end
end

---Captures the controller axis events and attempts to supress them while the UI is up.
---@param e EclLuaControllerButtonEvent
local function E6_OnControllerAxis(e)
    if not featUIClosed then
        e:PreventAction()
        e:StopPropagation()
    end
    return 0
end

---Captures the controller button event to close the UI on 'Y' (first feat details, then the feat list)
---@param e EclLuaControllerButtonEvent
local function E6_OnControllerButton(e)
    local wasOpen = not featUIClosed
    if e.Event == "KeyDown" and e.Button == "Y" then
        E6_OnCloseWindow()
    end

    if wasOpen then
        e:PreventAction()
        e:StopPropagation()
    end
    return 0
end

---Captures the keyboard event looking for escape while the UI is up to close the windows.
---@param e EclLuaKeyInputEvent
local function E6_OnKey(e)
    local wasOpen = not featUIClosed
    if e.Event == "KeyDown" and e.Key == "ESCAPE" then
        E6_OnCloseWindow()
    end

    if wasOpen then
        e:PreventAction()
        e:StopPropagation()
    end
    return 0
end

-- Ensure the UI is closed when the game mode changes out of Running.
Ext.Events.GameStateChanged:Subscribe(E6_ManageUI)

-- Checking every tick seems less than optimal, but I'm not sure where I can hook for
-- when the selected character changes.
Ext.Events.Tick:Subscribe(E6_OnTick_UpdateFeatUI)

---Subscribe to events for controller buttons so we can close the windows on 'Y'
Ext.Events.ControllerButtonInput:Subscribe(E6_OnControllerButton)
--Ext.Events.ControllerAxisInput:Subscribe(E6_OnControllerAxis) Can't suppress the axis events while the UI is up :(
Ext.Events.KeyInput:Subscribe(E6_OnKey)

featUI = ConfigureFeatSelectorUI({1, 1})
E6_CloseUI()