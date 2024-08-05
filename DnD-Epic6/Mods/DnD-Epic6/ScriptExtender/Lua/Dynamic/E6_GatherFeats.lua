
---Returns true if the feat is supported, false otherwise.
---@param feat any
---@return string?
local function E6_IsFeatSupported(feat)
    -- We don't support adding spells yet
    if feat.AddSpells ~= nil and #feat.AddSpells > 0 then
        return "the feat adds spells"
    end
    -- We don't support requirements filtering yet
    if feat.Requirements ~= nil and string.len(feat.Requirements) > 0 then
        return "the feat has requirements"
    end
    -- We don't support abilities yet
    if feat.SelectAbilities ~= nil and #feat.SelectAbilities > 0 then
        return "the feat selects abilities"
    end
    -- We don't support ability bonuses yet
    if feat.SelectAbilityBonus ~= nil and #feat.SelectAbilityBonus > 0 then
        return "the feat selects ability bonuses"
    end
    -- We don't support equipment yet
    if feat.SelectEquipment ~= nil and #feat.SelectEquipment > 0 then
        return "the feat selects equipment"
    end
    -- We don't support passives yet
    if feat.SelectPassives ~= nil and #feat.SelectPassives > 0 then
        return "the feat selects passives"
    end
    -- We don't support skills yet
    if feat.SelectSkills ~= nil and #feat.SelectSkills > 0 then
        return "the feat selects skills"
    end
    -- We don't support skill expertise yet
    if feat.SelectSkillsExpertise ~= nil and #feat.SelectSkillsExpertise > 0 then
        return "the feat selects skill expertise"
    end
    -- We don't support spell yet
    if feat.SelectSpells ~= nil and #feat.SelectSpells > 0 then
        return "the feat selects spells"
    end
    return nil
end

---@return table<string,table>
function E6_ProcessFeats()
    -- Maps feat uuid to the properties, merging feat and featdescription lsx files.
    -- We go in mod order and overwrite any settings found.
    -- First:
    --  featSet[uuid].Desc = <description>
    --  featSet[uuid].Spec = <specification>
    local featSet = {}
    local feats = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.Feat)
    for _, featid in ipairs(feats) do
        local feat = Ext.StaticData.Get(featid, Ext.Enums.ExtResourceManagerType.Feat)
        local featRejectReason = E6_IsFeatSupported(feat)
        if featRejectReason == nil then
            featSet[featid] = {Spec = feat}
        else
            _E6P("Skipping unsupported feat " .. feat.Name .. ": " .. featRejectReason)
        end
    end
    local featDescriptions = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.FeatDescription)
    for _, descriptionid in ipairs(featDescriptions) do
        local description = Ext.StaticData.Get(descriptionid, Ext.Enums.ExtResourceManagerType.FeatDescription)
        if featSet[description.FeatId] ~= nil then
            featSet[description.FeatId].Desc = description
            --_D(featSet[description.FeatId])
        end
    end

    for _, featInfo in pairs(featSet) do
        _E6P("Allowing feat: " .. featInfo.Spec.Name)
    end

    return featSet
end
