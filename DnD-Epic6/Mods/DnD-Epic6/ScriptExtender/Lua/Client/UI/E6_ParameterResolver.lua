--- @class ParameterResolver Uses the player information and corresponding spell or passive to resolve parameters into meaningful text.
--- @field playerInfo PlayerInformationType The player information to resolve parameters for.
--- @field replacementMap table<string, string> The map of replacements to use.
--- Handles the creation of text elements in the UI to support wrapping, inline images, etc.
ParameterResolver = {}
ParameterResolver.__index = ParameterResolver

---Creates a new instance of the parameter resolver
---@param playerInfo PlayerInformationType The player information to resolve parameters for.
---@param replacementMap table<string, string>? The map of replacements to use.
---@return ParameterResolver The new instance of the parameter resolver.
function ParameterResolver:new(playerInfo, replacementMap)
    local res = setmetatable({}, self)
    res.playerInfo = playerInfo
    if not replacementMap then
        res.replacementMap = {}
    else
        res.replacementMap = replacementMap
    end
    return res
end

---Creates an updated instance of the parameter resolver with additional replacment map settings
---@param prevResolver ParameterResolver The player information to resolve parameters for.
---@param replacementMap table<string, string>? The map of replacements to use.
---@return ParameterResolver The new instance of the parameter resolver.
function ParameterResolver:update(prevResolver, replacementMap)
    local res = setmetatable({}, self)
    res.playerInfo = prevResolver.playerInfo
    res.replacementMap = DeepCopy(prevResolver.replacementMap)
    if replacementMap then
        for key,value in pairs(replacementMap) do
            res.replacementMap[key] = value
        end
    end
    return res
end

---Performs a triple check to replace the text with the given search and replace values.
---@param text string The text to search and replace.
---@param search string The text to search for.
---@param replace string|function The text or function to replace with.
---@param includeBase boolean? Whether to include the base search or not.
---@return string The text with the replacements.
local function TripleCheck(text, search, replace, includeBase)
    if includeBase == nil then
        includeBase = true
    end
    for _,prefix in ipairs({"Owner%.", "Cause%.", ""}) do
        if includeBase or string.len(prefix) ~= 0 then
            text = string.gsub(text, prefix .. search, replace)
        end
    end
    return text
end

---@type table<string,string> Cache of the level map values.
local levelMapValueCache = {}

---Initializes the level map value cache.
local function InitLevelMapValue()
    local ids = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.LevelMap)
    for _,id in ipairs(ids) do
        ---@type ResourceLevelMap
        local resource = Ext.StaticData.Get(id, Ext.Enums.ExtResourceManagerType.LevelMap)
        if resource then
            local value = nil
            if resource.LevelMaps and #resource.LevelMaps >= 6 then
                value = resource.LevelMaps[6]
            end
            if not value then
                value = resource.FallbackValue
            end
            if type(value) ~= "number" and type(value) ~= "integer" then
                value = tostring(value.AmountOfDices) .. value.DiceValue.Label
            end
            levelMapValueCache[resource.Name] = value
        else
            _E6Warn("LevelMap resource not found: " .. id)
        end
    end
end

---Retrieves the level map value for the given key. Note: We are always level 6 for this lookup.
---@param key string The key to retrieve the value for.
---@return string The value for the key.
local function GetLevelMapValue(key)
    if #levelMapValueCache == 0 then
        InitLevelMapValue()
    end
    local value = levelMapValueCache[key]
    if value then
        return value
    end
    _E6Error("GetLevelMapValue: " .. key .. " not found!")
    return key
end

---@param playerInfo PlayerInformationType
---@param key string The key to retrieve the value for.
local function GetTagged(playerInfo, key)
    local passiveName = "E6_Tag_" .. NormalizePascalCase(key) .. "_Passive"
    if playerInfo.PlayerPassives[passiveName] then
        return "true"
    end
    return "false"
end

---@param playerInfo PlayerInformationType
---@param className string The class name to retrieve the level for.
local function GetClassLevel(playerInfo, className)
    local level = playerInfo.PlayerLevels[className]
    if level then
        return level
    end
    return 0
end

