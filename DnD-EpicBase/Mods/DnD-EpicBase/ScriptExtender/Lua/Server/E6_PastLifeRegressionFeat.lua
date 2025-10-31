

local pastLifeRegressionsId = "cb2def23-b880-49e8-906f-d97b822c093a"

---We need to gather feats that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle The player entity to gather feats for.
---@return table<string, number> The count of occurrences for each feat. 
function E6_GatherPlayerFeats(entity)
    local feats = {}
    if entity == nil then
        return feats
    end
    local CCLevelUp = entity.CCLevelUp
    if CCLevelUp == nil then
        return feats
    end
    local function AddFeat(feat)
        if IsValidGuid(feat) then
            local curCount = feats[feat]
            if curCount == nil then
                curCount = 1
            else
                curCount = curCount + 1
            end
            feats[feat] = curCount
        end
    end

    for _, levelup in ipairs(CCLevelUp.LevelUps) do
        AddFeat(levelup.Feat)
        if levelup.Upgrades ~= nil then
            for _, upgrade in ipairs(levelup.Upgrades.Feats) do
                AddFeat(upgrade.Feat)
            end
        end
    end

    ---@type SelectedFeatType[]
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats ~= nil then
        for _, feat in ipairs(e6Feats) do
            AddFeat(feat.FeatId)
        end
    end
    return feats
end


--- Updates the background of the character to point to the Past Life Regression background 
--- if the player has selected the Past Life Regression feat.
--- @param ent EntityHandle The player's entity handle.
function E6_UpdateCharacterBackground(ent)
    if not ent or not ent.Background or not ent.Background.Background or ent.Background.Background == pastLifeRegressionsId then
        return
    end

    local currentBackground = ent.Background.Background
    local feats = E6_GatherPlayerFeats(ent)

end
