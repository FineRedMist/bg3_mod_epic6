
---@class InternalPassiveSelectorType
---@field ID GUIDSTRING The ID of the passive.
---@field Stat PassiveData The stat data for the passive.
---@field Icon string The Icon of the passive
---@field DisplayName string The display name of the passive.
---@field Description string The description of the passive.
---@field DescriptionParams string[] The parameters for the description.

---@class RenderStateType Tracks render information for collections of passives spanning multiple rows.
---@field CenterCell ExtuiTableCell The center cell to add the passives to.
---@field IconsPerRow integer The number of icons to display per row.
---@field IconRowCount integer The number of icons added to the current row.
---@field Row integer The current index of the row for the passives.


---Returns true if selecting the passive won't cause the player to lose out on something important (like saving throw proficiency, stat increase, etc)
---@param playerInfo PlayerInformationType The player info to query against
---@param passive string The name of the passive
---@param passiveStat PassiveData The stat retrieved for the passive
---@return boolean Whether the passive can be safely selected.
---@return FeatMessageType[] The message to display to the player about why the requirement failed.
local function IsPassiveSafe(playerInfo, passive, passiveStat)
    local result = true
    ---@type FeatMessageType[]
    local successMessages = {}
    local failMessages = {}

    ---Adds a result message. If the canSelect is false, the result is set to false.
    ---@param canSelect boolean Whether the passive is selectable.
    ---@param message FeatMessageType A message about the passive (could occur even if selectable as a warning)
    local function AddResultMessage(canSelect, message)
        result = canSelect and result
        if canSelect then
            table.insert(successMessages, message)
        else
            table.insert(failMessages, message)
        end
    end

    -- If we already have the passive, return false
    if playerInfo.PlayerPassives[passive] then
        AddResultMessage(false, ToMessageLoca("hfd5c2332g01e0g4bf7ga4ebgd284ea1bb4e6")) -- This feature has already been selected.
    end
    local boostEntry = passiveStat.Boosts
    local boosts = SplitString(boostEntry, ";")
    for _,boost in ipairs(boosts) do
        -- Check ability scores
        local ability, score = ParseAbilityBoost(boost)
        if ability and score then
            local playerAbility = playerInfo.Abilities[ability]
            if not CanApplyAbilityBoost(playerAbility, score) then
                AddResultMessage(false, ToMessageLoca("h941fb918g8e78g4c41ga66fg1d14cd0f77cf")) -- This feature boosts an ability that is already at 20 (Legendary doesn't work for feature).
            else
                AddResultMessage(true, ToMessageLoca("h45303d74g2579g454ag9662g31dcf74794d7")) -- This feature boosts an ability that is limited to 20 (Legendary doesn't work for feature).
            end
        end
    
        -- Check saving throw proficiencies
        local proficiencyType, proficiency = ParseProficiencyBonusBoost(boost)
        if proficiencyType == "SavingThrow" then
            if playerInfo.Proficiencies.SavingThrows[proficiency] then
                AddResultMessage(false, ToMessageLoca("h6376efd2gf22cg47d9ga024gd8f39a0541c2")) -- You already have proficiency for this saving throw.
            end
        end
        -- Check equipment proficiencies
        local equipment = ParseProficiencyBoost(boost)
        if equipment then
            if playerInfo.Proficiencies.Equipment[string.lower(equipment)] then
                AddResultMessage(false, ToMessageLoca("hb22ba8fege28fg4863ga54eg005886d16a6b")) -- You already have this proficiency.
            end
        end
    end
    if result then
        return true, successMessages
    else
        return false, failMessages
    end
end

---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param playerInfo PlayerInformationType The ability information to render.
---@param uniquingName string The unique name to use for the control names to avoid collisions.
---@param passiveIndex integer The index of the passive in the feat (as there could be multiple sets of passives to select from).
---@param passive InternalPassiveSelectorType The passive to render.
---@param passiveList ResourcePassiveList The list of passives to select from.
---@param sharedResource SharedResource The shared resource to bind the control to.
---@param renderState RenderStateType The state of the rendering.
---@param selectedPassives table<string, boolean> The collection of selected passives.
local function AddPassiveByCheckbox(parent, playerInfo, uniquingName, passiveIndex, passive, passiveList, sharedResource, renderState, selectedPassives)
    if not renderState.CenterCell then
        renderState.CenterCell = CreateCenteredControlCell(parent, uniquingName .. "_Passives_" .. tostring(passiveIndex), GetWidthFromViewport(parent) - 60)
    end

    local passiveID = passive.ID
    local checkBoxControl = SpicyCheckbox(renderState.CenterCell, passive.DisplayName)
    local isPassiveSafe, passiveMessages = IsPassiveSafe(playerInfo, passiveID, passive.Stat)
    if not isPassiveSafe then
        UI_Disable(checkBoxControl)
    else
        checkBoxControl.OnChange = function()
            if checkBoxControl.Checked then
                selectedPassives[passiveID] = true
                sharedResource:AcquireResource()
            else
                selectedPassives[passiveID] = nil
                sharedResource:ReleaseResource()
            end
        end
        sharedResource:add(function(hasResources, _)
            if hasResources then
                UI_Enable(checkBoxControl)
            else
                UI_SetEnable(checkBoxControl, selectedPassives[passiveID] ~= nil)
            end
        end)
    end
    local resolver = ParameterResolver:new(playerInfo)
    local tooltip = AddTooltip(checkBoxControl)
    tooltip.preText = { function(text) return resolver:Resolve(text) end }
    tooltip:AddLoca(passive.Description, passive.DescriptionParams)

    local transform = MakeErrorText
    if isPassiveSafe then
        transform = MakeWarningText
    end
    AddTooltipMessageDetails(tooltip, passiveMessages, transform)
end

---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param playerInfo PlayerInformationType The ability information to render.
---@param uniquingName string The unique name to use for the control names to avoid collisions.
---@param passiveIndex integer The index of the passive in the feat (as there could be multiple sets of passives to select from).
---@param passive InternalPassiveSelectorType The passive to render.
---@param passiveList ResourcePassiveList The list of passives to select from.
---@param sharedResource SharedResource The shared resource to bind the control to.
---@param renderState RenderStateType The state of the rendering.
---@param selectedPassives table<string, boolean> The collection of selected passives.
local function AddPassiveByIcon(parent, playerInfo, uniquingName, passiveIndex, passive, passiveList, sharedResource, renderState, selectedPassives)
    local function AddRow()
        renderState.IconRowCount = 0
        renderState.Row = renderState.Row + 1
        return CreateCenteredControlCell(parent, uniquingName .. "_Passives_" .. tostring(passiveIndex) .. "_" .. tostring(renderState.Row), GetWidthFromViewport(parent) - 60)
    end

    if not renderState.Row then
        renderState.IconsPerRow = ComputeIconsPerRow(#passiveList.Passives)
        renderState.IconRowCount = 0
        renderState.Row = 0
        renderState.CenterCell = AddRow()
    end

    local passiveID = passive.ID
    local iconId = passive.Icon
    local iconControl = nil
    local isPassiveSafe, passiveMessages = IsPassiveSafe(playerInfo, passiveID, passive.Stat)
    if not isPassiveSafe then
        iconControl = renderState.CenterCell:AddImage(iconId, DefaultIconSize)
        UI_Disable(iconControl)
    else
        iconControl = renderState.CenterCell:AddImageButton("", iconId, DefaultIconSize)
        iconControl.OnClick = function()
            if selectedPassives[passiveID] then
                selectedPassives[passiveID] = nil
                sharedResource:ReleaseResource()
                MakeBland(iconControl)
            else
                selectedPassives[passiveID] = true
                sharedResource:AcquireResource()
                MakeSelected(iconControl)
            end
        end
        sharedResource:add(function(hasResources, _)
            if hasResources then
                UI_Enable(iconControl)
            else
                UI_SetEnable(iconControl, selectedPassives[passiveID] ~= nil)
            end
        end)
    end

    iconControl.SameLine = true

    local resolver = ParameterResolver:new(playerInfo)
    local tooltip = AddTooltip(iconControl)
    tooltip.preText = { function(text) return resolver:Resolve(text) end }
    tooltip:AddText(passive.DisplayName):AddSpacing():AddLoca(passive.Description, passive.DescriptionParams)

    local transform = MakeErrorText
    if isPassiveSafe then
        transform = MakeWarningText
    end
    AddTooltipMessageDetails(tooltip, passiveMessages, transform)

    renderState.IconRowCount = renderState.IconRowCount + 1
    if renderState.IconRowCount >= renderState.IconsPerRow then
        renderState.CenterCell = AddRow()
    end
end

---Converts the data to an internal passive selector type.
---@param passive string The passive ID
---@param iconId string? The icon ID
---@param stat PassiveData The stat data for the passive
---@return InternalPassiveSelectorType
local function GetInternalPassiveData(passive, iconId, stat)
    return { ID = passive, Stat = stat, Icon = iconId, DisplayName = Ext.Loca.GetTranslatedString(stat.DisplayName), Description = Ext.Loca.GetTranslatedString(stat.Description), DescriptionParams = SplitString(stat.DescriptionParams, ";") }
end

---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param feat FeatType
---@param playerInfo PlayerInformationType The ability information to render
---@param selectedPassives table<string, boolean> The collection of selected passives.
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
function AddPassiveSelectorToFeatDetailsUI(parent, feat, playerInfo, selectedPassives)
    if #feat.SelectPassives == 0 then
        return {}
    end

    local sharedResources = {}

    parent:AddSpacing()
    parent:AddSeparator()
    parent:AddSpacing()

    local uniquingName = feat.ShortName .. "_Passives"
    for passiveIndex, featPassiveInfo in ipairs(feat.SelectPassives) do
        local sharedResource = SharedResource:new(featPassiveInfo.Count)
        table.insert(sharedResources, sharedResource)

        ---@type ResourcePassiveList
        local passiveList = Ext.StaticData.Get(featPassiveInfo.SourceId, Ext.Enums.ExtResourceManagerType.PassiveList)

        local titleCell = CreateCenteredControlCell(parent, uniquingName .. "_Title_" .. tostring(passiveIndex), GetWidthFromViewport(parent) - 60)
        local title = titleCell:AddText("")

        local locString = "h447df23cgb2f2g405bgbe3eg1617f0209e39" -- Select Features: {Count}/{Max}
        if featPassiveInfo.Count == 1 then
            locString = "h8125b54ag30d6g49b0g87c0g579c827eb7da" -- Select Feature: {Count}/{Max}
        end
        locString = Ext.Loca.GetTranslatedString(locString)

        local function updateTitle(_,_)
            title.Label = SubstituteParameters(locString, {Count = sharedResource.count, Max = sharedResource.capacity})
        end
        sharedResource:add(updateTitle)

        updateTitle(nil, nil)

        local renderState = {}
        ---@type InternalPassiveSelectorType[]
        local sortedPassives = {}
        local isMissingIcons = false
        for _,passive in ipairs(passiveList.Passives) do
            ---@type PassiveData Data for the passive
            local stat = Ext.Stats.Get(passive, -1, true, true)
            local iconId = stat.Icon
            if not iconId or string.len(iconId) == 0 then
                isMissingIcons = true
            end
            table.insert(sortedPassives, GetInternalPassiveData(passive, iconId, stat))
        end

        -- Disable the sort as the specified order is assumed intentional.       
        --table.sort(sortedPassives, function(a,b)
        --    return a.Stat.DisplayName < b.Stat.DisplayName
        --end)

        local addPassiveFunction = nil
        if isMissingIcons then
            addPassiveFunction = AddPassiveByCheckbox
        else
            addPassiveFunction = AddPassiveByIcon
        end

        for _,passive in ipairs(sortedPassives) do
            addPassiveFunction(parent, playerInfo, uniquingName, passiveIndex, passive, passiveList, sharedResource, renderState, selectedPassives)
        end
    end

    return sharedResources
end

