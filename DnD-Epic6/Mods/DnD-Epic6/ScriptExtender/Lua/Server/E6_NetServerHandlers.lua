NetServerHandlers = {}


function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
    _E6P("Selected feat specification: peer=" .. tostring(peerId) .. ", payload=" .. payload)
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)

    local e6Feats = entity.Vars.E6_Feats
    if e6Feats == nil then
        e6Feats = {}
    end
    table.insert(e6Feats, message.Feat)
    entity.Vars.E6_Feats = e6Feats

    E6_ApplyFeat(message.PlayerId, message.Feat)
    Osi.ApplyStatus(message.PlayerId, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, message.PlayerId)
end

return NetServerHandlers
