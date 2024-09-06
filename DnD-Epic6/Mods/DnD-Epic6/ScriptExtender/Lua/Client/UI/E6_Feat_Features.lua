---Adds the list of passives to the cell.
---@param cell ExtuiTableCell
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
local function AddFeaturesToCell(cell, feat, extraPassives)
    local avoidDupes = {}
    for _,passive in ipairs(feat.PassivesAdded) do
        local passiveStat = Ext.Stats.Get(passive,  -1, true, true)
        local key = passiveStat.DisplayName .. "|" .. passiveStat.Description .. "|" .. passiveStat.Icon
        if not avoidDupes[key] then
            local icon = cell:AddImage(passiveStat.Icon)
            AddLocaTooltipTitled(icon, passiveStat.DisplayName, passiveStat.Description)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end
    for _,passive in ipairs(extraPassives) do
        local key = passive.DisplayName .. "|" .. passive.Description .. "|" .. passive.Icon
        if not avoidDupes[key] then
            local icon = cell:AddImage(passive.Icon)
            AddLocaTooltipTitled(icon, passive.DisplayName, passive.Description)
            icon.SameLine = true
            avoidDupes[key] = true
        end
    end
end

---Adds the passives to the feat details, if present.
---@param parent ExtuiTreeParent
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
function AddFeaturesToFeatDetailsUI(parent, feat, extraPassives)
    if #feat.PassivesAdded > 0 or #extraPassives then
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()
        AddLocaTitle(parent, "hffc72a17g6934g42f8ga935g447764ee6f43") -- Features
        local passivesCell = CreateCenteredControlCell(parent, "Passives", parent.Size[1] - 60)
        AddFeaturesToCell(passivesCell, feat, extraPassives)
    end
end