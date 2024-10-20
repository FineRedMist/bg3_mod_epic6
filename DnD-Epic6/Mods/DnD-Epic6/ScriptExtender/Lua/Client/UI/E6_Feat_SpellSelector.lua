
---@class SelectSpellInfoUIType : SelectSpellInfoType
---@field IsCantrip boolean Whether the spell is a cantrip.
---@field IsSelected boolean Whether the spell is enabled.
---@field CanSelect boolean Whether the spell can be selected (if you already have it, you can't select it again).
---@field DisplayName string The display name of the spell.
---@field Description string The description of the spell.
---@field Icon string The icon of the spell.

---Checks the player's grant map for either added or selected spells to determine if the spell can be selected.
---To be denied granting, the spell must match the resource and ability of the spell grant.
---@param grantMap SpellGrantMapType The mapping of added or selected spells to their grant information.
---@param spell SelectSpellInfoUIType The spell to check for.
local function CanSelectFromSpellGrant(grantMap, spell)
    if not grantMap then
        return true
    end
    local grantInfo = grantMap[spell.SpellId]
    if not grantInfo then
        return true
    end
    for _,spellGrant in ipairs(grantInfo) do
        if spellGrant.ResourceId == spell.ActionResource and spellGrant.AbilityId == spell.Ability then
            return false
        end
    end
    return true
end

---A mapping of spell list ids to the corresponding spells in the list.
---@type table<GUIDSTRING,table<GUIDSTRING,boolean>>
local spellListMap = {}

---Determines if the spell list contains the given spell id.
---@param spellList GUIDSTRING The ID of the list.
---@param spellId GUIDSTRING The spell ID to query for.
---@return boolean True if the spell list contains the spell, false otherwise.
local function SpellListContainsSpell(spellList, spellId)
    if not spellListMap[spellList] then
        spellListMap[spellList] = {}
        ---@type ResourceSpellList
        local spells = Ext.StaticData.Get(spellList, Ext.Enums.ExtResourceManagerType.SpellList)
        if spells then
            for _,spell in ipairs(spells.Spells) do
                spellListMap[spellList][spell] = true
            end
        end
    end
    return spellListMap[spellList][spellId]
end

---Determines if the player can select the spell.
---@param unlockSpell SelectSpellInfoUIType The spell to unlock.
---@param playerInfo PlayerInformationType Information about the player to alter the spell selector.
local function CanSelectSpell(unlockSpell, playerInfo)
    for spellsId,spellGrantInfo in pairs(playerInfo.Spells.Added) do
        for _,spellGrant in ipairs(spellGrantInfo) do
            if spellGrant.ResourceId == unlockSpell.ActionResource and spellGrant.AbilityId == unlockSpell.Ability then
                if SpellListContainsSpell(spellsId, unlockSpell.SpellId) then
                    return false
                end
            end
        end
    end

    for _,spellGrant in pairs(playerInfo.Spells.Selected) do
        if not CanSelectFromSpellGrant(spellGrant, unlockSpell) then
            return false
        end
    end
    return true
end

---Adds a spell button to the UI. The button will be disabled if the spell cannot be selected.
---@param cell ExtuiTableCell The cell to add the button to.
---@param sharedResource SharedResource The shared resource for selecting the spell.
---@param unlockSpell SelectSpellInfoUIType The spell to unlock.
local function AddSpellButton(cell, sharedResource, unlockSpell)
    local icon = cell:AddImageButton("", unlockSpell.Icon, DefaultIconSize)
    AddLocaTooltipTitled(icon, unlockSpell.DisplayName, unlockSpell.Description)
    icon.SameLine = true

    if not unlockSpell.CanSelect then
        UI_Disable(icon)
    else
        icon.OnClick = function()
            if unlockSpell.IsSelected then
                unlockSpell.IsSelected = false
                if sharedResource:ReleaseResource() then
                    MakeBland(icon)
                else
                    unlockSpell.IsSelected = true
                end
            else
                unlockSpell.IsSelected = true
                if sharedResource:AcquireResource() then
                    MakeSelected(icon)
                else
                    unlockSpell.IsSelected = false
                end
            end
        end

        sharedResource:add(function(hasResources,_)
            if hasResources then
                UI_Enable(icon)
            else
                if not unlockSpell.IsSelected then
                    UI_Disable(icon)
                end
            end
        end)
    end
end

---Adds a spell selector block to the UI
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param selectSpells SelectSpellsType Information about the spell selection to add.
---@param playerInfo PlayerInformationType Information about the player to alter the spell selector.
---@param selectedSpells SelectSpellInfoUIType[] The spells selected by the player.
---@return SharedResource? The shared resource for selecting spells
local function AddSpellSelector(parent, id, selectSpells, playerInfo, selectedSpells)
    ---@type ResourceSpellList
    local spells = Ext.StaticData.Get(selectSpells.SpellsId, Ext.Enums.ExtResourceManagerType.SpellList)
    if not spells then
        return nil
    end

    local sharedResource = SharedResource:new(selectSpells.Count)

    parent:AddSpacing()

    local locString = Ext.Loca.GetTranslatedString("h00c4820cgf31bg4b3agab92g7058ba3c44e5") -- Select Spells {Count}/{Max}
    local centeredCell = CreateCenteredControlCell(parent, "SelectSpells_TitleTable_" .. id, GetWidthFromViewport(parent) - 60)
    local title = centeredCell:AddText("SelectSpells_Title_" .. id)
    local function updateTitle(_,_)
        title.Label = SubstituteParameters(locString, {Count = sharedResource.count, Max = sharedResource.capacity})
    end

    sharedResource:add(updateTitle)
    sharedResource:trigger()

    local spellCount = 0
    for _,spellId in pairs(spells.Spells) do -- not ipairs intentionally, it doesn't handle Array_FixedString for some reason.
        ---@type SpellData The spell data.
        local spellStat = Ext.Stats.Get(spellId, -1, true, true)
        if spellStat then
            spellCount = spellCount + 1
            ---@type SelectSpellInfoUIType
            local unlockSpell = DeepCopy(selectSpells)
            unlockSpell.Level = spellStat.Level
            unlockSpell.IsCantrip = spellStat.Level == 0
            unlockSpell.SpellId = spellId
            unlockSpell.IsSelected = false
            unlockSpell.DisplayName = spellStat.DisplayName
            unlockSpell.Description = spellStat.Description
            unlockSpell.Icon = spellStat.Icon
            unlockSpell.CanSelect = CanSelectSpell(unlockSpell, playerInfo)
            table.insert(selectedSpells, unlockSpell)
        end
    end

    local centeredCell = CreateCenteredControlCell(parent, "SelectSpells_" .. id .. "_Row_1", GetWidthFromViewport(parent) - 60)

    local rowNumber = 1
    local spellsPerRow = ComputeIconsPerRow(spellCount)
    local spellsInRow = 0
    for _,unlockSpell in ipairs(selectedSpells) do
        AddSpellButton(centeredCell, sharedResource, unlockSpell)
        spellsInRow = spellsInRow + 1
        if spellsInRow >= spellsPerRow then
            rowNumber = rowNumber + 1
            centeredCell = CreateCenteredControlCell(parent, "SelectSpells_" .. id .. "_Row_" .. tostring(rowNumber), GetWidthFromViewport(parent) - 60)
            spellsInRow = 0
        end
    end
    
    return sharedResource
end

---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param feat FeatType
---@param playerInfo PlayerInformationType The ability information to render
---@param selectedSpells SelectSpellInfoUIType[][] The spells selected by the player.
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
function AddSpellSelectorToFeatDetailsUI(parent, feat, playerInfo, selectedSpells)
    if #feat.SelectSpells == 0 then
        return {}
    end

    parent:AddSpacing()
    parent:AddSeparator()

    local sharedResources = {}

    for idx,selectSpells in ipairs(feat.SelectSpells) do
        local selected = {}
        table.insert(selectedSpells, selected)
        local resource = AddSpellSelector(parent, tostring(idx), selectSpells, playerInfo, selected)
        if resource then
            table.insert(sharedResources, resource)
        end
    end

    return sharedResources
end