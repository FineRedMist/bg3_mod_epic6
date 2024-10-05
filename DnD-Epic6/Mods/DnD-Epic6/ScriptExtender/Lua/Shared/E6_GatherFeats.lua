
---Returns true if the feat is supported, false otherwise.
---@param feat any
---@return string?
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

local races = {
    Human = "0eb594cb-8820-4be6-a58d-8be7a1a98fba",
    Elf = "6c038dcb-7eb5-431d-84f8-cecfaf1c0c5a",
    HighElf = "4fda6bce-0b91-4427-901f-690c2d091c47",
    WoodElf = "a459ba68-a9ec-4c8e-b127-602615f5b4c0",
    Drow = "4f5d1434-5175-4fa9-b7dc-ab24fba37929",
    Dwarf = "0ab2874d-cfdc-405e-8a97-d37bfbb23c52",
    Halfling = "78cd3bcc-1c43-4a2a-aa80-c34322c16a04",
    Gnome = "f1b3f884-4029-4f0f-b158-1f9fe0ae5a0d",
    DeepGnome = "3560f4a2-c0b8-4f8b-baf8-6b6eaef0c160",
    Tiefling = "b6dccbed-30f3-424b-a181-c4540cf38197",
    HalfElf = "45f4ac10-3c89-4fb2-b37d-f973bb9110c0",
    HighHalfElf = "30fafb0b-7c8b-4917-bd2a-536233b35d3c",
    WoodHalfElf = "76057327-da03-4398-aaf0-c59345ef3a8b",
    HalfDrow = "e966f47f-998a-41df-ad86-d83b44299efb",
    Dragonborn = "9c61a74a-20df-4119-89c5-d996956b6c66",
    HalfOrc = "5c39a726-71c8-4748-ba8d-f768b3c11a91"
}

local featRacialConstraints = {}
featRacialConstraints["ebf69e0c-9a32-4a16-9b7a-1f2b0036d15d"] = {races.Dragonborn} -- DragonHide
--featRacialConstraints["fa386a9d-962b-4d73-af04-660377fa0e0c"] = {races.Dwarf} -- DwarvenFortitude
featRacialConstraints["c3810995-3bb1-429e-9411-fa2bc9426518"] = {races.Dwarf, races.Gnome, races.Halfling} -- SquatNimbleness
featRacialConstraints["daf81082-ce05-4835-b8a0-5e60b2f027e3"] = {races.Elf, races.HighElf, races.WoodElf, races.Drow, races.HalfElf} -- ElvenAccuracy
--featRacialConstraints["09859f63-ad8e-4950-9f07-ad8e81ed91b7"] = {races.WoodElf, races.WoodHalfElf} -- WoodElfMagic
featRacialConstraints["74a5d838-d72c-4205-a42e-9f4bf1e52b3c"] = {races.Gnome} -- FadeAway
featRacialConstraints["38614cda-1b13-4583-8fa8-18a7dd3bb6b6"] = {races.HalfOrc} -- OrcishFury
featRacialConstraints["e65b2814-fc8e-4290-821b-4e243f64982b"] = {races.Halfling} -- BountifulLuck
featRacialConstraints["6c59e67a-76f9-4c9b-af59-dbe6bb2048f7"] = {races.Halfling} -- SecondChance
featRacialConstraints["e0457947-44b7-4316-b700-d1a69a10ced7"] = {races.Tiefling} -- FlamesOfPhlegethos
featRacialConstraints["168923b1-75a0-46dd-b6a8-bf44736e3ec8"] = {races.Tiefling} -- InfernalConstitution
featRacialConstraints["5a726c22-5bc8-442f-b161-7f1b338879ff"] = {races.HalfElf} -- EverybodysFriend
--featRacialConstraints["8db4b515-2bed-48fc-a15b-2f357c68e91d"] = {races.DeepGnome} -- SvirfneblinMagic


---Adds a requirement for the feat.
---@param feat table The feat to add the requirement to.
---@param testFunc function the function to test the requirement.
local function E6_AddFeatRequirement(feat, testFunc)
    if not feat.HasRequirements then
        feat.HasRequirements = { testFunc }
        return
    end
    table.insert(feat.HasRequirements, testFunc)
end

---Applies racial constraints to feats and updates the HasRequirements function to test it.
---@param feat table The feat entry to update
local function E6_ApplyRacialConstraints(feat)
    local featId = feat.ID
    if featRacialConstraints[featId] then
        local raceConstraint = featRacialConstraints[featId]
        local raceRequirement = function(entity, playerInfo)
            local name = GetCharacterName(entity)
            if not entity.CharacterCreationStats then
                _E6Error("Racial Constraints: " .. name .. " does not have CharacterCreationStats")
                return false
            end
            local race = entity.CharacterCreationStats.Race
            if not race then
                _E6Error("Racial Constraints: " .. name .. " does not have CharacterCreationStats.Race")
                return false
            end
            for raceName,raceId in ipairs(raceConstraint) do
                if race == raceId then
                    --_E6P("Racial Constraints: " .. name .. " has the race " .. raceName .. " matching the constraint for: " .. feat.ShortName)
                    return true
                end
            end
            local subRace = entity.CharacterCreationStats.SubRace
            if subRace then
                for raceName,raceId in ipairs(raceConstraint) do
                    if subRace == raceId then
                        --_E6P("Racial Constraints: " .. name .. " has the subrace " .. raceName .. " matching the constraint for: " .. feat.ShortName)
                        return true
                    end
                end
            end
            --_E6Warn("Racial Constraints: " .. name .. " with race " .. race .. " and subrace " .. tostring(subRace) .. " does not match the constraint for: " .. feat.ShortName)
            return false
        end
        E6_AddFeatRequirement(feat, raceRequirement)
    end
