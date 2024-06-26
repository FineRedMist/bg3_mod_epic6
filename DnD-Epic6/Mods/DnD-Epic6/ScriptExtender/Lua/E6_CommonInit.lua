Ext.Require("E6_DumpSpell.lua")

local function OnStatsLoaded_RedirectXPFiles()
    Ext.Utils.Print("DnD-Epic6: Overriding Level Files (Data.txt, XPData.txt)")

    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/Data.txt", "Public/DnD-Epic6/Stats/Generated/Data/Data.txt")
    Ext.IO.AddPathOverride("Public/SharedDev/Stats/Generated/Data/XPData.txt", "Public/DnD-Epic6/Stats/Generated/Data/XPData.txt")
end

EpicSpellContainerName = "E6_Shout_EpicFeats" -- Also listed in E6_MakeFeatSpells.lua


local function E6_DumpSpell(name)
    _P("DnD-Epic6: Dumping spell properties from: " .. name)
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

local useDynamic = false

Ext.Require("Dynamic/E6_FeatConverter.lua")
Ext.Require("Static/E6_ConfigureFeats.lua")

function DnDEpic6Init()
    Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded_RedirectXPFiles)

    if useDynamic then
        E6_FeatConverterInit()
    else
        E6_ConfigureFeats()
    end
    --E6_DebugSpells()
end

