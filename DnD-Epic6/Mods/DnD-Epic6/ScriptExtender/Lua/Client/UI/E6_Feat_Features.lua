---Adds the list of passives to the cell.
---@param parent ExtuiTreeParent
---@param playerInfo PlayerInformationType
---@param feat FeatType
---@param extraPassives ExtraPassiveType[] Passives to add to the passives list for when there is only one ability to select. 
local function AddFeaturesToCell(parent, playerInfo, feat, extraPassives)
    local avoidDupes = {}

    ---@type ExtuiTableCell The cell to add the passives to.
    local centeredCell = nil

    ---Adds a passive icon and its corresponding tooltip.
    ---@param iconId string
    ---@param displayNameId string
    ---@param descriptionId string
    ---@param descriptionParams string[]?
    local function AddPassiveIcon(iconId, displayNameId, descriptionId, descriptionParams)
        local key = displayNameId .. "|" .. descriptionId .. "|" .. iconId
        if not avoidDupes[key] then
            local icon = centeredCell:AddImage(iconId, DefaultIconSize)
            local builder = AddTooltip(icon)
            builder.preText = { function(text) return playerInfo.Resolver:Resolve(text) end }
            builder:AddText(displayNameId):AddSpacing():AddLoca(descriptionId, descriptionParams)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end
    ---@param spell SelectSpellInfoUIType? The spell data.
    local function AddSpell(spell)
        if not spell then
            return
        end
        local key = spell.DisplayName .. "|" .. spell.Description .. "|" .. spell.Icon
        if not avoidDupes[key] then
            local icon = AddSpellIcon(centeredCell, spell, playerInfo, false)
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
        -- We are allowing feats with passives that can't be found. If it doesn't exist, don't show it.
        -- It does mean if it does get fixed, the feat will need to be reapplied to get the effect (if any).
        if passiveStat then
            AddPassiveIcon(passiveStat.Icon, passiveStat.DisplayName, passiveStat.Description, SplitString(passiveStat.DescriptionParams, ";"))
        else
            _E6Warn("The feat '" .. feat.ShortName .. "' has a passive " .. passive .. " that can't be found. When fixed, the character may need to reapply the feat to get the effect.")
        end
    end
    for _,passive in ipairs(extraPassives) do
        AddPassiveIcon(passive.Icon, passive.DisplayName, passive.Description, passive.DescriptionParams)
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
                    AddSpell(SpellInfoFromSpellCollection(addSpells, spellId, playerInfo))
                end
            end
        end
    end

end

---Adds the passives to the feat details, if present.
---@param parent ExtuiTreeParent
---@param playerInfo PlayerInformationType
---@param feat FeatType
---@param extraPassives ExtraPassiveType[] Passives to add to the passives list for when there is only one ability to select. 
function AddFeaturesToFeatDetailsUI(parent, playerInfo, feat, extraPassives)
    if #feat.PassivesAdded > 0 or #extraPassives > 0 or #feat.AddSpells > 0 then
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()
        AddFeaturesToCell(parent, playerInfo, feat, extraPassives)
    end
end