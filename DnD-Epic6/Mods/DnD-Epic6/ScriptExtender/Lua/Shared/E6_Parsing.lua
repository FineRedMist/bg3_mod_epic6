---Parses an ability boost into its component ability and amount.
---@param boost string The boost string from a passive or feat.
---@return string? The name of the ability being boosted if present, nil otherwise.
---@return AbilityScoreType? The ability score information for the boost.
function ParseAbilityBoost(boost)
    local parts = GetFullMatch(boost, "%s*Ability%s*%(%s*(%a+)%s*,%s*(%d+),?%s*(%d*)%s*%)%s*")
    if not parts then
        return nil
    end
    local capIncrease = nil
    if parts[3] and string.len(parts[3]) > 0 then
        capIncrease = tonumber(parts[3])
    end
    return parts[1], { Current = tonumber(parts[2]), Maximum = capIncrease }
end

---Parses a proficieny bonus boost into its kind (Skill or SavingThrow) and the skill/ability.
---@param boost string The boost string from a passive or feat.
---@return string? Whether the proficiency is for a Skill or SavingThrow, or nil if not a match.
---@return string? The proficiency the bonus is applied to, for Skill, the skill name, for SavingThrow, the ability.
function ParseProficiencyBonusBoost(boost)
    local parts = GetFullMatch(boost, "%s*ProficiencyBonus%s*%(%s*(%a+)%s*,%s*(%a+)%s*%)%s*")
    if not parts then
        return nil
    end
    return parts[1], parts[2]
end

---Parses a proficiency (such as weapon or musical instrument).
---@param boost string The boost string from a passive or feat.
---@return string? Whether the proficiency if parsed, or nil otherwise.
function ParseProficiencyBoost(boost)
    local parts = GetFullMatch(boost, "%s*Proficiency%s*%(%s*(%a+)%s*%)%s*")
    if not parts then
        return nil
    end
    return parts[1]
end

