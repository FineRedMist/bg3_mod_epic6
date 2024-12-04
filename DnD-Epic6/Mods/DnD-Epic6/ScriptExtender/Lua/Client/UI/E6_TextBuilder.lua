--- @class TextBuilder A resource shared between multiple options to determine when the resource still has pending choices or is completely consumed.
--- @field parent ExtuiTreeParent The parent ui element to add text (and other ui controls) to.
--- @field width? number The width of the text field (in 3840x2160 resolution). If not set, the text will be as wide as the parent. If less than zero, strings will be split.
--- @field preText function[]? Functions to call on the text itself before the text ui element is created with it.
--- @field onText function? A function to call whenever creating a text field for subsequent modification.
--- Handles the creation of text elements in the UI to support wrapping, inline images, etc.
TextBuilder = {}
TextBuilder.preText = nil
TextBuilder.__index = TextBuilder

--- Creates a new SharedResource instance.
--- @param parent ExtuiTreeParent The parent ui element to add text (and other ui controls) to.
--- @param width? number The width of the text field (in 3840x2160 resolution). If not set, the text will be as wide as the parent. If less than zero, strings will be split.
--- @param onText function? A function to call whenever creating a text field for subsequent modification.
--- @return TextBuilder
function TextBuilder:new(parent, width, onText)
    local res = setmetatable({}, self)
    res.parent = parent
    res.onText = onText
    res.width = width
    return res
end

---Whether to rely on the parent to wrap, so break up text blocks into parts.
function TextBuilder:UseParentWrapping()
    return self.width and self.width < 0
end

---Whether to rely on the parent to wrap, so break up text blocks into parts.
function TextBuilder:UseTextWrapping()
    return self.width and self.width > 0
end

---Runs the pre-text functions on the text.
---@param text string
---@return string
function TextBuilder:RunPreText(text)
    text = tostring(text)
    if self.preText then
        for _,pre in ipairs(self.preText) do
            text = pre(text)
        end
    end
    return text
end

---Takes an array of stringifiable objects and splits them into individual strings based on whitespace.
---@param textParts any[] Stringifiable objects to split.
---@return string[] The split strings.
function TextBuilder:SplitFlattenText(textParts)
    for i = #textParts,1,-1 do
        local myParts = SplitString(TidyDescription(textParts[i]), nil, true)
        table.remove(textParts, i)
        for j = #myParts,1,-1 do
            local part = myParts[j]
            if string.find(part, "%S") or string.find(part, "\n") then
                table.insert(textParts, i, part)
            end
        end
    end
    return textParts
end

---Adds text to the parent ui element.
---If the width is set and less than zero, the line is split into parts to hopefully wrap correctly, using SameLine = true.
---If the width is set and greater than zero, a single text control with the width and text wrap position is created.
---In both cases, each text element has the corresponding onText member called.
---@param formatter function? The formatter to use to format the text.
---@param ... any The texts to add. Note: these can be localization ids.
---@return TextBuilder The current text builder.
function TextBuilder:AddFormattedText(formatter, ...)
    local textParts = {...}
    if self:UseParentWrapping() then
        textParts = self:SplitFlattenText(textParts)
    else
        for i = 1,#textParts do
            local text = tostring(textParts[i])
            local loc = Ext.Loca.GetTranslatedString(text)
            if loc and string.len(loc) > 0 then
                text = loc
            end
            textParts[i] = text
        end
    end
    for _,part in ipairs(textParts) do
        if self:UseParentWrapping() and string.find(part, "\n") then
            self.parent:AddSpacing()
            self.parent:AddSpacing()
        else
            local textElement = self.parent:AddText(TidyDescription(part))
            if formatter then
                formatter(textElement)
            end
            if self:UseTextWrapping() then
                textElement.ItemWidth = ScaleToViewportWidth(self.width)
                textElement.TextWrapPos = textElement.ItemWidth
            elseif self:UseParentWrapping() then
                textElement.SameLine = true
            end
            if self.onText then
                self.onText(textElement)
            end
        end
    end

    return self
end
---Adds text to the parent ui element.
---If the width is set and less than zero, the line is split into parts to hopefully wrap correctly, using SameLine = true.
---If the width is set and greater than zero, a single text control with the width and text wrap position is created.
---In both cases, each text element has the corresponding onText member called.
---@param ... any The texts to add. Note: these can be localization ids.
---@return TextBuilder The current text builder.
function TextBuilder:AddText(...)
    return self:AddFormattedText(nil, ...)
end

---Adds a spacing element to the parent ui element.
---@return TextBuilder The current text builder.
function TextBuilder:AddSpacing()
    self.parent:AddSpacing()
    return self
end

---Adds text corresponding to the localization id to the parent ui element.
---If the width is set and less than zero, the line is split into parts to hopefully wrap correctly, using SameLine = true.
---If the width is set and greater than zero, a single text control with the width and text wrap position is created.
---In both cases, each text element has the corresponding onText member called.
---@param textId string The localization id of the text to add.
---@param textArgs string[]? The arguments to pass to the localization.
---@return TextBuilder The current text builder.
function TextBuilder:AddFormattedLoca(formatter, textId, textArgs)
    local newArgs = DeepCopy(textArgs)
    if newArgs == nil then
        newArgs = {}
    end
    for i,arg in ipairs(newArgs) do
        newArgs[i] = self:RunPreText(arg)
    end
    if self:UseParentWrapping() then
        ProcessParameterizedLoca(textId, newArgs, function(text)
            self:AddFormattedText(formatter, text)
        end)
    else
        local result = ""
        local function GatherText(text)
            result = result .. text
        end
        ProcessParameterizedLoca(textId, newArgs, GatherText)
        self:AddFormattedText(formatter, result)
    end
    return self
end
---Adds text corresponding to the localization id to the parent ui element.
---If the width is set and less than zero, the line is split into parts to hopefully wrap correctly, using SameLine = true.
---If the width is set and greater than zero, a single text control with the width and text wrap position is created.
---In both cases, each text element has the corresponding onText member called.
---@param textId string The localization id of the text to add.
---@param textArgs string[]? The arguments to pass to the localization.
---@return TextBuilder The current text builder.
function TextBuilder:AddLoca(textId, textArgs)
    return self:AddFormattedLoca(nil, textId, textArgs)
end

---Creates an image element for the parent ui element.
---If the width is set and less than zero, the image is placed with SameLine set to true.
---@param imageName string The name of the image.
---@param size integer[] The size the image should be.
---@return TextBuilder The current text builder.
---@return ExtuiImage The image element created.
function TextBuilder:addImage(imageName, size)
    local imageElement = self.parent:AddImage(imageName, size)
    if self:UseParentWrapping() then
        imageElement.SameLine = true
    end
    return self, imageElement
end

return TextBuilder
