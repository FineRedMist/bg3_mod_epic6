NetServerHandlers = {}


function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
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

function NetServerHandlers.ExportCharacter(_, payload, peerId)
    local entity = Ext.Entity.Get(payload)
    if entity ~= nil then
        E6_ToFile(entity, "E6_Character.json", {"Party", "ServerReplicationDependencyOwner", "InventoryContainer"})
    end
end

return NetServerHandlers
