
---@class SelectSpellInfoUIType : SelectSpellInfoType
---@field IsCantrip boolean Whether the spell is a cantrip.
---@field IsSelected boolean Whether the spell is enabled.
---@field DisplayName string The display name of the spell.
---@field Description string The description of the spell.
---@field Icon string The icon of the spell.

---comment
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
            table.insert(selectedSpells, unlockSpell)
        end
    end

    local centeredCell = CreateCenteredControlCell(parent, "SelectSpells_" .. id .. "_Row_1", GetWidthFromViewport(parent) - 60)

    ---@param unlockSpell SelectSpellInfoUIType
    local function AddSpellButton(unlockSpell)
        local icon = centeredCell:AddImageButton("", unlockSpell.Icon, DefaultIconSize)
        AddLocaTooltipTitled(icon, unlockSpell.DisplayName, unlockSpell.Description)
        icon.SameLine = true

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

    local rowNumber = 1
    local spellsPerRow = ComputeIconsPerRow(spellCount)
    local spellsInRow = 0
    for _,unlockSpell in ipairs(selectedSpells) do
        AddSpellButton(unlockSpell)
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