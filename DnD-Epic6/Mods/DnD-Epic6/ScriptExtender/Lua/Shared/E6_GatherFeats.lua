
---Returns true if the feat is supported, false otherwise.
---@param feat any
---@return string?
local function E6_IsFeatSupported(feat)
    -- We don't support adding spells yet
    if feat.AddSpells ~= nil and #feat.AddSpells > 0 then
        return "the feat adds spells"
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
    Gnome = "0ab2874d-cfdc-405e-8a97-d37bfbb23c52",
    Tiefling = "b6dccbed-30f3-424b-a181-c4540cf38197",
    HalfElf = "45f4ac10-3c89-4fb2-b37d-f973bb9110c0",
    Dragonborn = "9c61a74a-20df-4119-89c5-d996956b6c66",
    HalfOrc = "5c39a726-71c8-4748-ba8d-f768b3c11a91"
}

local featRacialConstraints = {}
featRacialConstraints["ebf69e0c-9a32-4a16-9b7a-1f2b0036d15d"] = {races.Dragonborn} -- DragonHide
featRacialConstraints["fa386a9d-962b-4d73-af04-660377fa0e0c"] = {races.Dwarf} -- DwarvenFortitude
featRacialConstraints["c3810995-3bb1-429e-9411-fa2bc9426518"] = {races.Dwarf, races.Gnome, races.Halfling} -- SquatNimbleness
featRacialConstraints["daf81082-ce05-4835-b8a0-5e60b2f027e3"] = {races.Elf, races.HighElf, races.WoodElf, races.Drow, races.HalfElf} -- ElvenAccuracy
featRacialConstraints["09859f63-ad8e-4950-9f07-ad8e81ed91b7"] = {races.WoodElf} -- WoodElfMagic
featRacialConstraints["74a5d838-d72c-4205-a42e-9f4bf1e52b3c"] = {races.Gnome} -- FadeAway
featRacialConstraints["38614cda-1b13-4583-8fa8-18a7dd3bb6b6"] = {races.HalfOrc} -- OrcishFury
featRacialConstraints["e65b2814-fc8e-4290-821b-4e243f64982b"] = {races.Halfling} -- BountifulLuck
featRacialConstraints["6c59e67a-76f9-4c9b-af59-dbe6bb2048f7"] = {races.Halfling} -- SecondChance
featRacialConstraints["e0457947-44b7-4316-b700-d1a69a10ced7"] = {races.Tiefling} -- FlamesOfPhlegethos
featRacialConstraints["168923b1-75a0-46dd-b6a8-bf44736e3ec8"] = {races.Tiefling} -- InfernalConstitution


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
        local raceRequirement = function(entity)
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
                    _E6P("Racial Constraints: " .. name .. " has the race " .. raceName .. " matching the constraint for: " .. feat.ShortName)
                    return true
                end
            end
            local subRace = entity.CharacterCreationStats.SubRace
            if subRace then
                for raceName,raceId in ipairs(raceConstraint) do
                    if subRace == raceId then
                        _E6P("Racial Constraints: " .. name .. " has the subrace " .. raceName .. " matching the constraint for: " .. feat.ShortName)
                        return true
                    end
                end
            end
            _E6P("Racial Constraints: " .. name .. " with race " .. race .. " and subrace " .. tostring(subRace) .. " does not match the constraint for: " .. feat.ShortName)
            return false
        end
        E6_AddFeatRequirement(feat, raceRequirement)
    end
end

---Indicates a match failure
---@param feat table The feat entry for the ability requirement
---@param matchResult table The expression that failed to match
---@return function That evaluates to false, always.
local function E6_MatchFailure(feat, matchResult)
    if matchResult then
        _E6Error("Failed to match the feat " .. feat.ShortName .. " requirement: " .. matchResult[1])
    end
    return function(entity)
        return false
    end
end

---Generates the function to test the character for meeting the ability requirement specified.
---@param feat table The feat entry for the ability requirement
---@param abilityMatch table The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeAbilityRequirement(feat, abilityMatch)
    _E6P(Ext.Json.Stringify(E6_ToJson(abilityMatch)))
    local ability = string.lower(abilityMatch[1])
    local value = tonumber(abilityMatch[2])
    _E6P("Ability Constraint(" .. feat.ShortName .. ": " .. ability .. ">= " .. tostring(value) .. "): found!")
    return function(entity)
        local name = GetCharacterName(entity)
        _E6P("Ability Constraint(" .. feat.ShortName .. ": " .. ability .. ">= " .. tostring(value) .. "): was not satisfied for: " .. name)
        return false
    end
end

---Generates the function to test the character for meeting the proficiency requirement specified.
---@param feat table The feat entry for the ability requirement
---@param proficiencyMatch table The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeProficiencyRequirement(feat, proficiencyMatch)
    _E6P(Ext.Json.Stringify(E6_ToJson(proficiencyMatch)))
    local proficiency = string.lower(proficiencyMatch[1])
    _E6P("Proficiency Constraint(" .. feat.ShortName .. ": " .. proficiency .. "): found!")
    return function(entity)
        local name = GetCharacterName(entity)
        _E6P("Proficiency Constraint(" .. feat.ShortName .. ": " .. proficiency .. "): was not satisfied for: " .. name)
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
    _E6P("Feat Requirements: " .. feat.ShortName .. ": " .. spec.Requirements .. " -> " .. Ext.Json.Stringify(requirements))
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

---Applies overrides to feats to allow or constrain feats further.
---@param feat table The feat entry to update
---@param spec table The specification table for the feat from Feats.lsx
local function E6_ApplyFeatOverrides(feat, spec)
    local featId = feat.ID
    if featOverrideAllowMultiple[featId] then
        feat.CanBeTakenMultipleTimes = true
    end
    E6_ApplyFeatRequirements(feat, spec)
    E6_ApplyRacialConstraints(feat)
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
            _E6P("Skipping unsupported feat " .. feat.Name .. ": " .. featRejectReason)
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

    for _, featInfo in pairs(featSet) do
        _E6P("Allowing feat: " .. featInfo.ShortName)
    end

    return featSet
end