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

---@param message string The error message about the failure
---@param args any[]? Additional arguments to pass to the error message.
---@return FeatMessageType The message to display to the player about why the requirement failed.
function ToMessageLoca(message, args)
    return { MessageLoca = message, Args = args }
end

local RequirementsMet = ToMessageLoca("h35115c97g6f5bg4ba5gad35gfdba5e7e1d51") -- Requirements met

---Returns the loca for a missing ability.
---@param abilityName string The name of the ability that was missing.
---@return FeatMessageType The message to display to the player about why the requirement failed.
local function MissingAbilityLoca(abilityName)
    local isAbility = AbilityPassives[abilityName] ~= nil
    local param = abilityName
    if isAbility then
        param = AbilityPassives[abilityName].DisplayName
    end
    return ToMessageLoca("hbc4fc044gb46fg47f2g9ff9g00af57de9fae", {param}) -- The ability [1] could not be found on the character
end

---Indicates a match failure
---@param feat table The feat entry for the ability requirement
---@param errorMessage string The error message about the failure
---@param args any[] Additional arguments to pass to the error message.
---@return function That always returns false for match failures against the requirements of the feat.
local function E6_MatchFailure(feat, errorMessage, args)
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Always false
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        return false, { MessageLoca = errorMessage, Args = args }
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
            E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h33fcc5c5g2d0dg45a4ga313gc12dbfbb9ac7", ability.SourceId})) -- Feat misconfiguration: [1], The ability list [2] wasn't found.
            return
        end
        ---@type string[] The list of abilities in the ability list.
        local abilityNames = {}
        for _,abilityName in ipairs(abilityList.Abilities) do
            table.insert(abilityNames, abilityName.Label)
        end
        ---@param entity EntityHandle The entity to test the requirement against.
        ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
        ---@return boolean Whether the player meets the ability score requirement.
        ---@return FeatMessageType The message to display to the player about why the requirement failed.
        local abilityRequirement = function(entity, playerInfo)
            local abilityScores = playerInfo.Abilities
            -- Determine the total number of assignable points across the listed abilities. If the count is less than granted, return false.
            local availablePointRoom = 0
            for _,abilityName in ipairs(abilityNames) do
                local abilityScore = abilityScores[abilityName]
                if not abilityScore then
                    return false, MissingAbilityLoca(abilityName)
                end
                availablePointRoom = availablePointRoom + abilityScore.Maximum - abilityScore.Current
            end
            if availablePointRoom < ability.Count then
                return false, ToMessageLoca("h2e9bd450g5df3g4075ga81eg29eef9f9f4a4") -- The feat grants more points than can be applied to abilities.
            end
            return true, RequirementsMet
        end
        E6_AddFeatRequirement(feat, abilityRequirement)
    end
end

---Generates the function to filter the feat if the character already has all the selectable passives.
---@param feat FeatType The feat entry for the ability requirement
local function E6_ApplySelectPassiveRequirement(feat)
    if #feat.SelectPassives == 0 then
        return
    end
    for _, passive in ipairs(feat.SelectPassives) do
        ---@type ResourcePassiveList
        local passiveList = Ext.StaticData.Get(passive.SourceId, Ext.Enums.ExtResourceManagerType.PassiveList)
        if not passiveList then
            E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h31df0045ge2e3g453bga538ga0a618a38844", passive.SourceId})) -- Feat misconfiguration: [1], The passive list [2] wasn't found.
            return
        end
        ---@type string[] The list of passives in the passive list.
        local passiveNames = {}
        for _,passiveName in ipairs(passiveList.Passives) do
            table.insert(passiveNames, passiveName)
        end

        -- Number of passives to choose.
        local passiveCount = passive.Count

        ---@param entity EntityHandle The entity to test the requirement against.
        ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
        ---@return boolean Whether the feat has enough passives remaining to select.
        ---@return FeatMessageType The message to display to the player about why the requirement failed.
        local passiveRequirement = function(entity, playerInfo)
            local playerPassives = playerInfo.PlayerPassives
            local missingPassives = 0
            for _,passiveName in ipairs(passiveNames) do
                if not playerPassives[passiveName] then
                    missingPassives = missingPassives + 1
                end
                if missingPassives >= passiveCount then
                    return true, RequirementsMet
                end
            end
            return false, ToMessageLoca("h8b51336eg9283g49acgb856g30ab5c92524c") -- There aren't enough unselected passives to choose from.
        end
        E6_AddFeatRequirement(feat, passiveRequirement)
    end
end