---Gets the lowest value on the given count of dice with the given sides.
---@param count string Number of dice
---@param sides string Number of sides on the dice
---@return number Lowest value the dice can have.
local function GetDiceLowest(count, sides)
    return tonumber(count)
end

---Gets the highest value on the given count of dice with the given sides.
---@param count string Number of dice
---@param sides string Number of sides on the dice
---@return number Highest value the dice can have.
local function GetDiceHighest(count, sides)
    return tonumber(count) * tonumber(sides)
end

local function CleanSigns(formula)
    formula = string.gsub(formula, "%+%s*%-", "-") -- replace + - with just -
    formula = string.gsub(formula, "%+%s*%+", "+") -- replace + + with just +
    formula = string.gsub(formula, "%-%s*%+", "-") -- replace - + with just -
    formula = string.gsub(formula, "^%s*%+", "") -- Resolve leading +

    formula = Trim(formula)

    return formula
end

---Resolves stages in the computation to collapse logic.
---@param formula string The formula to process
---@param search string The search parameters to use replacement on 
---@param replFunc function The function to do the computation
---@param collapse function? Post cleanup function
---@return string The reduced formula
local function ResolveStep(formula, search, replFunc, collapse)
    local last = formula
    repeat
        last = formula
        formula = CleanSigns(formula)
        formula = string.gsub(formula, search, replFunc)
        formula = Trim(formula)
    until formula == last
    return formula
end

---Computes the given formula. Note: 'load' isn't an options, so we have to do it manually.
---@param originalFormula string The formula to compute.
---@return number? The computed value or nil if it couldn't be computed.
local function GetValue(originalFormula)

    local formula = originalFormula

    ---Wraps the computation with the boilerplate validation. Then computes.
    ---@param aText string
    ---@param bText string
    ---@param compute function
    ---@return string
    local function ComputeWrapper(aText, bText, compute)
        local a = GetValue(aText)
        local b = GetValue(bText)
        if a == nil or b == nil then
            return "nil"
        end
        return tostring(compute(a, b))
    end

    -- Resolve max first
    formula = ResolveStep(formula, "max%s*%(%s*([%d%+%-%*/%. ]+)%s*,%s*([%d%+%-%*/%. ]+)%s*%)", function(aText, bText)
            return ComputeWrapper(aText, bText, math.max)
        end)

    -- Resolve * next
    formula = ResolveStep(formula, "([%d%.]+)%s*%*%s*([%d%.]+)", function(aText, bText)
        return ComputeWrapper(aText, bText, function(a, b) return a * b end)
    end)

    -- Resolve / next
    formula = ResolveStep(formula, "([%d%.])+%s*/%s*([%d%.]+)", function(aText, bText)
        return ComputeWrapper(aText, bText, function(a, b) if b == 0 then return a end return a / b end)
    end)

    -- Resolve + next
    formula = ResolveStep(formula, "(-?[%d%.]+)%s*%+%s*([%d%.]+)", function(aText, bText)
        return "+" .. ComputeWrapper(aText, bText, function(a, b) return a + b end)
    end)
    
    -- Resolve - next
    formula = ResolveStep(formula, "(-?[%d%.]+)%s*%-%s*([%d%.]+)", function(aText, bText)
        return "+" .. ComputeWrapper(aText, bText, function(a, b) return a - b end)
    end)

    formula = CleanSigns(formula)
    if string.find(formula, "[^%-%d%.]") then
        return nil
    end
    return tonumber(formula)
end

---Computes the formula range based on the dice and modifiers.
---@param formula string The formula to compute the range for.
---@return string The low range of the formula
---@return string? The high range of the formula, or nil if it couldn't be computed.
local function GetFormulaRange(formula)
    local lowText = string.gsub(formula, "(%d+)[Dd](%d+)", GetDiceLowest)
    local highText = string.gsub(formula, "(%d+)[Dd](%d+)", GetDiceHighest)

    local low = GetValue(lowText)
    local high = GetValue(highText)

    -- Couldn't figure it out, return the string
    if low == nil or high == nil then
        return formula, nil
    end

    if low == high then
        return tostring(low), nil
    end

    return tostring(low), tostring(high)
end

---@class RollTermType
---@field IsPositive boolean Whether the term is positive or negative.
---@field DiceCount number The number of dice in the term.
---@field DiceSides number The number of sides on the dice (zero for constant terms).

