
---@type integer The width of the tooltip to use in 3840x2160 units.
local tooltipWidth = 900

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

---The UI is scaled based on 3840x2160, so we need to scale the UI to the current viewport.
local viewportWidth = Ext.IMGUI.GetViewportSize()[1]
local viewportHeight = Ext.IMGUI.GetViewportSize()[2]

---Scale from 3840 width to the current viewport width.
---@param width integer The source control width to scale.
---@return integer The scaled width to render with.
function ScaleToViewportWidth(width)
    return (width * viewportWidth) // 3840
end

---Scale from 2160 height to the current viewport height.
---@param height integer The source control height to scale.
---@return integer The scaled height to render with.
function ScaleToViewportHeight(height)
    return (height * viewportHeight) // 2160
end

---Scale from 3840x2160 to the current viewport dimensions.
---@param dimensions integer[] The source control dimensions to scale.
---@return integer The scaled dimensions to render with.
function ScaleToViewport(dimensions)
    return { ScaleToViewportWidth(dimensions[1]), ScaleToViewportHeight(dimensions[2]) }
end

---The default icon size to use for UI elements at 3840x2160.
DefaultIconSize = ScaleToViewport({48, 48})

---Scale from viewport width to the 3840 width for doing adjustments.
---@param width integer The source control width to scale.
---@return integer The scaled width to computed size.
function ScaleFromViewportWidth(width)
    return (width * 3840) // viewportWidth
end

---Scale from viewport height to the 2160 height for doing adjustments.
---@param height integer The source control height to scale.
---@return integer The scaled height to computed size.
function ScaleFromViewportHeight(height)
    return (height * 2160) // viewportHeight
end

---Sets the size of the control to the width and height based on 3840x2160.
---@param control ExtuiTable|ExtuiButton|ExtuiChildWindow|ExtuiImageReference|ExtuiProgressBar The control to set the size of.
---@param width integer The width based on 3840x2160.
---@param Height integer The height based on 3840x2160.
function SetSizeToViewport(control, width, Height)
    control.Size = { ScaleToViewportWidth(width), ScaleToViewportHeight(Height) }
end

---Retrieves the size from the control and scales it to 3840x2160.
---@param control ExtuiTable|ExtuiButton|ExtuiChildWindow|ExtuiImageReference|ExtuiProgressBar The control to get the size of.
---@return integer[] The scaled size based on 3840x2160.
function GetSizeFromViewport(control)
    return { ScaleFromViewportWidth(control.Size[1]), ScaleFromViewportHeight(control.Size[2]) }
end

---Uses a couple of different methods to get the width of the control, which could be based on the Size or ItemWidth.
---@param control ExtuiRenderable The control to get the width of.
---@return integer The width of the control based on 3840x2160.
function GetWidthFromViewport(control)
    local success, result = pcall(function()
        if control.Size then
            return ScaleFromViewportWidth(control.Size[1])
        end
    end)
    if success then
       return result
    end
    return ScaleFromViewportWidth(control.ItemWidth)
end

---Retrieves the size from the control and scales it to 3840x2160.
---@param control ExtuiTable|ExtuiButton|ExtuiChildWindow|ExtuiImageReference|ExtuiProgressBar The control to get the size of.
---@return integer The height scaled to 3840x2160.
function GetHeightFromViewport(control)
    return ScaleFromViewportHeight(control.Size[2])
end

--- The amount to modify alpha when enabling or disabling a control.
local alphaFactor = 4

---Enables a UI element
---@param control ExtuiStyledRenderable The control to enable.
function UI_Enable(control)
    if not control.Disabled then
       return
    end
    control.Disabled = false
    local curAlpha = control:GetStyle("Alpha")
    if not curAlpha then
        curAlpha = 1/alphaFactor
    end
    control:SetStyle("Alpha",  curAlpha * alphaFactor)
end

---Disables a UI element
---@param control ExtuiStyledRenderable The control to disable.
function UI_Disable(control)
    if control.Disabled then
        return
     end
     control.Disabled = true
     local curAlpha = control:GetStyle("Alpha")
     if not curAlpha then
        curAlpha = 1
    end
     control:SetStyle("Alpha",  curAlpha / alphaFactor)
 end

---Sets whether the control is enabled or disabled based on isEnabled.
---@param control ExtuiStyledRenderable The control to enable or disable.
---@param isEnabled boolean Whether the control should be enabled or disabled.
function UI_SetEnable(control, isEnabled)
    if isEnabled then
        UI_Enable(control)
    else
        UI_Disable(control)
    end
