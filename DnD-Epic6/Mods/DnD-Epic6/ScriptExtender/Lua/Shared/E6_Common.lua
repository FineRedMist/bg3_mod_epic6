EpicSpellContainerName = "E6_Shout_EpicFeats"

GuidZero = "00000000-0000-0000-0000-000000000000"

local GuidMatch = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

---Determines if the guid is a valid guid, not nil, not the zero guid, and in a guid format.
---@param guid string
---@return boolean
function IsValidGuid(guid)
    return guid ~= nil and string.len(guid) == string.len(GuidZero) and guid ~= GuidZero and string.match(guid, GuidMatch) ~= nil
end

---Helper function to convert an argument to a string. Nil becomes an empty string.
---@param arg any
---@return string
local function ArgString(arg)
    if arg == nil then
        return ""
    end
    return tostring(arg)
end

---Retrieves the ability modifier for a given ability score.
---@param abilityScore integer The ability score to get the modifier for.
---@return integer The modifier based on the score.
function GetAbilityModifier(abilityScore)
    return math.floor((abilityScore - 10) / 2)
end

---Joins multiple terms together as a string for various functions.
---@param args table The list of arguments to join. Must be amenable to tostring. nil is converted to the empty string
---@param separator string? The separator to join the terms with. Defaults to comma if unspecified.
---@return string Arguments joined by the separator, with nils replaced by the empty string, preserving positions in the list.
function JoinArgs(args, separator)
    if not separator then
        separator = ","
    end
    local result = ""
    local count = #args
    for i=1, count do
        if i > 1 then
            result = result .. separator
        end
        result = result .. ArgString(args[i])
    end
    return result
end

---Splits a string based on the separator, which defaults to whitspace
---@param inputstr string The string to split
---@param separator string? The separator to split the string with
---@param includeSeparators boolean? Whether to include the separators in the resulting list, default false
---@return string[] The list of tokens split by separator
function SplitString(inputstr, separator, includeSeparators)
    if inputstr == nil then
        return {}
    end
    if separator == nil then
        separator = "%s"
    end
    local result = {}
    local pos = 1
    for str in string.gmatch(inputstr, "([^"..separator.."]+)") do
      table.insert(result, str)
      pos = pos + string.len(str)
      if includeSeparators then
        local s, e = string.find(inputstr, "(["..separator.."]+)", pos)
        if s then
          table.insert(result, string.sub(inputstr, s, e))
          pos = e + 1
        end
      end
    end
    return result
  end

---Gets the complete set of terms matched by the expression.
---@param str string The string to gather matches against
---@param regex string The regular expression to gather matches for
---@return table? The list of matched terms
function GetFullMatch(str, regex)
    local iterFn, state, other = str:gmatch(regex)
    local current = table.pack(iterFn(state, other))
    if #current > 0 then
        return current
    else
        return nil
    end
end

---Substitutes substrings in str with the values in parameters, which maps the keys to the values.
---@param str string The string to substitute values in.
---@param parameters table<string,any> The parameters to substitute in the string. Keys exclude the curly braces.
---@return string The string with the parameters substituted.
function SubstituteParameters(str, parameters)
    for key, value in pairs(parameters) do
        str = string.gsub(str, "{" .. key .. "}", tostring(value))
    end
    return str
end

---Strips xml tags and restores spaces after periods.
---@param str string The string to remove xml tags from.
---@return string The 'tidied' string. There can be resulting anomalies.
function TidyDescription(str)
    if false then
        for match in string.gmatch(str, "<[^>]+>") do
            _E6P("Found Xml Tag: " .. match)
        end
    end
    str = string.gsub(str, "<br>", "\n")
    str = string.gsub(str, "\r", "")
    str = string.gsub(str, "\n \n", "\n\n")
    str = string.gsub(str, "\n\n\n", "\n\n")
    str = string.gsub(str, "<[^>]+>", " ")
    str = string.gsub(str, "  ", " ")
    str = string.gsub(str, " ([,.])", "%1")
    str = string.gsub(str, "’", "'")
    return str
end

---Converts an argument to a string. 
--- If it is a function, it will resolve it and then continue processiong
--- If it is a string, it will attempt to localize it, otherwise just return the string.
--- If it is a table, it will error out.
--- If it is nil, it will return an empty string.
--- Otherwise, it will return the string representation of the argument.
---@param arg any The argument to lookup.
---@return string The string representation of the argument (with function evaluation and localization)
function GetParameterArgument(arg)
    if type(arg) == "function" then
        arg = arg()
    end
    if type(arg) == "string" then
        local loca = Ext.Loca.GetTranslatedString(arg)
        if type(loca) == "string" and string.len(loca) > 0 then
            return loca
        end
        return arg
    end
    if type(arg) == "table" then
        _E6Error("Unsupported table passed to GetParameterArgument: " .. Ext.Json.Stringify(arg))
        return ""
    end
    if type(arg) == "nil" then
        return ""
    end
    return tostring(arg)
end

