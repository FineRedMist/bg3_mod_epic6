
---@class ApplyStatusStateType
---@field Icon string The icon of the status effect.
---@field Loca string The localization id of the status effect.
---@field Params string[] The parameters for the status effect.

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

---Parses a tag boost into the component tag, or returns nil if not a match.
---@param boost string The boost string from a passive or feat.
---@return string? The name of the tag being boosted if present, nil otherwise.
function ParseTagBoost(boost)
    local parts = GetFullMatch(boost, "%s*Tag%s*%(%s*([a-zA-Z0-9_]+)%s*%)%s*")
    if not parts then
        return nil
    end
    return parts[1]
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

---Parses the apply status and returns formatted data.
---@param statusApply string? The status to apply in text.
---@return ApplyStatusStateType? The status effect applied by the spell to show in the tooltip.
function ParseApplyStatus(statusApply)
    if not statusApply or string.len(statusApply) == 0 then
        return nil
    end

    ---@type string?
    local icon = nil
    ---@type number?
    local duration = nil

    local function GetDuration(inStatus, inAmount, inDuration)
        local status = Ext.Stats.Get(inStatus, -1, true, true)
        if not status then
            return ""
        end
        if not status.Icon then
            return ""
        end
        icon = status.Icon
        duration = tonumber(inDuration)
        return ""
    end

    string.gsub(statusApply, "%s*ApplyStatus%s*%(%s*([^, ]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+).*%)%s*", GetDuration)

    if icon == nil or duration == nil then
        return nil
    end
    if duration == -1 then
        return {Icon = icon, Loca = "h50ea69dagf61eg466fga47eg530c55933114", Params = {}} -- Until Long Rest
    end
    if duration > 0 then
        return {Icon = icon, Loca = "h6e1e86b5g98f8g42c8ga383gf770838ca349", Params = {tostring(duration)}} -- [1] turns
    end
    -- Zero duration, not interesting as far as I know.
    return nil
end
