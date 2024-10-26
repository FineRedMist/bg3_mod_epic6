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
---@param separator any The separator to split the string with
---@return table The list of tokens split by separator
function SplitString(inputstr, separator)
    if separator == nil then
        separator = "%s"
    end
    local result = {}
    for str in string.gmatch(inputstr, "([^"..separator.."]+)") do
      table.insert(result, str)
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
---@param arg any
---@return string
local function GetParameterArgument(arg)
    if type(arg) == "function" then
        return arg()
    end
    if type(arg) == "string" then
        local loca = Ext.Loca.GetTranslatedString(arg)
        if loca then
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
---then convert the value to a string.
---@param loca string The localization string to start with for the parameterized loca
---@param ... any The parameters to substitute into the loca string
function GetParameterizedLoca(loca, ...)
    local message = Ext.Loca.GetTranslatedString(loca)
    for i,v in ipairs(arg) do
        local keySubString = "%[" .. tostring(i) .. "%]"
        message = string.gsub(message, keySubString, GetParameterArgument(v))
    end
    return message
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

