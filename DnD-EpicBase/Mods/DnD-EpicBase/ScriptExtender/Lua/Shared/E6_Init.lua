Ext.Require("Shared/E6_Logging.lua")
Ext.Require("Shared/E6_Types.lua")
Ext.Require("Shared/E6_UniqueList.lua")
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
Ext.Require("Shared/E6_ClientControlledCharacters.lua")


local function DnDEpic6Init()
    Ext.Vars.RegisterUserVariable("E6_Feats", {})
    Ext.Vars.RegisterUserVariable("E6_InCombat", {Client = true, Persistent = false, SyncToClient = true, SyncOnTick = true})
    Ext.Vars.RegisterUserVariable("E6_InDialog", {Client = true, Persistent = false, SyncToClient = true, SyncOnTick = true})
    Ext.Vars.RegisterModVariable(ModuleUUID, "E6_XPPerFeat", {Server = true, Client = false, SyncToClient = false})
    Ext.Vars.RegisterModVariable(ModuleUUID, "E6_XPPerFeatIncrease", {Server = true, Client = false, SyncToClient = false})

    RegisterClientControlHandlers()

    -- Force setting the maximum XP cap on stats load. Setting it in data.txt depends on load order.
    Ext.Events.StatsLoaded:Subscribe(function()
        Ext.Stats.GetStatsManager().ExtraData.MaximumXPCap = Ext.Stats.GetStatsManager().ExtraData.Epic6MaximumXPCap
    end)
end

DnDEpic6Init()