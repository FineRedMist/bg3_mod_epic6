
---Gather the abilities and map any single attribute increases to extraPassives
---@param feat table
---@param playerInfo table
---@param extraPassives table
function GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    local results = {}
    for _,abilityListSelector in ipairs(feat.SelectAbilities) do
        local abilityList = Ext.StaticData.Get(abilityListSelector.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if abilityList then
            local pointCount = abilityListSelector.Count
            local result = { ID = abilityListSelector.SourceId, PointCount = pointCount, Max = abilityListSelector.Max, State = {} }
            table.insert(results, result)

            for _,abilityEnum in ipairs(abilityList.Spells) do -- TODO: Will likely get renamed in the future
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
                    Description = AbilityPassives[abilityName].Description,
                    Icon = AbilityPassives[abilityName].Icon,
                    Boost = "Ability(" .. JoinArgs({abilityName, tostring(pointCount)}) .. ")",
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
---@param pointInfo table
---@param state table
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
---@return table?
local function AddAbilityControl(parent, sharedResource, pointInfo, state, abilityResources)
    local abilityName = state.Name
    local id = pointInfo.ID
    local maxPoints = pointInfo.Max

    local win = parent:AddChildWindow(abilityName .. id .. "_Window")
    win.Size = {100, 180}
    win.SameLine = true
    local passiveInfo = AbilityPassives[abilityName]
    AddLocaTooltipTitled(win, passiveInfo.DisplayName, passiveInfo.Description)
    AddLocaTitle(win, AbilityPassives[abilityName].ShortName)

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
---@param abilityInfo table The ability information to render
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
        local abilitiesCell = CreateCenteredControlCell(parent, abilityListSelector.ID, parent.Size[1] - 60)

        for _,ability in ipairs(abilityListSelector.State) do -- TODO: Will likely get renamed in the future
            AddAbilityControl(abilitiesCell, pointCount, abilityListSelector, ability, abilityResources)
        end

        pointCount:trigger()
    end
    return resources
end