end

---Adds a tooltip to the target with the given text.
---@param target ExtuiStyledRenderable
---@return TextBuilder The builder for the tooltip that was added.
function AddTooltip(target)
    local tooltip = target:Tooltip()
    tooltip.IDContext = target.IDContext .. "_TOOLTIP"
    ClearChildren(tooltip)
    return TextBuilder:new(tooltip, ScaleToViewportWidth(tooltipWidth))
end

---Creates a table that facilitates centering an object through brute force.
---@param parent ExtuiTreeParent The container to add the table to
---@param uniqueName string A unique name for the table and columns.
---@param tableWidth number The width the table should be.
function CreateCenteredControlCell(parent, uniqueName, tableWidth)
    local columnCount = 3
    local halfColumnCount = (columnCount - 1) / 2
    local table = parent:AddTable(uniqueName, columnCount)
    table.ItemWidth = ScaleToViewportWidth(tableWidth)
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
    local centeredCell = CreateCenteredControlCell(parent, titleId .. "_Title", GetWidthFromViewport(parent) - 60)
    return centeredCell:AddText(title)
end

---Enables the control when all resources are allocated, disables when any are not.
---@param control ExtuiStyledRenderable
---@param sharedResources SharedResource[]
local function EnableOnAllResourcesAllocated(control, sharedResources)
    for _, resource in pairs(sharedResources) do
        if resource.count > 0 then
            UI_Disable(control)
            return
        end
    end
    UI_Enable(control)
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

local WhiteColor = NormalizedRGBA(255, 255, 255, 0.76)
local DunRedColor = NormalizedRGBA(198, 56, 74, 0.76)
local DunYellowColor = NormalizedRGBA(198, 170, 20, 0.76)
local checkBoxColors = {Border = NormalizedRGBA(110, 91, 83, 0.76), BorderShadow = NormalizedRGBA(60, 50, 46, 0.76)}
local selectedColors = {Border = NormalizedRGBA(255, 215, 0, 0.76), BorderShadow = NormalizedRGBA(192, 159, 106, 0.76)}
local checkBoxBorder = {ChildBorderSize = 1.0, FrameBorderSize = 1.0}
local checkBoxBorderBland = {ChildBorderSize = 0.0, FrameBorderSize = 0.0}

---Sets the text color of the target object.
---@param target ExtuiStyledRenderable The object with text to change the color of.
---@param color table<number> The color to set the text to.
function SetTextColor(target, color)
    target:SetColor('Text', color)
end

---Sets the text color to white for the control.
---@param target ExtuiStyledRenderable The object with text to make white.
function SetWhiteText(target)
    SetTextColor(target, WhiteColor)
end

---Sets the text color to red to indicate an error
---@param target ExtuiStyledRenderable The object with text to make red.
function MakeErrorText(target)
    SetTextColor(target, DunRedColor)
end

---Sets the text color to red to indicate an error
---@param target ExtuiStyledRenderable The object with text to make red.
function MakeWarningText(target)
    SetTextColor(target, DunYellowColor)
end

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

---Adds a selected border around the target object.
---@param target ExtuiStyledRenderable The object to add a border to.
function MakeSelected(target)
    for k, v in pairs(selectedColors) do
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
---@param text string? The text to display next to the checkbox.
---@return ExtuiCheckbox The checkbox that was added.
function SpicyCheckbox(parent, text)
    if text == nil then
        text = ""
    end
    local checkbox = parent:AddCheckbox(text)
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

---
---@param tooltip TextBuilder The tooltip to add the messages to
---@param messages FeatMessageType[] The set of messages to add
---@param tooltipTransform function transform to apply for the the control added for the messages
function AddTooltipMessageDetails(tooltip, messages, tooltipTransform)
    if not messages or not next(messages) then
        return
    end

    tooltip:AddSpacing()
    tooltip:AddSpacing()
    local lastTextWasBullet = false -- Hack to do the SameLine on the next text element after the bullet.
    tooltip.onText = function(textElement)
            tooltipTransform(textElement)
            if textElement.Label == " - " then
                lastTextWasBullet = true
            elseif lastTextWasBullet then
                textElement.SameLine = true
                lastTextWasBullet = false
            end
        end
    tooltip:AddText("hc3a8865ageffcg4d60gabd8gccd4f828d6e9") -- Requirements:
    for _, message in ipairs(messages) do
        tooltip:AddText(" - "):AddLoca(message.MessageLoca, message.Args)
    end
end
