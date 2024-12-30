Ext.Require("Shared/E6_Logging.lua")
Ext.Require("Shared/E6_Types.lua")
Ext.Require("Shared/E6_Common.lua")
Ext.Require("Shared/E6_Dequeue.lua")
Ext.Require("Shared/E6_Jsonify.lua")
Ext.Require("Shared/E6_Parsing.lua")
Ext.Require("Shared/E6_Feat_Tables.lua")
Ext.Require("Shared/E6_FeatBuilders.lua")
Ext.Require("Shared/E6_FeatFiltering.lua")
Ext.Require("Shared/E6_GatherFeats.lua")
Ext.Require("Shared/E6_NetChannels.lua")
Ext.Require("Shared/E6_NetCommand.lua")
Ext.Require("Shared/E6_CommandRegistry.lua")

local function DnDEpic6Init()
    Ext.Vars.RegisterUserVariable("E6_Feats", {})
    Ext.Vars.RegisterUserVariable("E6_InCombat", {Client = true, Persistent = false, SyncToClient = true, SyncOnTick = true})
    Ext.Vars.RegisterUserVariable("E6_InDialog", {Client = true, Persistent = false, SyncToClient = true, SyncOnTick = true})
    Ext.Vars.RegisterModVariable(ModuleUUID, "E6_XPPerFeat", {Server = true, Client = false, SyncToClient = false})
    Ext.Vars.RegisterModVariable(ModuleUUID, "E6_XPPerFeatIncrease", {Server = true, Client = false, SyncToClient = false})
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

local function TextFeatXP()
    TestFeatCount(0, 1000, 0, 0)
    TestFeatCount(1000, 1000, 0, 1)
    TestFeatCount(1000, 1000, 1000, 1)
    TestFeatCount(2000, 1000, 1, 1)
    TestFeatCount(2001, 1000, 1, 2)
end

DnDEpic6Init()
--TextFeatXP()