---Substitutes parameters using the format [1], [2], etc, indexing into the parameters table.
---It will call functions to get values if provided as substitutes, then try loca lookups for strings,
---then pass each part of the string to the function given.
---@param loca string The localization string to start with for the parameterized loca
---@param args any[]? The parameters to substitute into the loca string
---@param func function The function to process each piece of the resulting string
function ProcessParameterizedLoca(loca, args, func)
    local message = GetParameterArgument(loca)
    if args == nil or #args == 0 then
        func(message)
        return
    end

    local parts = {message}
    -- Go through each argument and process replacements in the parts list.
    -- Each instance of [1], [2], etc will be expanded so that [1], [2] are isolated
    -- as their own elements to be replaced in the parts list.
    -- For example:
    --   "Hello [1], how are you [2]?"
    -- Becomes:
    --   {"Hello ", "[1]", ", how are you ", "[2]", "?"}
    -- It will then swap in the arguments and continue to expand the list until all 
    -- arguments are processed.
    for argIndex, argParam in ipairs(args) do
        local substitute = "[" .. tostring(argIndex) .. "]"
        local arg = GetParameterArgument(argParam)
        for partIndex, part in ipairs(parts) do
            local foundIndex = string.find(part, substitute, 1, true)
            if foundIndex then
                local before = string.sub(part, 1, foundIndex - 1)
                local after = string.sub(part, foundIndex + string.len(substitute))
                parts[partIndex] = before
                table.insert(parts, partIndex + 1, arg)
                table.insert(parts, partIndex + 2, after)
                partIndex = partIndex + 1 -- Skip the argument for processing (avoids recursion), but ensure we process 'after', the for-loop will increment the index by 1.
            end
        end
    end
    for _, part in ipairs(parts) do
        func(part)
    end
end

---Trims the leading and trailing whitespace of a string.
---@param s string The string to trim
---@return string The trimmed string
function Trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
 end

---Substitutes parameters using the format [1], [2], etc, indexing into the parameters table.
---It will call functions to get values if provided as substitutes, then try loca lookups for strings,
---then convert the value to a string.
---@param loca string The localization string to start with for the parameterized loca
---@param args any[]? The parameters to substitute into the loca string
function GetParameterizedLoca(loca, args)
    local result = ""
    ProcessParameterizedLoca(loca, args, function(part)
        result = result .. part
    end)

    return result
end

---Retrieves the name for the character, either from the CharacterCreationStats or the Origin
---@param entity EntityHandle -- The entity to retrieve the name for
---@param[opt=false] returnNil boolean -- If true, return nil if the name is unknown, otherwise return <unknown>
---@return string? -- The name of the character or <unknown>
function GetCharacterName(entity, returnNil)
    local defaultReturn = nil
    if not returnNil then
        defaultReturn = "<Unknown>"
    end
    if not entity then
        return defaultReturn
    end
    local stats = entity.CharacterCreationStats
    if not stats then
        return defaultReturn
    end
    local statName = stats.Name
    if statName and string.len(statName) > 0 then
        return statName
    end
    local origin = entity.Origin
    if not origin then
        return defaultReturn
    end
    local originName = origin.Origin
    if not originName or string.len(originName) == 0 then
        return defaultReturn
    end
    return originName
end

---Creates a deep copy of an object.
---@param o any The object to generate a deep copy of.
---@param seen table? A table to track which objects have been visited.
---@return any The deep copy of the object.
function DeepCopy(o, seen)
    seen = seen or {}
    if o == nil then return nil end
    if seen[o] then return seen[o] end
  
    local no
    if type(o) == 'table' then
      no = {}
      seen[o] = no
  
      for k, v in next, o, nil do
        no[DeepCopy(k, seen)] = DeepCopy(v, seen)
      end
      setmetatable(no, DeepCopy(getmetatable(o), seen))
    else -- number, string, boolean, etc
      no = o
    end
    return no
  end

  ---Whether the current player id is for the host.
---@param playerId GUIDSTRING The player id to check if they are the host
---@return boolean Whether the current character is the host
function IsHost(playerId)
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor.UserID == 65537 and entity.Uuid.EntityUuid == playerId then
            return true
        end
    end

    return false
end

---Gather the entities with client controls. This is for the server to gather all instances of clients playing.
---@return EntityHandle[] The list of entity handles that are clients.
function GetClientEntities()
    local entities = {}
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor then
            table.insert(entities, entity)
        end
    end

    return entities
end

---Gets the locally controlled entity for the client side.
---@return EntityHandle? The entity under client control.
function GetLocallyControlledCharacter()
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor and entity.UserReservedFor.UserID == 1 then
            return entity
        end
    end
    return nil
end

---Converts a string to PascalCase (does no internal checking)
---@param str string
---@return string
function ToPascalCase(str)
    return string.sub(str, 1, 1):upper() .. string.sub(str, 2):lower()
end

---Normalizes a string with separators to use PascalCase
---@param str string
---@return string
function NormalizePascalCase(str)
    for _, sep in ipairs({"_", " ", "-"}) do
        local parts = SplitString(str, "_")
        if #parts > 1 then
            local result = ""
            for _,part in ipairs(parts) do
                result = result .. ToPascalCase(part)
            end
            return result
        end
    end
    return ToPascalCase(str)
end