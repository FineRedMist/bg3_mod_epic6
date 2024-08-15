---Adds a tooltip to the target with the given text.
---@param target ExtuiStyledRenderable
---@param text string The text of the tooltip
function AddTooltip(target, text)
    local tooltip = target:Tooltip()
    tooltip.IDContext = target.IDContext .. "_TOOLTIP"
    local textControl = tooltip:AddText(text)
    textControl.ItemWidth = 400
    textControl.TextWrapPos = 400
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