---Generates the function to test the character for meeting the ability requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param abilityMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeAbilityRequirement(feat, abilityMatch)
    local ability = abilityMatch[1]
    local value = tonumber(abilityMatch[2])
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player meets the ability score requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        local abilityScores = playerInfo.Abilities
        if not abilityScores then
            return false, ToMessageLoca("h3ee30c4bg920fg46fdga857g21d9a21b5bb5") -- An error occurred getting the player's ability scores.
        end
        local abilityScore = abilityScores[ability]
        if not abilityScore then
            return false, MissingAbilityLoca(ability)
        end
        if abilityScore.Current >= value then
            return true, RequirementsMet
        end
        return false, ToMessageLoca("h69b3c062g4965g4fbeg9446g901d37a06d72", {AbilityPassives[ability].DisplayName, value, abilityScore.Current}) -- [1] is less than [2]. It is currently [3].
    end
end

---Generates the function to test the character for meeting the proficiency requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeProficiencyRequirement(feat, proficiencyMatch)
    local proficiency = proficiencyMatch[1]
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player meets the ability score requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        if not ProficiencyLoca[proficiency] then
            return false, ToMessageLoca("h1c81aad6g23b0g4068ga108g3b4b0957050b", {proficiency}) -- Unknown proficiency: [1]
        end
        local proficiencyComp = entity.Proficiency
        if not proficiencyComp then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        local proficiencyFlags = proficiencyComp.Flags
        if proficiencyFlags == nil then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        for _,proficiencyFlag in ipairs(proficiencyFlags) do
            if proficiencyFlag == proficiency then
                return true, RequirementsMet
            end
        end
        return false, ToMessageLoca("h0772c666g159dg47eag857eg2c8bb25bc440", {ProficiencyLoca[proficiency]}) -- Missing proficiency: [1]
    end
end

---Generates the function to test the character for meeting the non-proficiency requirement specified.
---@param feat FeatType The feat entry for the non-proficiency requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the non-proficiency requirement, false otherwise.
local function E6_MakeNonProficiencyRequirement(feat, proficiencyMatch)
    local proficiency = proficiencyMatch[1]
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player has the proficiency requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        if not ProficiencyLoca[proficiency] then
            return false, ToMessageLoca("h1c81aad6g23b0g4068ga108g3b4b0957050b", {proficiency}) -- Unknown proficiency: [1]
        end
        local proficiencyComp = entity.Proficiency
        if not proficiencyComp then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        local proficiencyFlags = proficiencyComp.Flags
        if proficiencyFlags == nil then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        for _,proficiencyFlag in ipairs(proficiencyFlags) do
            if proficiencyFlag == proficiency then
                return false, ToMessageLoca("h1d87338fgc5ddg4386gaf1eg83c82d9ca1a3", {ProficiencyLoca[proficiency]}) -- Already has proficiency: [1]
            end
        end
        return true, RequirementsMet
    end
end

---Generates the function to test the character for meeting the proficiency requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeCharacterLevelRequirement(feat, proficiencyMatch)
    local levelRequirement = tonumber(proficiencyMatch[1])
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the character level is strictly greater than the requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        if entity.EocLevel.Level > levelRequirement then
            return true, RequirementsMet
        else
            return false, ToMessageLoca("h04fab965g7b1bg47fegad9bg69ae676c8cdf", {levelRequirement}) -- Character level must be greater than: [1]
        end
    end
end


---Generates the function to test the character for meeting the passive requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakePassiveRequirement(feat, proficiencyMatch)
    local passiveName = proficiencyMatch[1]
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player has the passive.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        ---@type PassiveData Data for the passive
        local passiveStat = Ext.Stats.Get(passiveName,  -1, true, true)
        if not passiveStat then
            return false, ToMessageLoca("h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h9d531312g1e6ag4dd9ga25ag405948ce70af", passiveName}) -- Feat misconfiguration: [1], The passive [2] wasn't found.
        end
        if playerInfo.PlayerPassives[passiveName] ~= nil then
            return true, RequirementsMet
        else
            return false, ToMessageLoca("hd7005e0bgad9bg43afgabb9gd831f1708f49", {passiveStat.DisplayName}) -- Missing ability: [1]
        end
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
        Regex = "FeatRequirementNonProficiency%('(%w+)'%)",
        Func = E6_MakeNonProficiencyRequirement
    },
    {
        Regex = "CharacterLevelGreaterThan%((%d+)%)",
        Func = E6_MakeCharacterLevelRequirement
    },
    {
        Regex = "HasPassive%('(.+)'%)",
        Func = E6_MakePassiveRequirement
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
                E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "hf5f71dc3g2cd6g40ddga2aeg167bdfe6d71e", {req})) -- Unknown requirement (please report a bug on NexusMods for DnD-Epic6 to have it added): [1]
            end
        end
    end
end

