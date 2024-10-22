
---Applies a feat to an entity, does not add it to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feat SelectedFeatType The feat block as stored in Vars.E6_Feats.
function E6_ApplyFeat(entityId, feat)
    if feat.PassivesAdded then
        for _,passive in ipairs(feat.PassivesAdded) do
            Osi.AddPassive(entityId, passive)
        end
    end
    if feat.Boosts then
        for _,boost in ipairs(feat.Boosts) do
            Osi.AddBoosts(entityId, boost, "E6_Feat", feat.FeatId)
        end
    end
end

---Applies the feats to the entity, does not add them to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feats SelectedFeatType[] A list of feat blocks as stored in Vars.E6_Feats.
function E6_ApplyFeats(entityId, feats)
    for _,feat in ipairs(feats) do
        E6_ApplyFeat(entityId, feat)
    end
end

---Removes a feat from an entity, does not remove it to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feat SelectedFeatType The feat block as stored in Vars.E6_Feats.
function E6_RemoveFeat(entityId, feat)
    if feat.PassivesAdded then
        for _,passive in ipairs(feat.PassivesAdded) do
            Osi.RemovePassive(entityId, passive)
        end
    end
    if feat.Boosts then
        for _,boost in ipairs(feat.Boosts) do
            Osi.RemoveBoosts(entityId, boost, 1, "E6_Feat", feat.FeatId)
        end
    end
end

---@param entityId string The UUID identity of the character.
---@param feats SelectedFeatType[] A list of feat blocks as stored in Vars.E6_Feats.
function E6_RemoveFeats(entityId, feats)
    _E6P("Removing feats from " .. entityId)
    for _,feat in ipairs(feats) do
        E6_RemoveFeat(entityId, feat)
    end
end

---@class NewBoostRecordCountType : NewBoostRecordType
---@field Count integer The number of times the boost has been applied.

---@class FeatAndPassiveCheckListType
---@field Passives table<string, integer> A mapping of passives to the number found
---@field Boosts table<string, NewBoostRecordCountType> A mapping of boosts to the number found

---Gathers all the feats and passives for the entity.
---@param entityId string The UUID identity of the character.
local function E6_GatherFeatsAndPassives(entityId)
    ---@type FeatAndPassiveCheckListType
    local result = {Passives = {}, Boosts = {}}
    local entity = Ext.Entity.Get(entityId)
    if entity.PassiveContainer then
        for _,passive in ipairs(entity.PassiveContainer.Passives) do
            local passiveId = passive.Passive.PassiveId
            local count = result.Passives[passiveId]
            if not count then
                count = 0
            end
            count = count + 1
            result.Passives[passiveId] = count
        end
    end

    if entity.BoostContainer then
        
    end
end

---Applies just the boosts from Vars.E6_Feats to the entity. This is getting lost on save/load so we need to reapply them.
---@param entityId string The UUID identity of the character.
---@param feats SelectedFeatType[] A list of feat blocks as stored in Vars.E6_Feats.
function E6_VerifyFeats(entityId, feats)

end

