
---Returns true if the feat is supported, false otherwise.
---@param feat ResourceFeat The feat to check for support.
---@return string? nil if supported, a string indicating the reason if not supported.
local function E6_IsFeatSupported(feat)
    -- We don't support ability bonuses yet
    if feat.SelectAbilityBonus ~= nil and #feat.SelectAbilityBonus > 0 then
        return "the feat selects ability bonuses"
    end
    -- We don't support equipment yet
    if feat.SelectEquipment ~= nil and #feat.SelectEquipment > 0 then
        return "the feat selects equipment"
    end
    return nil
end

local featOverrideAllowMultiple = {}
featOverrideAllowMultiple["019564a0-f136-4139-94ea-040f94bbaf19"] = "Skilled"
featOverrideAllowMultiple["d10c01e5-50f9-4ffa-b20d-ffbfb89ab554"] = "SkillExpert"
featOverrideAllowMultiple["b13c4744-1d45-42da-b92c-e09f598ab1c3"] = "Resilient"
featOverrideAllowMultiple["08a88b82-3e78-4189-8996-15dcaaa676e3"] = "EldritchAdept"

---Applies overrides to feats to allow or constrain feats further.
---@param feat FeatType The feat entry to update
---@param spec ResourceFeat The specification table for the feat from Feats.lsx
local function E6_ApplyFeatOverrides(feat, spec)
    local featId = feat.ID
    if featOverrideAllowMultiple[featId] then
        feat.CanBeTakenMultipleTimes = true
    end

    E6_ApplyFeatFiltering(feat, spec)
end

---Processes a property list by applying a function to each element and returning a table of the results.
---@param sourceList table[]
---@param func function
---@return table
local function ProcessProperty(sourceList, func)
    local result = {}
    for _,source in ipairs(sourceList) do
        table.insert(result, func(source))
    end
    return result
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectAbilitiesType[] The list of passive options for the feat.
local function ProcessAbilities(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Arg2,
            Max = source.Arg3,
            Source = source.Arg4,
            SourceId = source.UUID
        }
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectSkillsType[] The list of passive options for the feat.
local function ProcessSkills(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Amount,
            Source = source.Arg3,
            SourceId = source.UUID
        }
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectSkillExpertiseType[] The list of passive options for the feat.
local function ProcessSkillExpertise(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Amount,
            Arg3 = source.Arg3,
            Source = source.Arg4,
            SourceId = source.UUID
        }
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectPassiveType[] The list of passive options for the feat.
local function ProcessPassives(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Amount,
            Unknown = source.Amount2,
            Arg3 = source.Arg3,
            SourceId = source.UUID
        }
    end)
end

---Converts the source object, extracting common core spell information for AddSpells and SelectSpells.
---@param source table The source object to convert.
---@return SelectSpellBaseType The common core spell information.
local function ProcessSpellBase(source)
    return {
        SpellsId = source.SpellUUID,
        ActionResource = source.ActionResource,
        PrepareType = source.PrepareType.Label,
        CooldownType = source.CooldownType.Label
    }
end

