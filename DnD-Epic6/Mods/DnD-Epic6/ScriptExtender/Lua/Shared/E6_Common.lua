EpicSpellContainerName = "E6_Shout_EpicFeats"

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

---@param message string
function _E6P(message)
    local hostType = "Client"
    if(Ext.IsServer()) then
        hostType = "Server"
    end
    _P("E6[" .. hostType .. "]: " .. message)
end

---@param message string
function _E6Warn(message)
    local hostType = "Client"
    if(Ext.IsServer()) then
        hostType = "Server"
    end
    Ext.Utils.PrintWarning("E6[" .. hostType .. "]: " .. message)
end

---@param message string
function _E6Error(message)
    local hostType = "Client"
    if(Ext.IsServer()) then
        hostType = "Server"
    end
    Ext.Utils.PrintError("E6[" .. hostType .. "]: " .. message)
end

-- Thanks to Aahz for this function
---comment
---@param u integer
---@return integer
function PeerToUserID(u)
    -- all this for userid+1 usually smh
    return (u & 0xffff0000) | 0x0001
end

-- Return the party members currently following the player
---@return table<integer,string>
function GetPartyMembers()
    local teamMembers = {}

    local allPlayers = Osi.DB_Players:Get(nil)
    for _, player in ipairs(allPlayers) do
        if not string.match(player[1]:lower(), "%f[%A]dummy%f[%A]") then
            teamMembers[#teamMembers + 1] = string.sub(player[1], -36)
        end
    end

    return teamMembers
end

-- Returns the character that the user is controlling
---@param userId integer
---@return string?
function GetUserCharacter(userId)
    if not _C().PartyComposition then
        return nil
    end
    for _, member in ipairs(_C().PartyComposition.Members) do
        if member.UserId == userId then
            return member.UserUUid
        end
    end
    return nil
end