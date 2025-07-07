
---Exports the character's profile information to the file system as json. It skips numerous fields to avoid to much data (and redundancy).
---@param _ string Command called
---@param charId string Character ID
local function ExportCharacter(_, charId, ...)
    local entity = Ext.Entity.Get(charId)
    if entity ~= nil then
        --local datePrefix = os.date("%Y-%m-%d")
        local character = GetCharacterName(entity)
        E6_ToFile(entity, character .. "-Character-Export.json", {"Party", "ServerReplicationDependencyOwner", "InventoryContainer", "ServerRecruitedBy", "ServerOwneeHistory", "StatusManager"})
    else
        _E6Error("Failed find the character '" .. charId .. "' to export.")
    end
end

---Exports the character's Epic 6 data to the file system as json.
---@param _ string Command called
---@param charId string Character ID
local function ExportEpicSix(_, charId, ...)
    local entity = Ext.Entity.Get(charId)
    if not entity then
        _E6Error("Failed to get the entity for the id: " .. charId)
        return
    end

    --local datePrefix = os.date("%Y-%m-%d")
    local playerInfo = GetFullPlayerInfo(entity)
    if not playerInfo then
        _E6Error("Failed to get the player info for: " .. charId)
        return
    end
    local data = {
        PlayerInfo = playerInfo,
        SelectedFeats = entity.Vars.E6_Feats
    }
    local filename = playerInfo.Name .. "-EpicSix-Export.json"
    Ext.IO.SaveFile(filename, Ext.Json.Stringify(data))
    _E6P("Json data saved to %LOCALAPPDATA%\\Larian Studios\\Baldur's Gate 3\\Script Extender\\" .. filename .. ".")
end

---Gets the race of the entity if the name cannot be retrieved. Also returns the level if available.
---@param entity EntityHandle Character ID to dump the party for.
local function GetEntityInfo(entity)
    local name = GetCharacterName(entity, true)
    if name == nil then
        if entity.Race then
            local raceGuid = entity.Race.Race
            ---@type ResourceRace
            local race = Ext.StaticData.Get(raceGuid, Ext.Enums.ExtResourceManagerType.Race)
            if race then
                name = race.DisplayName:Get()
            end
        end
    end
    if name == nil then
        name = "<unknown>"
    end
    local availableLevel = nil
    if entity.AvailableLevel then
        availableLevel = "Level " .. tostring(entity.AvailableLevel.Level)
    end
    local eocLevel = nil
    if entity.EocLevel then
        eocLevel = "EOC Level " .. tostring(entity.EocLevel.Level)
    end
    local level = nil
    if availableLevel and eocLevel then
        level = availableLevel .. ", " .. eocLevel
    elseif availableLevel then
        level = availableLevel
    elseif eocLevel then
        level = eocLevel
    end
    if level then
        return name .. " (" .. level .. ")"
    end
    return name
end

---Iterates through the party views for the given character id, calling the function for each member.
---@param charId string Character ID
---@param onMember function The function to call for each member
local function IterParty(charId, onMember)
    local entity = Ext.Entity.Get(charId)
    if not entity then
        _E6Error("Failed to get the entity for the id: " .. charId)
        return
    end

    if not entity.PartyMember then
        _E6Error("Failed to get the party member for the entity: ".. charId)
        return
    end

    if not entity.PartyMember.Party then
        _E6Error("Failed to get the party member party for the entity: ".. charId)
        return
    end

    if not entity.PartyMember.Party.PartyView then
        _E6Error("Failed to get the party member party party view for the entity: ".. charId)
        return
    end

    local partyView = entity.PartyMember.Party.PartyView

    for i, v in ipairs(partyView.Views) do
        for j, c in ipairs(v.Characters) do
            onMember(i, j, c)
        end
    end
end

---Dumps the party members for the given character id, including summons.
---@param _ string Command called 
---@param charId string Character ID to dump the party for.
local function DumpParty(_, charId)
    _E6P("Views for: " .. charId)
    local partyView = {}

    IterParty(charId, function(i, j, c)
        if not partyView[i] then
            _E6P("  Party view: " .. tostring(i))
            partyView[i] = true
        end
        _E6P("    Party member: " .. GetEntityInfo(c))
    end)
end

