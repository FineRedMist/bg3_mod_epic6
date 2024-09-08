
---Takes the AddSpells entry from a feat and generates the string for the boost to apply.
---@param addSpells table The entry from the gathering of feats.
---@return string The boost string.
function MakeBoost_AddSpells(addSpells)

    return "AddSpells(" .. JoinArgs({addSpells.SpellsId, addSpells.SelectorId, addSpells.Ability, addSpells.ActionResource, addSpells.PrepareType, addSpells.CooldownType}) .. ")"
end