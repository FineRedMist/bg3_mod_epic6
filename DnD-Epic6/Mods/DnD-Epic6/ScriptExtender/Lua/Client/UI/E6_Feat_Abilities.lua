---There theoretically be multiple sources for changing the ability at once. This tracks each of those.
---@class AbilityInfoStateUIType Used to track what will be the new state of the ability
---@field Name string The name of the ability
---@field Initial integer The initial value of the ability
---@field Current integer The current value of the ability
---@field Maximum integer The maximum value of the ability

---@class AbilityInfoUIType Information about the ability
---@field ID string The GUID That maps to the selector list
---@field PointCount integer The current ability value
---@field Max integer The maximum ability value
---@field State AbilityInfoStateUIType[] The current state of the ability

---Gather the abilities and map any single attribute increases to extraPassives
---@param feat FeatType
---@param playerInfo PlayerInformationType
---@param extraPassives ExtraPassiveType[]
---@return AbilityInfoUIType[] The abilities to display in the UI
function GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    ---@type AbilityInfoUIType[]
    local results = {}
    for _,abilityListSelector in ipairs(feat.SelectAbilities) do
        ---@type ResourceAbilityList
        local abilityList = Ext.StaticData.Get(abilityListSelector.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if abilityList then
            local pointCount = abilityListSelector.Count
            local result = { ID = abilityListSelector.SourceId, PointCount = pointCount, Max = abilityListSelector.Max, State = {} }
            table.insert(results, result)

            for _,abilityEnum in ipairs(abilityList.Abilities) do
                local abilityName = abilityEnum.Label
                local abilityInfo = playerInfo.Abilities[abilityName]
                if abilityInfo.Current < abilityInfo.Maximum then
                    table.insert(result.State, { Name = abilityName, Initial = abilityInfo.Current, Current = abilityInfo.Current, Maximum = abilityInfo.Maximum }) -- The ability name is repeated for UI purposes.
                end
            end

            -- We shouldn't encounter zero, we prefiltered on the server to remove them.
            if #result.State == 1 then
                local ability = result.State[1]
                local abilityName = ability.Name
                table.insert(extraPassives, {
                    DisplayName = AbilityPassives[abilityName].DisplayName,
                    Description = "h05cbc2b5ga5bag459fg91a0g22f6c4dd630b", -- [1]\n[2]
                    DescriptionParams = {
                        AbilityPassives[abilityName].Description,
                        "hddb8e266g3b9dg4d9cgb132gcc4d933e234a", -- [3] [4]
                        "+" .. tostring(pointCount),
                        AbilityPassives[abilityName].DisplayName
                    },
                    Icon = AbilityPassives[abilityName].Icon,
                    Boosts = { GetAbilityBoostPassive(abilityName, pointCount) },
                })
                table.remove(results, #results) -- Remove the entry so it doesn't show up in the selector
            end
        end
    end
    return results
end

---Creates a control for manipulating the ability scores
---@param parent ExtuiTreeParent
---@param sharedResource SharedResource
---@param pointInfo AbilityInfoUIType
---@param state AbilityInfoStateUIType
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
local function AddAbilityControl(parent, sharedResource, pointInfo, state, abilityResources)
    local abilityName = state.Name
    local id = pointInfo.ID
    local maxPoints = state.Maximum

    local win = parent:AddChildWindow(abilityName .. id .. "_Window")
    SetSizeToViewport(win, 100, 200)
    win.SameLine = true
    local passiveInfo = AbilityPassives[abilityName]
    local passiveTooltip = AddTooltip(win):AddText(passiveInfo.DisplayName):AddSpacing():AddText(passiveInfo.Description)
    AddLocaTitle(win, AbilityPassives[abilityName].ShortName)

    passiveTooltip:AddSpacing()
    local maximumText = Ext.Loca.GetTranslatedString("hf288edb6g7572g4963gb930ge36925049021") -- Maximum: {Maximum}
    passiveTooltip:AddText(SubstituteParameters(maximumText, { Maximum = maxPoints }))

    local addButtonCell = CreateCenteredControlCell(win, abilityName .. id .. "_+", GetWidthFromViewport(win) - 20)
    local addButton = addButtonCell:AddImageButton("", "ico_plus_h", ScaleToViewport({32, 32}))

    local currentScoreCell = CreateCenteredControlCell(win, abilityName .. id .. "_Current", GetWidthFromViewport(win) - 20)
    local currentScore = currentScoreCell:AddText(tostring(state.Current))

    local minButtonCell = CreateCenteredControlCell(win, abilityName .. id .. "_-", GetWidthFromViewport(win) - 20)
    local minButton = minButtonCell:AddImageButton("", "ico_min_h", ScaleToViewport({32, 32}))

    local updateButtons = function()
        UI_SetEnable(addButton, sharedResource.count > 0 and state.Current < state.Maximum and state.Current - state.Initial < maxPoints)
        UI_SetEnable(minButton, state.Current > state.Initial and sharedResource.count < sharedResource.capacity)
    end

    -- In case there is more than one selection that is possible for an ability (haven't found any yet, but paranoid).
    -- Might be worthwhile to create some test feats to validate this.
    local abilityResource = nil
    if abilityResources[abilityName] then
        abilityResource = abilityResources[abilityName]
    else
        abilityResource = SharedResource:new(state.Current, 100)
        abilityResources[abilityName] = abilityResource
    end

    addButton.OnClick = function()
        if sharedResource:AcquireResource() then
            state.Current = state.Current + 1
            abilityResource:ReleaseResource()
        end
        updateButtons()
    end

    minButton.OnClick = function()
        if sharedResource:ReleaseResource() then
            state.Current = state.Current - 1
            abilityResource:AcquireResource()
        end
        updateButtons()
    end

    abilityResource:add(function(_, _)
        currentScore.Label = tostring(abilityResource.count)
    end)

    sharedResource:add(function(_, _)
        updateButtons()
    end)
end

---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param abilityInfo AbilityInfoUIType[] The ability information to render
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
function AddAbilitySelectorToFeatDetailsUI(parent, abilityInfo, abilityResources)
    local resources = {}
    for _,abilityListSelector in ipairs(abilityInfo) do
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()

        local pointCount = SharedResource:new(abilityListSelector.PointCount)
        table.insert(resources, pointCount)
        local pointText = AddLocaTitle(parent, "h8cb5f019g91b8g4873ga7c4g2c79d5579a78") -- Ability Points: {Count}/{Max}

        pointCount:add(function(_, _)
            local text = Ext.Loca.GetTranslatedString("h8cb5f019g91b8g4873ga7c4g2c79d5579a78") -- Ability Points: {Count}/{Max}
            text = SubstituteParameters(text, { Count = pointCount.count, Max = abilityListSelector.PointCount })
            pointText.Label = text
        end)
        local abilitiesCell = CreateCenteredControlCell(parent, abilityListSelector.ID, GetWidthFromViewport(parent) - 60)

        for _,ability in ipairs(abilityListSelector.State) do
            AddAbilityControl(abilitiesCell, pointCount, abilityListSelector, ability, abilityResources)
        end

        pointCount:trigger()
    end
    return resources
end
