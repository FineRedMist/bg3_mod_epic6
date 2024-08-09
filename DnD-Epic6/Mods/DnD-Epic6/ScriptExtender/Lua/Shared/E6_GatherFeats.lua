
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

local E6_FeatSet = nil

---@return table<string,table>
function E6_GatherFeats()
    -- Maps feat uuid to the properties, merging feat and featdescription lsx files.
    -- We go in mod order and overwrite any settings found.
    -- First:
    --  featSet[uuid].ID = <uuid>
    --  featSet[uuid].ShortName = <short name of the feat>    
    --  featSet[uuid].DisplayName = <translated display name>
    --  featSet[uuid].Description = <translated description>
    --  featSet[uuid].CanBeTakenMultipleTimes = <whether the feat can be taken multiple times>
    --  featSet[uuid].PassivesAdded = <the list of passives to add for the feat

    if E6_FeatSet ~= nil then
        return E6_FeatSet
    end

    local featSet = {}
    E6_FeatSet = featSet

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
        local id = description.FeatId
        if featSet[id] ~= nil then
            local spec = featSet[id].Spec
            featSet[id].Spec = nil -- remove this as it doesn't last anyway
            featSet[id].ID = id
            featSet[id].ShortName = spec.Name
            featSet[id].CanBeTakenMultipleTimes = spec.CanBeTakenMultipleTimes
            featSet[id].DisplayName = Ext.Loca.GetTranslatedString(description.DisplayName.Handle.Handle, description.DisplayName.Handle.Version)
            featSet[id].Description = Ext.Loca.GetTranslatedString(description.Description.Handle.Handle, description.Description.Handle.Version)
            if spec.PassivesAdded then
                featSet[id].PassivesAdded = SplitString(spec.PassivesAdded, ";")
            else
                featSet[id].PassivesAdded = {}
            end
        end
    end

    -- Remove entries that are missing an ID field.
    local toRemove = {}
    for k, v in pairs(featSet) do
        if v.ID == nil then
            table.insert(toRemove, k)
        end
    end
    for _, k in ipairs(toRemove) do
        featSet[k] = nil
    end

    for _, featInfo in pairs(featSet) do
        _E6P("Allowing feat: " .. featInfo.ShortName)
    end

    return featSet
end
