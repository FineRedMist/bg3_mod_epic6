Ext.Require("Shared/E6_Common.lua")
Ext.Require("Shared/E6_Dequeue.lua")
Ext.Require("Shared/E6_Jsonify.lua")
Ext.Require("Shared/E6_DumpSpell.lua")
Ext.Require("Shared/E6_GatherFeats.lua")
Ext.Require("Shared/E6_NetChannels.lua")
Ext.Require("Shared/E6_NetCommand.lua")
Ext.Require("Shared/E6_CommandRegistry.lua")

local function OnStatsLoaded_RedirectXPFiles()
    _E6P("Overriding Level Files (Data.txt, XPData.txt)")

    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/Data.txt", "Public/DnD-Epic6/Stats/Generated/Data/Data.txt")
    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/XPData.txt", "Public/DnD-Epic6/Stats/Generated/Data/XPData.txt")

    E6_GatherFeats() -- Precache this--it takes a bit of time
end

---@param name string
local function E6_DumpSpell(name)
    _E6P("Dumping spell properties from: " .. name)
    local spell = Ext.Stats.Get(name, -1, true, true)
    --_D(spell.SpellProperties)
    E6_DumpSpellMembers(spell)
end

local function E6_DebugSpells()
    E6_DumpSpell("E6_Shout_Feat_Alert")
    E6_DumpSpell("E6_Shout_Feat_Alert_Test1")
    --E6_DumpSpell("Projectile_ChromaticOrb")
    --E6_DumpSpell("Projectile_ChromaticOrb_Acid")
end

local function DnDEpic6Init()
    Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded_RedirectXPFiles)

    Ext.Vars.RegisterUserVariable("E6_Feats", {})
end

DnDEpic6Init()
