
Ext.Require("Dynamic/E6_GatherFeats.lua")
Ext.Require("Dynamic/E6_MakeFeatSpells.lua")


local function E6_DumpMods(e)
    if e ~= nil and e.ToState ~= nil and e.ToState == Ext.Enums.ServerGameState.Running then
        _E6P("********** Dumping mods **********")
        _D(mods)
        _E6P("********** Mods dumped **********")
    end
    _E6P("DnD-Epic6: Client State change from " .. e.FromState.Label .. " to " .. e.ToState.Label)
end

local function E6_OnStatsLoaded()
    local featSet = E6_GatherFeats()
    E6_GenerateDynamicFeats(featSet)
end

function E6_FeatConverterInit()
    --Ext.Events.GameStateChanged:Subscribe(E6_DumpMods)
    Ext.Events.StatsLoaded:Subscribe(E6_OnStatsLoaded)
end
