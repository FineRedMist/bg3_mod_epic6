
---Generates the boost line given the unlock obtions
---@param spellId string The id of the spell
---@param learningStrategy string? Singular|None|AddChildren|MostPowerful how the spell is learned 
---@param actionResourceUuid string? The uuid of the resource used, if any
---@param cooldownType string? OncePerTurn|OncePerCombat|UntilRest|OncePerTurnNoRealtime|UntilShortRest|UntilPerRestPerItem|OncePerShortRestPerItem cooldown type for the spell.
---@param ability string? Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma The ability to use the spell with.
local function MakeUnlockSpellBoost(spellId, learningStrategy, actionResourceUuid, cooldownType, ability)
    return "UnlockSpell(" .. JoinArgs({spellId, learningStrategy, actionResourceUuid, cooldownType, ability}) .. ")"
end

---Creates the condition for adding a spell that is slot dependent to the character.
---@param spellSlotName string The name of the spell slot.
---@param spellLevel integer The level of the spell slot.
---@return string The condition to use.
local function MakeCondition(spellSlotName, spellLevel)
    return "IF(HasActionResource('" .. spellSlotName .. "'," ..tostring(spellLevel) .. ",1,false,false,context.Source)):"
end

---Creates a conditioned spell unlock based on the spell slots used.
---@param spellSlotName string The name of the spell slot.
---@param spellLevel integer The level of the spell slot.
---@param spellId string The id of the spell
---@param learningStrategy string? Singular|None|AddChildren|MostPowerful how the spell is learned 
---@param actionResourceUuid string? The uuid of the resource used, if any
---@param cooldownType string? OncePerTurn|OncePerCombat|UntilRest|OncePerTurnNoRealtime|UntilShortRest|UntilPerRestPerItem|OncePerShortRestPerItem cooldown type for the spell.
---@param ability string? Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma The ability to use the spell with.
---@return string The conditional boost to apply for the spell.
local function MakeConditionalUnlockSpellBoost(spellSlotName, spellLevel, spellId, learningStrategy, actionResourceUuid, cooldownType, ability, condition)
    return MakeCondition(spellSlotName, spellLevel) .. MakeUnlockSpellBoost(spellId, learningStrategy, actionResourceUuid, cooldownType, ability)
end

---Takes the AddSpells entry from a feat and generates the string for the boost to apply.
---@param spell SelectSpellInfoType The entry from the gathering of feats.
---@param makeMultiUseSpells boolean Whether to make the spells multi-use.
---@return string[] The boost string.
function MakeBoost_UnlockSpell(spell, makeMultiUseSpells)
    if spell.CooldownType == "Default" then
        spell.CooldownType = nil
    end
    local list = {}
    table.insert(list, MakeUnlockSpellBoost(spell.SpellId, nil, GuidZero, spell.CooldownType, spell.Ability))
    if makeMultiUseSpells and spell.Level > 0 then
        table.insert(list, MakeConditionalUnlockSpellBoost("SpellSlot", spell.Level, spell.SpellId, "AddChildren", "d136c5d9-0ff0-43da-acce-a74a07f8d6bf", nil, spell.Ability))
        table.insert(list, MakeConditionalUnlockSpellBoost("WarlockSpellSlot", spell.Level, spell.SpellId, "MostPowerful", "e9127b70-22b7-42a1-b172-d02f828f260a", nil, spell.Ability))
    end
    return list
end

---comment
---@param spellsId string The id of the spell list
---@param spellGroupDetails SpellGrantInformationType The spell group details to apply
---@param spellIDs string[] The spell IDs to gather
local function GatherSpellBoostsForSet(spellsId, spellGroupDetails, spellIDs, makeMultiUseSpells)
    if not spellIDs then
        _E6Error("No spell ids provided for gathing spell boosts for spell group: " .. spellsId)
        return {}
    end

    local list = {}

    for _,spellId in pairs(spellIDs) do -- not ipairs intentionally, it doesn't handle Array_FixedString for some reason.
        ---@type SpellData The spell data.
        local spellStat = Ext.Stats.Get(spellId, -1, true, true)
        if spellStat then
            ---@type SelectSpellInfoType
            local spellToGrant = {
                SpellsId = spellsId,
                SpellId = spellId,
                Level = spellStat.Level,
                Ability = spellGroupDetails.AbilityId,
                CooldownType = spellGroupDetails.CooldownType,
                PrepareType = spellGroupDetails.PrepareType,
                ActionResource = spellGroupDetails.ResourceId,
            }

            for _,boost in ipairs(MakeBoost_UnlockSpell(spellToGrant, makeMultiUseSpells)) do
                table.insert(list, boost)
            end
        else
            _E6Warn("Could not find the spell data for: " .. spellId)
        end
    end
    return list
end

---Generates the unlock spell boosts for the feat.
---@param feat SelectedFeatType The feat selected.
---@return string[] The collection of boosts to apply for the feat.
function GatherSpellBoostsForFeat(feat)
    local list = {}
    -- Gather the spells to add
    if feat.AddedSpells then
        for spellGroupId, spellGroupDetailsSet in pairs(feat.AddedSpells) do
            for _,spellGroupDetails in ipairs(spellGroupDetailsSet) do
                ---@type ResourceSpellList
                local spells = Ext.StaticData.Get(spellGroupId, Ext.Enums.ExtResourceManagerType.SpellList)
                for _, boost in ipairs(GatherSpellBoostsForSet(spellGroupId, spellGroupDetails, spells.Spells, false)) do
                    table.insert(list, boost)
                end
            end
        end
    end
    -- Gather the selected spells
    if feat.SelectedSpells then
        for spellGroupId, selectedSpellsSet in pairs(feat.SelectedSpells) do
            for spellId, spellGroupDetails in pairs(selectedSpellsSet) do
                for _, boost in ipairs(GatherSpellBoostsForSet(spellGroupId, spellGroupDetails, {spellId}, true)) do
                    table.insert(list, boost)
                end
            end
        end
    end
    return list
end

---Generates the passive to add for a given ability.
---@param ability AbilityId The ability to boost
---@return string? The passive to add.
function GetAbilityBoostPassive(ability, count)
    if not AbilitySkillMap[ability] then
        _E6Error("Invalid ability passed to GetAbilityBoostPassive: " .. ability)
        return nil
    end
    return "Ability(" .. ability .. "," .. tostring(count) .. ")"
end

---Generates the passive to grant proficiency for a skill.
---@param skill SkillId The skill to grant proficiency
---@return string? The passive to add.
function GetProficiencyBoostPassive(skill)
    if not SkillLoca[skill] then
        _E6Error("Invalid skill passed to GetProficiencyBoostPassive: " .. skill)
        return nil
    end
    return "ProficiencyBonus(Skill," .. skill .. ")"
end

---Generates the passive to grant expertise for a skill.
---@param skill SkillId The skill to grant expertise
---@return string? The passive to add.
function GetExpertiseBoostPassive(skill)
    if not SkillLoca[skill] then
        _E6Error("Invalid skill passed to GetExpertiseBoostPassive: " .. skill)
        return nil
    end
    local upper = string.upper(skill)
    return "ExpertiseBonus(" .. skill .. ")"
end

