
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

---Adds a requirement for the feat.
---@param feat FeatType The feat to add the requirement to.
---@param testFunc function the function to test the requirement.
local function E6_AddFeatRequirement(feat, testFunc)
    if not feat.HasRequirements then
        feat.HasRequirements = { testFunc }
        return
    end
    table.insert(feat.HasRequirements, testFunc)
end

---Indicates a match failure
---@param feat table The feat entry for the ability requirement
---@param matchResult? table The expression that failed to match
---@return function That evaluates to false, always.
local function E6_MatchFailure(feat, matchResult)
    if matchResult then
        _E6Error("Failed to match the feat " .. feat.ShortName .. " requirement--please post this as a bug on Vortex for DnD-Epic6 to investigate: " .. matchResult[1])
    end
    return function(entity, playerInfo)
        return false
    end
end

---Generates the function to test the character for meeting the ability requirement for selecting abilities. In particular, if the player has
---maxed out their abilities for all the selectable abilities, then prevent the feat from being selectable.
---@param feat FeatType The feat entry for the ability requirement
local function E6_ApplySelectAbilityRequirement(feat)
    if #feat.SelectAbilities == 0 then
        return
    end
    for _, ability in ipairs(feat.SelectAbilities) do
        ---@type ResourceAbilityList
        local abilityList = Ext.StaticData.Get(ability.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if not abilityList then
            _E6Error("Failed to retrieve the ability list for feat " .. feat.ShortName .. " from source " .. ability.SourceId)
            E6_AddFeatRequirement(feat, E6_MatchFailure(feat, nil))
            return
        end
        ---@type string[] The list of abilities in the ability list.
        local abilityNames = {}
        for _,abilityName in ipairs(abilityList.Abilities) do
            table.insert(abilityNames, abilityName.Label)
        end
        local abilityRequirement = function(entity, playerInfo)
            local abilityScores = playerInfo.AbilityScores
            -- Determine the total number of assignable points across the listed abilities. If the count is less than granted, return false.
            local availablePointRoom = 0
            for _,abilityName in ipairs(abilityNames) do
                local abilityScore = abilityScores[abilityName]
                if not abilityScore then
                    _E6Error("Select Ability Constraint(" .. feat.ShortName .. "): " .. GetCharacterName(entity) .. " is missing the ability score for " .. abilityName)
                    return false
                end
                availablePointRoom = availablePointRoom + abilityScore.Maximum - abilityScore.Current
            end
            if availablePointRoom < ability.Count then
                return false
            end
            return true
        end
        E6_AddFeatRequirement(feat, abilityRequirement)
    end
end

---Generates the function to test the character for meeting the ability requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param abilityMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeAbilityRequirement(feat, abilityMatch)
    local ability = abilityMatch[1]
    local value = tonumber(abilityMatch[2])
    return function(entity, playerInfo)
        local abilityScores = playerInfo.AbilityScores
        local name = GetCharacterName(entity)
        if not abilityScores then
            _E6Error("Ability Constraint(" .. feat.ShortName .. ": " .. ability .. " >= " .. tostring(value) .. "): " .. name .. " is missing the ability scores")
            return false
        end
        local abilityScore = abilityScores[ability]
        if not abilityScore then
            _E6Error("Ability Constraint(" .. feat.ShortName .. ": " .. ability .. " >= " .. tostring(value) .. "): " .. name .. " is missing the ability score for " .. ability)
            return false
        end
        if abilityScore.Current >= value then
            return true
        end
        return false
    end
end

---Generates the function to test the character for meeting the proficiency requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeProficiencyRequirement(feat, proficiencyMatch)
    local proficiency = proficiencyMatch[1]
    return function(entity, playerInfo)
        local name = GetCharacterName(entity)
        local proficiencyComp = entity.Proficiency
        if not proficiencyComp then
            _E6Error("Proficiency Constraint(" .. feat.ShortName .. ": " .. proficiency .. "): " .. name .. " is missing the Proficiency component")
            return false
        end
        local proficiencyFlags = proficiencyComp.Flags
        if proficiencyFlags == nil then
            _E6Error("Proficiency Constraint(" .. feat.ShortName .. ": " .. proficiency .. "): " .. name .. " is missing the Proficiency.Flags")
            return false
        end
        for _,proficiencyFlag in ipairs(proficiencyFlags) do
            if proficiencyFlag == proficiency then
                return true
            end
        end
        return false
    end
end

local featRequirementRegexes = {
    {
        Regex = "FeatRequirementAbilityGreaterEqual%('(%w+)',(%d+)%)",
        Func = E6_MakeAbilityRequirement
    },
    {
        Regex = "FeatRequirementProficiency%('(%w+)'%)",
        Func = E6_MakeProficiencyRequirement
    },
    {
        Regex = "(.+)",
        Func = E6_MatchFailure
    }
}

---Adds the requirements the feat specifies to the feat entry.
---@param feat FeatType The feat entry to update
---@param spec ResourceFeat The specification table for the feat from Feats.lsx
local function E6_ApplyFeatRequirements(feat, spec)
    if spec.Requirements == nil then
        return
    end
    if string.len(spec.Requirements) == 0 then
        return
    end
    local requirements = SplitString(spec.Requirements, ";")
    for _, req in ipairs(requirements) do
        if string.len(req) > 0 then
            local matched = false
            for _,featReqRegex in ipairs(featRequirementRegexes) do
                local regex = featReqRegex.Regex
                local reqFunc = featReqRegex.Func
                local matchResult = GetFullMatch(req, regex)
                if matchResult then
                    E6_AddFeatRequirement(feat, reqFunc(feat, matchResult))
                    matched = true
                    break
                end
            end
            if not matched then
                E6_AddFeatRequirement(feat, E6_MatchFailure(feat, req))
            end
        end
    end
end

---Gathers any ability modifiers from the passive ability boosts.
---Note: This will be used for both feats and for passives listed in the passive list for selection. 
---@param passiveName string Name of the passive to gather the ability modifiers from. 
---@return table<string,number> A mapping of ability name to delta value.
local function GatherPassiveAbilityModifiers(passiveName)
    local result = {}
    local passive = Ext.Stats.Get(passiveName, -1, true, true)
    if passive and passive.Boosts then
        local boosts = SplitString(passive.Boosts, ";")
        for _,boost in ipairs(boosts) do
            local ability, delta = ParseAbilityBoost(boost)
            if ability then
                if not result[ability] then
                    result[ability] = delta
                else
                    result[ability] = result[ability] + delta
                end
            end
        end
    end
    return result
end

---Merges the ability boosts from the passive into the general ability boost table.
---@param abilityBoosts table<string,number>
---@param passiveBoosts table<string,number>
local function MergeAbilityBoosts(abilityBoosts, passiveBoosts)
    for ability,delta in pairs(passiveBoosts) do
        if not abilityBoosts[ability] then
            abilityBoosts[ability] = delta
        else
            abilityBoosts[ability] = abilityBoosts[ability] + delta
        end
    end
end

---Determines whether taking the feat will raise the player's abilities above the maximum
---@param feat FeatType The feat to test against
local function E6_ApplyFeatAbilityConstraints(feat)
    local abilityBoosts = {}
    for _,passiveName in ipairs(feat.PassivesAdded) do
        local passiveBoosts = GatherPassiveAbilityModifiers(passiveName)
        MergeAbilityBoosts(abilityBoosts, passiveBoosts)
    end
    if next(abilityBoosts) ~= nil then
        local function validateAbilityBoosts(entity, playerInfo)
            local abilityScores = playerInfo.AbilityScores
            for ability,delta in pairs(abilityBoosts) do
                local name = GetCharacterName(entity)
                if not abilityScores then
                    _E6Error("Ability Constraints: " .. name .. " is missing the ability scores")
                    return false
                end
                local abilityScore = abilityScores[ability]
                if not abilityScore then
                    _E6Error("Ability Constraints: " .. name .. " is missing the ability score for " .. ability)
                    return false
                end
                if abilityScore.Current + delta > abilityScore.Maximum then
                    _E6Warn("Ability constraint failed for " .. feat.ShortName .. ": " .. ability .. " is " .. abilityScore.Current .. " + " .. delta .. " > " .. abilityScore.Maximum)
                    return false
                end
            end
            return true
        end

        E6_AddFeatRequirement(feat, validateAbilityBoosts)
    end
end

---Applies overrides to feats to allow or constrain feats further.
---@param feat FeatType The feat entry to update
---@param spec ResourceFeat The specification table for the feat from Feats.lsx
local function E6_ApplyFeatOverrides(feat, spec)
    local featId = feat.ID
    if featOverrideAllowMultiple[featId] then
        feat.CanBeTakenMultipleTimes = true
    end
    if Ext.IsServer() then -- we don't need these on the client
        E6_ApplyFeatAbilityConstraints(feat)
        E6_ApplySelectAbilityRequirement(feat)
        E6_ApplyFeatRequirements(feat, spec)
    end
    -- Do I want to add feat constraints (like for the giant feats)?
end

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
        SelectorId = source.SelectorId,
        ActionResource = "",
        PrepareType = source.PrepareType.Label,
        CooldownType = source.CooldownType.Label
    }
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return AddSpellsType[] The list of passive options for the feat.
local function ProcessAddSpells(sourceList)
    return ProcessProperty(sourceList, function(source)
        ---@type AddSpellsType
        local result = ProcessSpellBase(source)
        result.Ability = source.Ability.Label
        return result
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectSpellsType[] The list of passive options for the feat.
local function ProcessSelectSpells(sourceList)
    return ProcessProperty(sourceList, function(source)
        ---@type SelectSpellsType
        local result = ProcessSpellBase(source)
        result.Ability = source.CastingAbility.Label
        result.Count = source.Amount
        return result
    end)
end


---Creates a feat info object from the feat specification and description.
---@param featId GUIDSTRING The feat Id to create the feat info for.
---@param spec ResourceFeat The specification of the feat.
---@param desc table The description of the feat.
---@return FeatType The feat information object.
local function E6_MakeFeatInfo(featId, spec, desc)
    local feat = {
        ID = featId,
        ShortName = spec.Name,
        DisplayName = Ext.Loca.GetTranslatedString(desc.DisplayName.Handle.Handle, desc.DisplayName.Handle.Version),
        Description = Ext.Loca.GetTranslatedString(desc.Description.Handle.Handle, desc.Description.Handle.Version),
        CanBeTakenMultipleTimes = spec.CanBeTakenMultipleTimes,
    }
    if spec.PassivesAdded then
        feat.PassivesAdded = SplitString(spec.PassivesAdded, ";")
    else
        feat.PassivesAdded = {}
    end

    feat.SelectAbilities = ProcessAbilities(spec.SelectAbilities)
    feat.SelectSkills = ProcessSkills(spec.SelectSkills)
    feat.SelectSkillsExpertise = ProcessSkillExpertise(spec.SelectSkillsExpertise)
    feat.SelectPassives = ProcessPassives(spec.SelectPassives)
    feat.AddSpells = ProcessAddSpells(spec.AddSpells)
    feat.SelectSpells = ProcessSelectSpells(spec.SelectSpells)

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

    ---@type GUIDSTRING[] The collection of feats ids from the game.
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
    ---@type GUIDSTRING[] The collection of feats ids from the game.
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
