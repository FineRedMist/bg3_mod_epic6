
function E6_SpellFeatHandlerInit()
    Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function (caster, spell, _, _, _)
        if spell == "E6_Shout_EpicFeats" then
            _P("E6_Shout_EpicFeats was cast by " .. caster)
        end
    end)
end