---Merges and collects like terms in the formula based on dice and constants.
---@param formula string The formula to collect terms for.
---@return string The result with consolidated terms.
local function ConsolidateTerms(formula)
    -- split the formula at + and - signs, then identify dice and constants, then merge terms.
    local terms = SplitString(formula, "+-", true)

    -- Collect the terms by dice side count.
    local isPositive = true
    local collector = {}
    for i,v in ipairs(terms) do
        local term = Trim(v)
        if term == "+" then
            isPositive = true
        elseif term == "-" then
            isPositive = false
        else
            local diceCount, diceSides = string.match(term, "(%d+)[Dd](%d+)")
            ---@type RollTermType?
            local roll = nil
            if diceCount and diceSides then
                roll = {IsPositive = isPositive, DiceCount = tonumber(diceCount), DiceSides = tonumber(diceSides)}
            else
                roll = {IsPositive = isPositive, DiceCount = tonumber(term), DiceSides = 0}
            end
            diceSides = roll.DiceSides
            local collection = collector[diceSides]
            if not collection then
                collection = {}
                collector[diceSides] = collection
            end
            table.insert(collection, roll)
        end
    end

    -- Gather the dice sides, and process them from highest to lowest.
    local diceSides = {}
    for k,v in pairs(collector) do
        table.insert(diceSides, k)
    end

    table.sort(diceSides, function(a, b) return a > b end)

    -- Generate the result string
    local result = ""
    for _,sides in ipairs(diceSides) do
        local collection = collector[sides]
        local diceCount = 0
        for _,roll in ipairs(collection) do
            if roll.IsPositive then
                diceCount = diceCount + roll.DiceCount
            else
                diceCount = diceCount - roll.DiceCount
            end
        end
        if diceCount > 0 then
            if #result > 0 then
                result = result .. "+" .. tostring(diceCount)
            else
                result = tostring(diceCount)
            end
        elseif diceCount < 0 then
            result = result .. "-" .. tostring(-diceCount)
        end
        if diceCount ~= 0 and sides > 0 then
            result = result .. "d" .. tostring(sides)
        end
    end
    return result
end

---Computes the dice range based on the formula.
---@param formula string The string representation of the formula to perform substitutions with.
---@param keep boolean? Whether to keep the base formula in terms of dice values and consolidate terms, or just the damage range.
---@return string The computed formula for human readability.
local function ComputeFormula(formula, keep)
    formula = TripleCheck(formula, "Level", "6")

    local low, high = GetFormulaRange(formula)
    if not high or not keep then
        return low
    elseif not keep then
        return low .. "~" .. high
    end

    return ConsolidateTerms(formula) .. " (" .. low .. "~" .. high .. ")"
    
end

local function GetDistance(distance)
   return GetParameterizedLoca("h3798d21bgceccg4e7cg8044g29b0cf015717", {distance})
end

local function GetTemporaryHitPoints(formula)
    local formula = ComputeFormula(formula, true)
    return GetParameterizedLoca("hdabb2235ge870g409bg8e02g1ebc41f8f81d", {formula})
end

local function RegainHitPoints(formula)
    local formula = ComputeFormula(formula, true)
    return GetParameterizedLoca("he982505bgbb90g46e6g999fg82d159022d1b", {formula})
end

local damageTypeLoca = {
    Acid = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_4",
    Bludgeoning = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_3",
    Cold = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_9",
    Fire = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_7",
    Force = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_13",
    Healing = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_16",
    Lightning = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_8",
    Necrotic = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_6",
    Piercing = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_2",
    Poison = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_11",
    Psychic = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_10",
    Radiant = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_12",
    Slashing = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_1",
    Spell = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_15",
    Thunder = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_5",
    Weapon = "hc3cd9b4eg4ea4g4438gbfbbg493c0abb6dd7_14"
}

---Computes the deal damage scenario
---@param formula string The formula to compute
---@param damageType string The type of the damage applied
---@return string The replacement string for the matched text
local function DealDamage(formula, damageType)
    local formula = ComputeFormula(formula, true)
    if damageTypeLoca[damageType] then
        damageType = damageTypeLoca[damageType]
    end
    return GetParameterizedLoca("ha7eeaa4ag452bg469dg9127gaa4afb1e3abc", {formula, damageType})
