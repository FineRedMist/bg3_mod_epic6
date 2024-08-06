NetServerHandlers = {}

function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
    _E6P("Selected feat specification: peer=" .. tostring(peerId) .. ", payload=" .. payload)
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats == nil then
        e6Feats = {}
    end
    table.insert(e6Feats, message.FeatId)
    entity.Vars.E6_Feats = e6Feats

    local result = Osi.ApplyStatus(message.PlayerId, message.Feat, -1, -1, message.PlayerId)
    _E6P("ApplyStatus result for " .. message.Feat .. ": " .. tostring(result))
    result = Osi.ApplyStatus(message.PlayerId, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, message.PlayerId)
    _E6P("ApplyStatus result for E6_FEAT_CONSUMEFEATPOINT: " .. tostring(result))
end

return NetServerHandlers
