
---Applies a feat to an entity, does not add it to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feat table The feat block as stored in Vars.E6_Feats.
function E6_ApplyFeat(entityId, feat)
    for _,passive in ipairs(feat.PassivesAdded) do
        Osi.AddPassive(entityId, passive)
    end
    Osi.ApplyStatus(entityId, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, entityId)
end

---Applies the feats to the entity, does not add them to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feats table A list of feat blocks as stored in Vars.E6_Feats.
function E6_ApplyFeats(entityId, feats)
    for _,feat in ipairs(feats) do
        E6_ApplyFeat(entityId, feat)
    end
end

---Removes a feat from an entity, does not remove it to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feat table The feat block as stored in Vars.E6_Feats.
function E6_RemoveFeat(entityId, feat)
    for _,passive in ipairs(feat.PassivesAdded) do
        Osi.RemovePassive(entityId, passive)
    end
end

---@param entityId string The UUID identity of the character.
---@param feats table A list of feat blocks as stored in Vars.E6_Feats.
function E6_RemoveFeats(entityId, feats)
    for _,feat in ipairs(feats) do
        E6_RemoveFeat(entityId, feat)
    end
end
