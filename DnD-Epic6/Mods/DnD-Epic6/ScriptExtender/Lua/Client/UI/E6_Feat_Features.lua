---Adds the list of passives to the cell.
---@param cell ExtuiTableCell
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
local function AddFeaturesToCell(cell, feat, extraPassives)
    local avoidDupes = {}

    local function AddPassiveIcon(displayNameId, descriptionId, iconId)
        local key = displayNameId .. "|" .. descriptionId .. "|" .. iconId
        if not avoidDupes[key] then
            local icon = cell:AddImage(iconId)
            AddLocaTooltipTitled(icon, displayNameId, descriptionId)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end

    for _,passive in ipairs(feat.PassivesAdded) do
        local passiveStat = Ext.Stats.Get(passive,  -1, true, true)
        AddPassiveIcon(passiveStat.DisplayName, passiveStat.Description, passiveStat.Icon)
    end
    for _,passive in ipairs(extraPassives) do
        AddPassiveIcon(passive.DisplayName, passive.Description, passive.Icon)
    end
    for _,addSpells in ipairs(feat.AddSpells) do
        table.insert(extraPassives, { Boost = MakeBoost_AddSpells(addSpells) })
        local spells = Ext.StaticData.Get(addSpells.SpellsId, Ext.Enums.ExtResourceManagerType.SpellList)
        _E6P("Spell info for " .. addSpells.SpellsId .. ": " .. E6_ToJson(spells, {}))
        if spells then
            for _,spellId in pairs(spells.Spells) do -- not ipairs intentionally, it doesn't handle Array_FixedString for some reason.
                local spellStat = Ext.Stats.Get(spellId, -1, true, true)
                if spellStat then
                    AddPassiveIcon(spellStat.DisplayName, spellStat.Description, spellStat.Icon)
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
    if #feat.PassivesAdded > 0 or #extraPassives then
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()
        AddLocaTitle(parent, "hffc72a17g6934g42f8ga935g447764ee6f43") -- Features
        local passivesCell = CreateCenteredControlCell(parent, "Passives", parent.Size[1] - 60)
        AddFeaturesToCell(passivesCell, feat, extraPassives)
    end
end