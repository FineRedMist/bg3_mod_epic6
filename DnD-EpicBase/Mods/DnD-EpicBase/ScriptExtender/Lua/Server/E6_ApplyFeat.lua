
---Applies the spell boosts from the feat to the entity.
---@param entityId string The UUID identity of the character.
---@param feat SelectedFeatType The feat block as stored in Vars.E6_Feats.
local function E6_ApplySpells(entityId, feat)
    for _, boost in ipairs(GatherSpellBoostsForFeat(feat)) do
        Osi.AddBoosts(entityId, boost, "E6_Feat", feat.FeatId)
    end
end

local function E6_ApplyBoosts(entityId, boosts)
    if not boosts then
        return
    end
    for _, boost in ipairs(boosts) do
        Osi.AddBoosts(entityId, boost, "E6_Feat", "E6_Feat")
    end
end

---Applies a feat to an entity, does not add it to Vars.E6_Feats.
---@param entityId string The UUID identity of the character.
---@param feat SelectedFeatType The feat block as stored in Vars.E6_Feats.
function E6_ApplyFeat(entityId, feat)
    E6_ApplyBoosts(entityId, feat.Boosts)

    if feat.PassivesAdded then
        for _,passive in ipairs(feat.PassivesAdded) do
            Osi.AddPassive(entityId, passive)
        end
    end

    E6_ApplySpells(entityId, feat)
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
    if feat.Boosts then
        for _,boost in ipairs(feat.Boosts) do
            Osi.RemoveBoosts(entityId, boost, 1, "E6_Feat", feat.FeatId)
        end
    end
    if feat.PassivesAdded then
        for _,passive in ipairs(feat.PassivesAdded) do
            Osi.RemovePassive(entityId, passive)
        end
    end
    for _, boost in ipairs(GatherSpellBoostsForFeat(feat)) do
        Osi.RemoveBoosts(entityId, boost, 1, "E6_Feat", feat.FeatId)
    end
end

---@param entityId string The UUID identity of the character.
---@param feats SelectedFeatType[] A list of feat blocks as stored in Vars.E6_Feats.
function E6_RemoveFeats(entityId, feats)
    if feats == nil then
        return
    end
    for _,feat in ipairs(feats) do
        E6_RemoveFeat(entityId, feat)
    end
end

---Applies just the boosts from Vars.E6_Feats to the entity. This is getting lost on save/load so we need to reapply them.
---@param entityId string The UUID identity of the character.
---@param feats SelectedFeatType[] A list of feat blocks as stored in Vars.E6_Feats.
function E6_VerifyFeats(entityId, feats)
    if feats == nil then
        return
    end
    for _, feat in ipairs(feats) do
        E6_ApplyBoosts(entityId, feat.Boosts)
        E6_ApplySpells(entityId, feat)
    end
end