end

---Indicates a match failure
---@param feat table The feat entry for the ability requirement
---@param matchResult? table The expression that failed to match
---@return function That evaluates to false, always.
local function E6_MatchFailure(feat, matchResult)
    if matchResult then
        _E6Error("Failed to match the feat " .. feat.ShortName .. " requirement: " .. matchResult[1])
    end
    return function(entity, abilityScores)
        return false
    end
end

---Generates the function to test the character for meeting the ability requirement for selecting abilities. In particular, if the player has
---maxed out their abilities for all the selectable abilities, then prevent the feat from being selectable.
---@param feat table The feat entry for the ability requirement
local function E6_ApplySelectAbilityRequirement(feat)
    if #feat.SelectAbilities == 0 then
        return
    end
    for _, ability in ipairs(feat.SelectAbilities) do
        local abilityList = Ext.StaticData.Get(ability.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if not abilityList then
            _E6Error("Failed to retrieve the ability list for feat " .. feat.ShortName .. " from source " .. ability.SourceId)
            E6_AddFeatRequirement(feat, E6_MatchFailure(feat, nil))
            return
        end
        local abilityNames = {}
        for _,abilityName in ipairs(abilityList.Abilities) do
            table.insert(abilityNames, abilityName.Label)
        end
        local abilityRequirement = function(entity, playerInfo)
            local abilityScores = playerInfo.AbilityScores
            -- determine the total number of assignable points across the listed abilities. If the count is less than granted,
            -- return false.
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
---@param feat table The feat entry for the ability requirement
---@param abilityMatch table The matched requirement parameters from the requirement expression
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
---@param feat table The feat entry for the ability requirement
---@param proficiencyMatch table The matched requirement parameters from the requirement expression
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
---@param feat table The feat entry to update
---@param spec table The specification table for the feat from Feats.lsx
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
---@param feat table The feat to test against
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
                --_E6P("Ability constraint passed for " .. feat.ShortName .. ": " .. ability .. " is " .. abilityScore.Current .. " + " .. delta .. " <= " .. abilityScore.Maximum)
            end
            return true
        end

        E6_AddFeatRequirement(feat, validateAbilityBoosts)
    end
end

---Applies overrides to feats to allow or constrain feats further.
---@param feat table The feat entry to update
---@param spec table The specification table for the feat from Feats.lsx
local function E6_ApplyFeatOverrides(feat, spec)
    local featId = feat.ID
    if featOverrideAllowMultiple[featId] then
        feat.CanBeTakenMultipleTimes = true
    end
    if Ext.IsServer() then -- we don't need these on the client
        E6_ApplyFeatAbilityConstraints(feat)
        E6_ApplySelectAbilityRequirement(feat)
        E6_ApplyFeatRequirements(feat, spec)
        E6_ApplyRacialConstraints(feat)
    end
    -- Do I want to add feat constraints (like for the giant feats)?
end

---Creates a feat info object from the feat specification and description.
---@param featId string
---@param spec table
---@param desc table
---@return table
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
    local function ProcessProperty(sourceList, func)
        local result = {}
        for _,source in ipairs(sourceList) do
            table.insert(result, func(source))
        end
        return result
    end

    feat.SelectAbilities = ProcessProperty(spec.SelectAbilities, function(source)
        return {
            Count = source.Arg2,
            Max = source.Arg3,
            Source = source.Arg4,
            SourceId = source.UUID
        }
    end)
    feat.SelectSkills = ProcessProperty(spec.SelectSkills, function(source)
        return {
            Count = source.Amount,
            Source = source.Arg3,
            SourceId = source.UUID
        }
    end)
    feat.SelectSkillsExpertise = ProcessProperty(spec.SelectSkillsExpertise, function(source)
        return {
            Count = source.Amount,
            Arg3 = source.Arg3,
            Source = source.Arg4,
            SourceId = source.UUID
        }
    end)
    feat.SelectPassives = ProcessProperty(spec.SelectPassives, function(source)
        return {
            Count = source.Amount,
            Unknown = source.Amount2,
            Arg3 = source.Arg3,
            SourceId = source.UUID
        }
    end)
    local processSpells = function(source)
        return {
            SpellsId = source.SpellUUID,
            SelectorId = source.SelectorId,
            ActionResource = "",
            PrepareType = source.PrepareType.Label,
            CooldownType = source.CooldownType.Label
        }
    end
    feat.AddSpells = ProcessProperty(spec.AddSpells, function(source)
        local result = processSpells(source)
        result.Ability = source.Ability
        return result
    end)
    feat.SelectSpells = ProcessProperty(spec.SelectSpells, function(source)
        local result = processSpells(source)
        result.Ability = source.CastingAbility
        result.Count = source.Amount
        return result
    end)

    E6_ApplyFeatOverrides(feat, spec)
    return feat
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
            _E6Warn("Skipping unsupported feat " .. feat.Name .. ": " .. featRejectReason)
        end
    end
    local featDescriptions = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.FeatDescription)
    for _, descriptionid in ipairs(featDescriptions) do
        local description = Ext.StaticData.Get(descriptionid, Ext.Enums.ExtResourceManagerType.FeatDescription)
        local id = description.FeatId
        if featSet[id] ~= nil then
            local spec = featSet[id].Spec
            featSet[id] = E6_MakeFeatInfo(id, spec, description)
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

    --for _, featInfo in pairs(featSet) do
    --    _E6P("Allowing feat: " .. featInfo.ShortName)
    --end

    return featSet
end
