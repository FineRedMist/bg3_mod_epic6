Ext.Require("Shared/E6_Common.lua")
Ext.Require("Shared/E6_DumpSpell.lua")
Ext.Require("Shared/E6_NetChannels.lua")
Ext.Require("Shared/E6_NetCommand.lua")
Ext.Require("Shared/E6_CommandRegistry.lua")

local function OnStatsLoaded_RedirectXPFiles()
    _E6P("Overriding Level Files (Data.txt, XPData.txt)")

    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/Data.txt", "Public/DnD-Epic6/Stats/Generated/Data/Data.txt")
    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/XPData.txt", "Public/DnD-Epic6/Stats/Generated/Data/XPData.txt")
end

EpicSpellContainerName = "E6_Shout_EpicFeats" -- Also listed in E6_MakeFeatSpells.lua

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


Ext.Require("Dynamic/E6_FeatConverter.lua")

local function DnDEpic6Init()
    Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded_RedirectXPFiles)

    --E6_FeatConverterInit()
    --E6_DebugSpells()
end

DnDEpic6Init()