end

---Performs replacements against the text to resolve the parameters.
---@param playerInfo PlayerInformationType
---@param text string
---@return string
function ParameterResolver:RunReplacements(playerInfo, text)
    local orig = text
    text = TripleCheck(text, "ProficiencyBonus", tostring(playerInfo.ProficiencyBonus))
    for name,ability in pairs(playerInfo.Abilities) do
        text = TripleCheck(text, name .. "Modifier", tostring(GetAbilityModifier(ability.Current)))
    end
    text = TripleCheck(text, "LevelMapValue%s*%(%s*([%w_]+)%s*%)", GetLevelMapValue)
    text = TripleCheck(text, "[Tt][Aa][Gg][Gg][Ee][Dd]%s*%(%s*'([%w_]+)'%s*%)", function(key)
        return GetTagged(playerInfo, key)
    end)
    text = TripleCheck(text, "ClassLevel%s*%(%s*([%w_]+)%s*%)", function(key)
        return GetClassLevel(playerInfo, key)
    end)

    text = string.gsub(text, "([%w_]+)", function(key)
        local value = self.replacementMap[key]
        if value then
            return value
        end
        return key
    end)

    text = TripleCheck(text, "Distance%s*%(%s*([%d%.]+)%s*%)", GetDistance)
    text = TripleCheck(text, "GainTemporaryHitPoints%s*%(%s*([%w_%+%-%*%./, ]+)%s*%)", GetTemporaryHitPoints)
    text = TripleCheck(text, "TemporaryHitPoints%s*%(%s*([%w_%+%-%*%./, ]+)%s*%)", GetTemporaryHitPoints)
    text = TripleCheck(text, "RegainHitPoints%s*%(%s*([%w_%+%-%*%./, ]+)%s*%)", RegainHitPoints)
    -- Lua doesn't have or (|) available for regex, so check each damage type. Otherwise, we have a problem with
    -- expressions like "DealDamage(1d6,Necrotic,,,,ad727a13-c6f0-4b5b-aefd-aac79c6ed46e)" (from Hex)
    for k, _ in pairs(damageTypeLoca) do
        text = TripleCheck(text, "DealDamage%s*%(%s*([%w_%+%-%*%./,%(%) ]+)%s*,%s*(" .. k .. ").*%)", DealDamage)
    end

    text = Trim(text)

    if damageTypeLoca[text] then
        text = damageTypeLoca[text]
    end

    -- Stuff Todo
    -- Ability(Strength,3)
    -- ApplyStatus(BLEEDING,100,2)
    -- ApplyStatus(FRIGHTENED,100,2)
    -- ApplyStatus(INVULNERABILITY,100,100)
    -- ApplyStatus(POISONED,100,2)
    -- ApplyStatus(REGENERATE,100,600)
    -- ApplyStatus(SLOW,100,2)
    -- UnarmedDamage
    -- UnarmedMeleeAbilityModifier
    -- MainMeleeWeaponDamageType
    -- MainRangedWeaponDamageType
    -- max(DexterityModifier,StrengthModifier)
    -- DealDamage(2d4+UnarmedMeleeAbilityModifier,Slashing), DealDamage(,Necrotic)
    -- Acid
    -- Bludgeoning
    -- Cold
    -- DamageBonus(1d4,Fire)
    -- EMPTY
    -- Fire
    -- Force
    -- GainTemporaryHitPoints(1d4+44)
    -- IF(Tagged('BARBARIAN')):RegainHitPoints(1d12+ConstitutionModifier)
    -- Lightning
    -- MaxHP
    -- Nil
    -- none
    -- Piercing
    -- Poison
    -- Psychic
    -- Radiant
    -- Slashing
    -- WeaponDamage(1d4, Poison)

    return text
end

---Resolve the text that can represent functions or relations into something human readable.
---@param text string
---@return string
function ParameterResolver:Resolve(text)
    local success, result = pcall(function ()
        return self:RunReplacements(self.playerInfo, text)
    end)
    if not success then
        _E6Error("Error resolving: " .. text .. " -> " .. result)
        return text
    end
    return result
end

return ParameterResolver