---Attempts to fix the summons in the party for the given character id, but it doesn't work.
---@param _ string Command called 
---@param charId string Character ID to dump the party for.
local function FixParty(_, charId)
    _E6P("Views for: " .. charId)
    local partyView = {}

    IterParty(charId, function(i, j, c)
        if not partyView[i] then
            _E6P("  Party view: " .. tostring(i))
            partyView[i] = true
        end
        _E6P("    Party member: " .. GetEntityInfo(c))
        local changed = false
        if c.AvailableLevel.Level > E6_GetMaxLevel() then
            c.AvailableLevel.Level = E6_GetMaxLevel()
            changed = true
        end
        if c.EocLevel.Level > E6_GetMaxLevel() then
            c.EocLevel.Level = E6_GetMaxLevel()
            changed = true
        end
        if changed then
            _E6P("    Party member: " .. GetEntityInfo(c))
        end
    end)
end

---Prints the number of feats that can be granted for the given XP.
---@param _ string The command
---@param xp string|number? The XP to calculate the feat count for.
---@param xpPerFeat string|number? The XP per feat to use. If not provided, the mod's value is used.
---@param xpPerFeatIncrease string|number? The XP per feat increase to use. If not provided, the mod's value is used.
local function GetFeatCount(_, xp, xpPerFeat, xpPerFeatIncrease)
    local savedXP = xp
    local savedXPPerFeat = xpPerFeat
    local savedXPPerFeatIncrease = xpPerFeatIncrease
    if xp == nil then
        local entityId = Osi.GetHostCharacter()
        local entity = Ext.Entity.Get(entityId)
        if not entity then
            _E6Error("Failed to get the entity for the id: " .. entityId)
            return
        end
        if entity.EocLevel.Level < E6_GetMaxLevel() then
            _E6Error("The character isn't level " .. tostring(E6_GetMaxLevel()) .. " yet to get epic feats.")
            return
        end
        xp = entity.Experience.CurrentLevelExperience
        if xp == nil then
            _E6Error("XP is required.")
            return
        end
    end
    xp = tonumber(xp)
    if xp == nil then
        _E6Error("The XP '" .. savedXP .. "' is invalid.")
        return
    end
    if xpPerFeat == nil then
        xpPerFeat = GetEpicFeatXP()
    else
        xpPerFeat = tonumber(xpPerFeat)
    end
    if xpPerFeat == nil then
        _E6Error("The xpPerFeat '" .. savedXPPerFeat .. "' is invalid.")
        return
    end
    if xpPerFeatIncrease == nil then
        xpPerFeatIncrease = GetEpicFeatXPIncrease()
    else
        xpPerFeatIncrease = tonumber(xpPerFeatIncrease)
    end
    if xpPerFeatIncrease == nil then
        _E6Error("The xpPerFeatDelta '" .. savedXPPerFeatIncrease .. "' is invalid.")
        return
    end
    local count = GetFeatCountForXPBase(xp, xpPerFeat, xpPerFeatIncrease)
    local nextFeatXP = GetXPForNextFeatBase(xp, xpPerFeat, xpPerFeatIncrease)
    _E6P("XP=" .. tostring(xp) .. ", XP/feat=" .. tostring(xpPerFeat) .. ", XP/feat delta=" .. tostring(xpPerFeatIncrease) .. ", feat count=" .. tostring(count) .. ", XP required for next feat: " .. tostring(nextFeatXP))
end

local function TestFeatCount(xp, featXP, featXPDelta, expectedCount)
    local count = GetFeatCountForXPBase(xp, featXP, featXPDelta)
    local result = "XP=" .. tostring(xp) .. ", XP/feat=" .. tostring(featXP) .. ", XP/feat delta=" .. tostring(featXPDelta) .. ", expected " .. tostring(expectedCount) .. " but got " .. tostring(count)
    if count ~= expectedCount then
        _E6Error(result)
    else
        _E6P(result)
    end
end

---Tests the feat count calculation.
local function TestXPCalc()
    TestFeatCount(0, 1000, 0, 0)
    TestFeatCount(1000, 1000, 0, 1)
    TestFeatCount(1000, 1000, 1000, 1)
    TestFeatCount(2000, 1000, 1, 1)
    TestFeatCount(2001, 1000, 1, 2)
end

Ext.RegisterConsoleCommand("E6_ExportCharacter", ExportCharacter)
Ext.RegisterConsoleCommand("E6_ExportEpicSix", ExportEpicSix)
Ext.RegisterConsoleCommand("E6_DumpParty", DumpParty)
Ext.RegisterConsoleCommand("E6_FixParty", FixParty)
Ext.RegisterConsoleCommand("E6_GetFeatCount", GetFeatCount)
Ext.RegisterConsoleCommand("E6_TestXPCalc", TestXPCalc)
