
function E6_SpellFeatHandlerInit()
    _E6P("E6_Initializing spell feat handler.")
    Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function (caster, spell, _, _, _)
        if spell == EpicSpellContainerName then
            _E6P(EpicSpellContainerName .. " was cast by " .. caster)
            Ext.Net.PostMessageToClient(caster, NetChannels.E6_SERVER_TO_CLIENT_SHOW_FEAT_SELECTOR, caster)
        end
    end)
end