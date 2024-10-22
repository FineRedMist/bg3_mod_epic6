
---Generates the boost line given the unlock obtions
---@param spellId string The id of the spell
---@param learningStrategy string? Singular|None|AddChildren|MostPowerful how the spell is learned 
---@param actionResourceUuid string? The uuid of the resource used, if any
---@param cooldownType string? OncePerTurn|OncePerCombat|UntilRest|OncePerTurnNoRealtime|UntilShortRest|UntilPerRestPerItem|OncePerShortRestPerItem cooldown type for the spell.
---@param ability string? Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma The ability to use the spell with.
local function MakeUnlockSpellBoost(spellId, learningStrategy, actionResourceUuid, cooldownType, ability)
    return "UnlockSpell(" .. JoinArgs({spellId, learningStrategy, actionResourceUuid, cooldownType, ability}) .. ")"
end


---Takes the AddSpells entry from a feat and generates the string for the boost to apply.
---@param spell SelectSpellInfoType The entry from the gathering of feats.
---@param makeMultiuseSpells boolean Whether the spell should be castable using spell slots
---@return string[] The boost string.
function MakeBoost_UnlockSpell(spell, makeMultiuseSpells)
    if spell.CooldownType == "Default" then
        spell.CooldownType = nil
    end
    local list = {}
    table.insert(list, MakeUnlockSpellBoost(spell.SpellId, nil, GuidZero, spell.CooldownType, spell.Ability))
    if makeMultiuseSpells then
        table.insert(list, "IF(HasActionResource('SpellSlot'," .. tostring(spell.Level) .. ",1,false,false,context.Source)):" .. MakeUnlockSpellBoost(spell.SpellId, "AddChildren", "d136c5d9-0ff0-43da-acce-a74a07f8d6bf", nil, spell.Ability))
        table.insert(list, "IF(HasActionResource('WarlockSpellSlot'," .. tostring(spell.Level) .. ",1,false,false,context.Source)):" .. MakeUnlockSpellBoost(spell.SpellId, "MostPowerful", "e9127b70-22b7-42a1-b172-d02f828f260a", nil, spell.Ability))
    end
    return list
end

---Generates the passive to add for a given ability.
---@param ability AbilityId The ability to boost
---@return string? The passive to add.
function GetAbilityBoostPassive(ability)
    if ~AbilitySkillMap[ability] then
        _E6Error("Invalid ability passed to GetAbilityBoostPassive: " .. ability)
        return nil
    end
    local upper = string.upper(ability)
    return "E6_FEAT_ABILITY_" .. upper
end

---Generates the passive to grant proficiency for a skill.
---@param skill SkillId The skill to grant proficiency
---@return string? The passive to add.
function GetProficiencyBoostPassive(skill)
    if ~SkillLoca[skill] then
        _E6Error("Invalid skill passed to GetProficiencyBoostPassive: " .. skill)
        return nil
    end
    local upper = string.upper(skill)
    return "E6_FEAT_SKILL_PROFICIENCY_" .. upper
end

---Generates the passive to grant expertise for a skill.
---@param skill SkillId The skill to grant expertise
---@return string? The passive to add.
function GetExpertiseBoostPassive(skill)
    if ~SkillLoca[skill] then
        _E6Error("Invalid skill passed to GetExpertiseBoostPassive: " .. skill)
        return nil
    end
    local upper = string.upper(skill)
    return "E6_FEAT_SKILL_EXPERTISE_" .. upper
end