---Gathers any ability modifiers from the passive ability boosts.
---Note: This will be used for both feats and for passives listed in the passive list for selection. 
---@param passiveName string Name of the passive to gather the ability modifiers from. 
---@param feat FeatType The feat to test against
---@return table<string,AbilityScoreType> A mapping of ability name to delta value.
local function GatherPassiveAbilityModifiers(feat, passiveName)
    local result = {}
    ---@type PassiveData Data for the passive
    local passive = Ext.Stats.Get(passiveName, -1, true, true)
    --There is a passive in the list we can't get data for. We don't want to block the feat, but we want to report it.
    if not passive then
        _E6Warn("The feat '" .. feat.ShortName .. "' has a passive '" .. passiveName .. "' that doesn't exist.")
        return result
    end
    if passive and passive.Boosts then
        local boosts = SplitString(passive.Boosts, ";")
        for _,boost in ipairs(boosts) do
            local ability, score = ParseAbilityBoost(boost)
            if ability and score then
                result[ability] = MergeAbilityBoost(result[ability], score)
            end
        end
    end
    return result
end

---Determines if the new ability score modifier can be applied to the current one for the player.
---Unfortunately, the game's passives can't be used to incrase the ability score beyond the maximum
---they specify in their boosts. So this function helps find and filter them so you don't waste a
---selection.
---@param player AbilityScoreType The current ability score
---@param delta AbilityScoreType The new ability score modifier to apply
---@return boolean Whether the new abiity score modifier can be applied.
function CanApplyAbilityBoost(player, delta)
    -- if the new maximum is nil, use the player maximum
    local limit = player.Maximum
    -- if the new maximum is not nil, use it instead.
    if delta.Maximum then
        limit = delta.Maximum
    end
    return player.Current + delta.Current <= limit
end

---Merges the ability boosts from the passive into the general ability boost table.
---@param abilityBoosts table<string,AbilityScoreType> Target to merge into
---@param passiveBoosts table<string,AbilityScoreType> Ability boosts to merge in
local function MergeAbilityBoosts(abilityBoosts, passiveBoosts)
    for ability,delta in pairs(passiveBoosts) do
        abilityBoosts[ability] = MergeAbilityBoost(abilityBoosts[ability], delta)
    end
end

---Determines whether taking the feat will raise the player's abilities above the maximum
---@param feat FeatType The feat to test against
local function E6_ApplyFeatAbilityConstraints(feat)
    ---@type table<string,AbilityScoreType>
    local abilityBoosts = {}
    local isValid = true
    local failedPassiveName = nil
    for _,passiveName in ipairs(feat.PassivesAdded) do
        ---@type table<string,AbilityScoreType>
        local passiveBoosts = GatherPassiveAbilityModifiers(feat, passiveName)
        if passiveBoosts then
            MergeAbilityBoosts(abilityBoosts, passiveBoosts)
        else
            failedPassiveName = passiveName
            isValid = false
        end
    end
    if not isValid then
        E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h9d531312g1e6ag4dd9ga25ag405948ce70af", failedPassiveName})) -- Feat misconfiguration: [1], The passive [2] wasn't found.
        return
    end
    if next(abilityBoosts) ~= nil then
        ---@param entity EntityHandle The entity to test the requirement against.
        ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
        ---@return boolean Whether the ability boosts of the feat are not going to exceed limits.
        ---@return FeatMessageType The message to display to the player about why the requirement failed.
        local function validateAbilityBoosts(entity, playerInfo)
            local abilityScores = playerInfo.Abilities
            local totalBoosts = 0
            for ability,delta in pairs(abilityBoosts) do
                if not abilityScores then
                    return false, ToMessageLoca("h3ee30c4bg920fg46fdga857g21d9a21b5bb5") -- An error occurred getting the player's ability scores.
                end
                local abilityScore = abilityScores[ability]
                if not abilityScore then
                    return false, MissingAbilityLoca(ability)
                end
                if not CanApplyAbilityBoost(abilityScore, delta) then
                    return false, ToMessageLoca("h941fb918g8e78g4c41ga66fg1d14cd0f77cf") -- This feature boosts an ability that is already at 20 (Legendary doesn't work for feature).
                end
                totalBoosts = totalBoosts + delta.Current
            end
            local successMessage = ToMessageLoca("h45303d74g2579g454ag9662g31dcf74794d7") -- This feature boosts an ability that is limited to 20 (Legendary doesn't work for feature).
            if totalBoosts == 0 then
                successMessage = RequirementsMet
            end
            return true, successMessage
        end

        E6_AddFeatRequirement(feat, validateAbilityBoosts)
    end
end

---Applies overrides to feats to allow or constrain feats further.
---@param feat FeatType The feat entry to update
---@param spec ResourceFeat The specification table for the feat from Feats.lsx
function E6_ApplyFeatFiltering(feat, spec)
    E6_ApplyFeatAbilityConstraints(feat)
    E6_ApplySelectAbilityRequirement(feat)
    E6_ApplySelectPassiveRequirement(feat)
    E6_ApplyFeatRequirements(feat, spec)
end