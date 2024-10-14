---Adds the list of passives to the cell.
---@param parent ExtuiTreeParent
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
local function AddFeaturesToCell(parent, feat, extraPassives)
    local avoidDupes = {}

    ---@type ExtuiTableCell The cell to add the passives to.
    local centeredCell = nil

    local function AddPassiveIcon(displayNameId, descriptionId, iconId)
        local key = displayNameId .. "|" .. descriptionId .. "|" .. iconId
        if not avoidDupes[key] then
            local icon = centeredCell:AddImage(iconId, DefaultIconSize)
            AddLocaTooltipTitled(icon, displayNameId, descriptionId)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end

    local firstSectionCount = #feat.PassivesAdded + #extraPassives
    if firstSectionCount > 0 then
        AddLocaTitle(parent, "hffc72a17g6934g42f8ga935g447764ee6f43") -- Features
        centeredCell = CreateCenteredControlCell(parent, "Features", GetWidthFromViewport(parent) - 60)
    end

    for _,passive in ipairs(feat.PassivesAdded) do
        ---@type PassiveData Data for the passive
        local passiveStat = Ext.Stats.Get(passive,  -1, true, true)
        AddPassiveIcon(passiveStat.DisplayName, passiveStat.Description, passiveStat.Icon)
    end
    for _,passive in ipairs(extraPassives) do
        AddPassiveIcon(passive.DisplayName, passive.Description, passive.Icon)
    end

    if #feat.AddSpells ~= 0 then
        avoidDupes = {}
        if firstSectionCount > 0 then
            parent:AddSpacing()
        end

        AddLocaTitle(parent, "h23fb3bb3gd957g433fgbdfag862d70a20649") -- New Spells
        centeredCell = CreateCenteredControlCell(parent, "AddedSpells", GetWidthFromViewport(parent) - 60)

        for _,addSpells in ipairs(feat.AddSpells) do
            ---@type ResourceSpellList
            local spells = Ext.StaticData.Get(addSpells.SpellsId, Ext.Enums.ExtResourceManagerType.SpellList)
            if spells then
                for _,spellId in pairs(spells.Spells) do -- not ipairs intentionally, it doesn't handle Array_FixedString for some reason.
                    ---@type SpellData The spell data.
                    local spellStat = Ext.Stats.Get(spellId, -1, true, true)
                    if spellStat then
                        ---@type SelectSpellInfoType
                        local unlockSpell = DeepCopy(addSpells)
                        unlockSpell.SpellId = spellId
                        unlockSpell.Level = spellStat.Level
                        table.insert(extraPassives, { Boost = MakeBoost_UnlockSpell(unlockSpell, false) })
                        AddPassiveIcon(spellStat.DisplayName, spellStat.Description, spellStat.Icon)
                    end
                end
            end
        end
    end

end

---Adds the passives to the feat details, if present.
---@param parent ExtuiTreeParent
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
function AddFeaturesToFeatDetailsUI(parent, feat, extraPassives)
    if #feat.PassivesAdded > 0 or #extraPassives > 0 or #feat.AddSpells > 0 then
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()
        AddFeaturesToCell(parent, feat, extraPassives)
    end
end