---Removes all children from the parent.
---@param parent ExtuiTreeParent
function ClearChildren(parent)
    local children = parent.Children
    for _, child in ipairs(children) do
        parent:RemoveChild(child)
    end
end

--- Create a table for the RGBA values
--- This is useful because of syntax highlighting that is not present when typing a table directly
---@param r number
---@param g number
---@param b number
---@param a number
---@return table<number>
function RGBA(r, g, b, a)
    return { r, g, b, a }
end

--- Create a table for the RGBA values, normalized to 0-1
--- This is useful because of syntax highlighting that is not present when typing a table directly
---@param r number
---@param g number
---@param b number
---@param a number
---@return table<number>
function NormalizedRGBA(r, g, b, a)
    if r > 1 or g > 1 or b > 1 then
        return { r / 255, g / 255, b / 255, a }
    else
        return RGBA(r, g, b, a)
    end
end


---Adds a tooltip to the target with the given text.
---@param target ExtuiStyledRenderable
---@param text string The text of the tooltip
function AddTooltip(target, text)
    local tooltip = target:Tooltip()
    tooltip.IDContext = target.IDContext .. "_TOOLTIP"
    ClearChildren(tooltip)
    local textControl = tooltip:AddText(text)
    textControl.ItemWidth = 500
    textControl.TextWrapPos = 500
end

---Adds a tooltip to the target with a title and text.
---@param target ExtuiStyledRenderable
---@param title string The title of the tooltip
---@param text string The text of the tooltip
function AddTooltipTitled(target, title, text)
    AddTooltip(target, title .. "\n\n" .. text)
end

---Adds a tooltip to the target with the given text.
---@param target ExtuiStyledRenderable
---@param textId string The id of the text in the localization system to lookup.
function AddLocaTooltip(target, textId)
    local text = Ext.Loca.GetTranslatedString(textId)
    AddTooltip(target, TidyDescription(text))
end

---Adds a tooltip to the target with a title and text.
---@param target ExtuiStyledRenderable
---@param titleId string The title of the tooltip
---@param textId string The text of the tooltip
function AddLocaTooltipTitled(target, titleId, textId)
    local title = Ext.Loca.GetTranslatedString(titleId)
    local text = Ext.Loca.GetTranslatedString(textId)
    AddTooltipTitled(target, TidyDescription(title), TidyDescription(text))
end

---Creates a table that facilitates centering an object through brute force.
---@param parent ExtuiTreeParent The container to add the table to
---@param uniqueName string A unique name for the table and columns.
---@param tableWidth number The width the table should be.
function CreateCenteredControlCell(parent, uniqueName, tableWidth)
    local columnCount = 3
    local halfColumnCount = (columnCount - 1) / 2
    local table = parent:AddTable(uniqueName, columnCount)
    table.ItemWidth = tableWidth
    for i = 1, halfColumnCount do
        table:AddColumn(uniqueName .. "_" .. tostring(i), Ext.Enums.GuiTableColumnFlags.WidthStretch)
    end
    table:AddColumn(uniqueName .. "_center", Ext.Enums.GuiTableColumnFlags.WidthFixed)
    for i = halfColumnCount + 2, columnCount do
        table:AddColumn(uniqueName .. "_" .. tostring(i), Ext.Enums.GuiTableColumnFlags.WidthStretch)
    end
    local row = table:AddRow()
    for i = 1, halfColumnCount do
        row:AddCell()
    end
    local centerCell = row:AddCell()
    for i = halfColumnCount + 2, columnCount do
        row:AddCell()
    end
    return centerCell
end

---Creates a centered title control for the given parent container.
---@param parent ExtuiTreeParent
---@param titleId string The id of the title in the localization system to lookup.
---@return ExtuiText The cell that contains the title.
function AddLocaTitle(parent, titleId)
    local title = Ext.Loca.GetTranslatedString(titleId)
    local centeredCell = CreateCenteredControlCell(parent, titleId .. "_Title", parent.Size[1] - 60)
    return centeredCell:AddText(title)
end

---Enables the control when all resources are allocated, disables when any are not.
---@param control ExtuiStyledRenderable
---@param sharedResources SharedResource[]
local function EnableOnAllResourcesAllocated(control, sharedResources)
    for _, resource in pairs(sharedResources) do
        if resource.count > 0 then
            control.Enabled = false
            return
        end
    end
    control.Enabled = true;
end

---Configures the control to enable the control when all resources are allocated and disable when any are not.
---@param control ExtuiStyledRenderable
---@param sharedResources SharedResource[]
function ConfigureEnableOnAllResourcesAllocated(control, sharedResources)
    for _, resource in pairs(sharedResources) do
        resource:add(function(_, _)
            EnableOnAllResourcesAllocated(control, sharedResources)
        end)
    end
    -- Call it at the outset to set the initial state.
    EnableOnAllResourcesAllocated(control, sharedResources)
end

local checkBoxColors = {Border = NormalizedRGBA(110, 91, 83, 0.76), BorderShadow = NormalizedRGBA(60, 50, 46, 0.76)}
local checkBoxBorder = {ChildBorderSize = 1.0, FrameBorderSize = 1.0}
local checkBoxBorderBland = {ChildBorderSize = 0.0, FrameBorderSize = 0.0}

---Adds a border around the target object.
---@param target ExtuiStyledRenderable The object to add a border to.
function MakeSpicy(target)
    for k, v in pairs(checkBoxColors) do
        target:SetColor(k, v)
    end
    for k, v in pairs(checkBoxBorder) do
        target:SetStyle(k, v)
    end
end

---Removes the border around the target object.
---@param target ExtuiStyledRenderable The object to add a border to.
function MakeBland(target)
    for k, v in pairs(checkBoxBorderBland) do
        target:SetStyle(k, v)
    end
end

---Adds a checkbox to the parent with a spicy border.
---@param parent ExtuiTreeParent The parent to add the checkbox to.
---@return ExtuiCheckbox The checkbox that was added.
function SpicyCheckbox(parent)
    local checkbox = parent:AddCheckbox("")
    MakeSpicy(checkbox)
    return checkbox
end

local minIconsPerRow = 7
local maxIconsPerRow = 9

---Try to determine a decent arrangement of icons per row, so that it looks boxy.
---@param iconCount number The total number of icons to place
---@return number The number of icons to place per row.
function ComputeIconsPerRow(iconCount)
    if iconCount <= maxIconsPerRow then
        return iconCount
    end
    local minRowCount = minIconsPerRow
    local minLost = minIconsPerRow - math.fmod(iconCount, minIconsPerRow)
    for i = minIconsPerRow, maxIconsPerRow - 1 do
        local modValue = math.fmod(iconCount, i)
        if modValue == 0 then
            return i
        end
        local lost = i - modValue
        if lost < minLost then
            minLost = lost
            minRowCount = i
        end
    end
    return minRowCount
end
