
---Generates the boost line given the unlock obtions
---@param spellId string The id of the spell
---@param learningStrategy string? Singular|None|AddChildren|MostPowerful how the spell is learned 
---@param actionResourceUuid string? The uuid of the resource used, if any
---@param cooldownType string? OncePerTurn|OncePerCombat|UntilRest|OncePerTurnNoRealtime|UntilShortRest|UntilPerRestPerItem|OncePerShortRestPerItem cooldown type for the spell.
---@param ability string? Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma The ability to use the spell with.
function MakeUnlockSpellBoost(spellId, learningStrategy, actionResourceUuid, cooldownType, ability)
    return "UnlockSpell(" .. JoinArgs({spellId, learningStrategy, actionResourceUuid, cooldownType, ability}) .. ")"
end


---Takes the AddSpells entry from a feat and generates the string for the boost to apply.
---@param spell table The entry from the gathering of feats.
---@param makeMultiuseSpells boolean Whether the spell should be castable using spell slots
---@return string The boost string.
function MakeBoost_UnlockSpell(spell, makeMultiuseSpells)
    local base = MakeUnlockSpellBoost(spell.SpellId, nil, nil, spell.CooldownType, spell.Ability)
    if makeMultiuseSpells then
        base = base .. ";IF(HasActionResource('SpellSlot')):" .. MakeUnlockSpellBoost(spell.SpellId, "AddChildren", "d136c5d9-0ff0-43da-acce-a74a07f8d6bf", nil, spell.Ability)
        base = base .. ";IF(HasActionResource('WarlockSpellSlot')):" .. MakeUnlockSpellBoost(spell.SpellId, "MostPowerful", "e9127b70-22b7-42a1-b172-d02f828f260a", nil, spell.Ability)
    end
    return base
end

