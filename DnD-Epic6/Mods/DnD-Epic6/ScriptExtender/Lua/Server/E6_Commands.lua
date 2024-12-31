
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
        if c.AvailableLevel.Level > 6 then
            c.AvailableLevel.Level = 6
            changed = true
        end
        if c.EocLevel.Level > 6 then
            c.EocLevel.Level = 6
            changed = true
        end
        if changed then
            _E6P("    Party member: " .. GetEntityInfo(c))
        end
    end)
end

local function TestFeatCount(xp, featXP, featXPDelta, expectedCount)
    local count = GetFeatCountForXPBase(xp, featXP, featXPDelta)
    local result = "XP=" .. tostring(xp) .. ", featXP=" .. tostring(featXP) .. ", featXPDelta=" .. tostring(featXPDelta) .. ", expected " .. tostring(expectedCount) .. " but got " .. tostring(count)
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
Ext.RegisterConsoleCommand("E6_TestXPCalc", TestXPCalc)