---Processes a passive list into the passive options for the feat.
---@param sourceList ResourceProgressionAddedSpell The source information to convert.
---@return AddSpellsType[] The list of passive options for the feat.
local function ProcessAddSpells(sourceList)
    return ProcessProperty(sourceList, function(source)
        ---@type AddSpellsType
        local result = ProcessSpellBase(source)
        result.Ability = source.Ability.Label
        if result.Ability == "None" then
            result.Ability = "Intelligence"
        end
        return result
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList ResourceProgressionSpell The source information to convert.
---@return SelectSpellsType[] The list of passive options for the feat.
local function ProcessSelectSpells(sourceList)
    return ProcessProperty(sourceList, function(source)
        ---@type SelectSpellsType
        local result = ProcessSpellBase(source)
        result.Ability = source.CastingAbility.Label
        result.Count = source.Amount
        if result.Ability == "None" then
            result.Ability = "Intelligence"
        end
        return result
    end)
end


---Creates a feat info object from the feat specification and description.
---@param featId GUIDSTRING The feat Id to create the feat info for.
---@param spec ResourceFeat The specification of the feat.
---@param desc table The description of the feat.
---@return FeatType The feat information object.
local function E6_MakeFeatInfo(featId, spec, desc)
    local passivesAdded = {}
    if spec.PassivesAdded then
        passivesAdded = SplitString(spec.PassivesAdded, ";")
    end

    ---@type FeatType
    local feat = {
        ID = featId,
        ShortName = spec.Name,
        DisplayName = Ext.Loca.GetTranslatedString(desc.DisplayName.Handle.Handle, desc.DisplayName.Handle.Version),
        Description = Ext.Loca.GetTranslatedString(desc.Description.Handle.Handle, desc.Description.Handle.Version),
        CanBeTakenMultipleTimes = spec.CanBeTakenMultipleTimes,
        HasRequirements = {},
        PassivesAdded = passivesAdded,
        SelectAbilities = ProcessAbilities(spec.SelectAbilities),
        SelectSkills = ProcessSkills(spec.SelectSkills),
        SelectSkillsExpertise = ProcessSkillExpertise(spec.SelectSkillsExpertise),
        SelectPassives = ProcessPassives(spec.SelectPassives),
        AddSpells = ProcessAddSpells(spec.AddSpells),
        SelectSpells = ProcessSelectSpells(spec.SelectSpells)
    }

    E6_ApplyFeatOverrides(feat, spec)
    return feat
end

local E6_FeatSet = nil

---Gathers feats from the game and converts them to a format that can be used by the E6 system.
---@return table<GUIDSTRING,FeatType> The mapping of feat ids to the feat information.
function E6_GatherFeats()
    if E6_FeatSet ~= nil then
        return E6_FeatSet
    end

    local featSet = {}
    E6_FeatSet = featSet

    local feats = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.Feat)
    for _, featid in ipairs(feats) do
        ---@type ResourceFeat The feat specification from the game.
        local feat = Ext.StaticData.Get(featid, Ext.Enums.ExtResourceManagerType.Feat)
        local featRejectReason = E6_IsFeatSupported(feat)
        if featRejectReason == nil then
            featSet[featid] = {Spec = feat}
        else
            _E6Warn("Skipping unsupported feat " .. feat.Name .. ": " .. featRejectReason)
        end
    end

    local featDescriptions = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.FeatDescription)
    for _, descriptionid in ipairs(featDescriptions) do
        ---@type ResourceFeatDescription The feat specification from the game.
        local description = Ext.StaticData.Get(descriptionid, Ext.Enums.ExtResourceManagerType.FeatDescription)
        local id = description.FeatId
        if featSet[id] ~= nil then
            local spec = featSet[id].Spec
            featSet[id] = E6_MakeFeatInfo(id, spec, description)
        end
    end

    return featSet
end

---@param feat FeatType The feat to test for
---@param entity EntityHandle The entity to test against
---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
---@param filterOnPass boolean Call onFilter if the requirement is met, not just when it fails
---@param onMet function The function to call if the requirement is met. Only called once.
---@param onFilter function The function to call if the requirement is not met, which takes the FeatType and FeatMessageType. May be called multiple times.
local function FeatRequirementTest(feat, entity, playerInfo, filterOnPass, onMet, onFilter)
    if not feat.CanBeTakenMultipleTimes and playerInfo.PlayerFeats[feat.ID] ~= nil then
        onFilter(feat, ToMessageLoca("ha0a03263g1b55g40c2g8a7fg5313663ee3a5")) -- The feat has already been selected.
        return
    end

    if not feat.HasRequirements then
        onMet(feat)
        return
    end

    local isMet = true
    for _, req in ipairs(feat.HasRequirements) do
        local met, messages = req(entity, playerInfo)
        if filterOnPass or not met then
            ForEachMessage(messages, function(message)
                onFilter(feat, message)
            end)
            isMet = isMet and met
        end
    end
    if isMet then
        onMet(feat)
    end
end

---Determines if the character meets the requirements for a feat.
---@param feat FeatType The feat to test for
---@param entity EntityHandle The entity to test against
---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
---@return FeatMessageType[] The reasons why the feat requirements were not met.
function GatherFailedFeatRequirements(feat, entity, playerInfo)
    local results = {}
    FeatRequirementTest(feat, entity, playerInfo, true, function(feat)
    end,
    function(feat, message)
        if message ~= RequirementsMet then
            table.insert(results, message)
        end
    end)
    return results
end

---Gathers the feats that the player can select. It checks constraints server side as client doesn't
---seem to have all the data to do so.
---@param entity EntityHandle The player entity to test against.
---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
---@return string[] The collection of feats the player can actually select
---@return string[] The collection of feats that were filtered out due to requirements.
function GatherSelectableFeatsForPlayer(entity, playerInfo)
    local allFeats = E6_GatherFeats()

    local featList = {}
    local filtered = {}
    local visited = {}
    for featId, feat in pairs(allFeats) do
        FeatRequirementTest(feat, entity, playerInfo, false, function(feat)
            table.insert(featList, featId)
        end,
        function(feat, message)
            if not visited[featId] then
                visited[featId] = true
                table.insert(filtered, featId)
            end
        end)
    end
    return featList, filtered
end

