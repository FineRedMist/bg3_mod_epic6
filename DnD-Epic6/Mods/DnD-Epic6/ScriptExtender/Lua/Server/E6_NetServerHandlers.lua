NetServerHandlers = {}

function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
    _E6P("Selected feat specification: peer=" .. tostring(peerId) .. ", payload=" .. payload)
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)

    local passive = Ext.Stats.Get(message.Feat, -1, false, true)
    if passive == nil then
        _E6Error("Failed to find passive for feat: " .. message.Feat)
        return
    end

    local e6Feats = entity.Vars.E6_Feats
    if e6Feats == nil then
        e6Feats = {}
    end
    table.insert(e6Feats, message.FeatId)
    entity.Vars.E6_Feats = e6Feats

    local result = Osi.ApplyStatus(message.PlayerId, message.Feat, 100, -1, message.PlayerId)
    _E6P("ApplyStatus result for " .. message.Feat .. ": " .. tostring(result))
    result = Osi.ApplyStatus(message.PlayerId, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, message.PlayerId)
    _E6P("ApplyStatus result for E6_FEAT_CONSUMEFEATPOINT: " .. tostring(result))

    local json = E6_ToJson(entity)
    local str = Ext.Json.Stringify(json)
    Ext.IO.SaveFile("E6_character.json", str)
end

return NetServerHandlers
