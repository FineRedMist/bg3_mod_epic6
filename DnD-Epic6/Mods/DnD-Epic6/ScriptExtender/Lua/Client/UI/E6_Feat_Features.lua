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
            local resolver = ParameterResolver:new(playerInfo)
            local builder = AddTooltip(icon)
            builder.preText = { function(text) return resolver:Resolve(text) end }
            builder:AddText(displayNameId):AddSpacing():AddLoca(descriptionId, descriptionParams)
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
        AddPassiveIcon(passiveStat.Icon, passiveStat.DisplayName, passiveStat.Description, SplitString(passiveStat.DescriptionParams, ";"))
    end
    for _,passive in ipairs(extraPassives) do
        AddPassiveIcon(passive.Icon, passive.DisplayName, passive.Description, nil)
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
                        AddPassiveIcon(spellStat.Icon, spellStat.DisplayName, spellStat.Description, SplitString(spellStat.DescriptionParams, ";"))
                    end
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