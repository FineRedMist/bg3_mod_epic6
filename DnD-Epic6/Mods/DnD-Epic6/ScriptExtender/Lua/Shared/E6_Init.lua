Ext.Require("Shared/E6_Logging.lua")
Ext.Require("Shared/E6_Common.lua")
Ext.Require("Shared/E6_Dequeue.lua")
Ext.Require("Shared/E6_Jsonify.lua")
Ext.Require("Shared/E6_Parsing.lua")
Ext.Require("Shared/E6_Feat_Tables.lua")
Ext.Require("Shared/E6_FeatBuilders.lua")
Ext.Require("Shared/E6_Types.lua")
Ext.Require("Shared/E6_GatherFeats.lua")
Ext.Require("Shared/E6_NetChannels.lua")
Ext.Require("Shared/E6_NetCommand.lua")
Ext.Require("Shared/E6_CommandRegistry.lua")

local function OnStatsLoaded_RedirectXPFiles()
    _E6P("Overriding Level Files (Data.txt, XPData.txt)")

    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/Data.txt", "Public/DnD-Epic6/Stats/Generated/Data/Data.txt")
    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/XPData.txt", "Public/DnD-Epic6/Stats/Generated/Data/XPData.txt")
end

local function DnDEpic6Init()
    Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded_RedirectXPFiles)

    Ext.Vars.RegisterUserVariable("E6_Feats", {})
    Ext.Vars.RegisterModVariable(ModuleUUID, "E6_XPPerFeat", {Server = true, Client = false, SyncToClient = false})
end

DnDEpic6Init()
