
---@type ExtuiWindow?
local featUI = nil
---@type ExtuiWindow?
local featDetailUI = nil
---@type number
local uiPendingCount = 0
---The number of ticks to wait before checking the UI focus.
---@type number
local uiPendingTickCount = 2


---The details panel for the feat.
---@param feat table The feat to create the window for.
---@param playerInfo table The player id for the feat.
local function ShowFeatDetailSelectUI(feat, playerInfo)
    local windowDimensions = {1000, 1450}
    if not featDetailUI then
        local featDetails = Ext.Loca.GetTranslatedString("h43800b7agdc92g46b6g82dcg22fb987efe6c") -- Feat Details
        featDetailUI = Ext.IMGUI.NewWindow(featDetails)
        featDetailUI.Closeable = true
        featDetailUI.NoMove = true
        featDetailUI.NoResize = true
        featDetailUI.NoCollapse = true
        featDetailUI:SetSize(windowDimensions)
        featDetailUI:SetPos({1400, 100})
    end

    featDetailUI.Visible = true
    featDetailUI.Open = true
    featDetailUI:SetFocus()
    uiPendingCount = uiPendingTickCount

    ClearChildren(featDetailUI)

    local childWin = featDetailUI:AddChildWindow("Selection")
    childWin.Size = {windowDimensions[1] - 30, windowDimensions[2] - 130}
    childWin.PositionOffset = {0, 0}
    childWin.NoTitleBar = true
    local description = childWin:AddText(TidyDescription(feat.Description))
    description.ItemWidth = windowDimensions[1] - 60
    pcall(function()
        -- This isn't in the standard bg3se yet. I have a PR for it at: https://github.com/Norbyte/bg3se/pull/431
        description.TextWrapPos = windowDimensions[1] - 60
    end)

    local extraPassives = {}
    local abilityResources = {}
    local skillStates = {}
    local selectedPassives = {}
    local abilityInfo = GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    AddFeaturesToFeatDetailsUI(childWin, feat, extraPassives)
    local sharedResources = AddAbilitySelectorToFeatDetailsUI(childWin, abilityInfo, abilityResources)
    local skillSharedResources = AddSkillSelectorToFeatDetailsUI(childWin, feat, playerInfo, abilityResources, skillStates)
    local passiveSharedResources = AddPassiveSelectorToFeatDetailsUI(childWin, feat, playerInfo, selectedPassives)

    for _, resource in ipairs(skillSharedResources) do
        table.insert(sharedResources, resource)
    end
    for _, resource in ipairs(passiveSharedResources) do
        table.insert(sharedResources, resource)
    end

    local centerCell = CreateCenteredControlCell(featDetailUI, "Select", windowDimensions[1] - 30)
    local select = centerCell:AddButton(Ext.Loca.GetTranslatedString("h04f38549g65b8g4b72g834eg87ee8863fdc5")) -- Select

    select:SetStyle("ButtonTextAlign", 0.5, 0.5)

    select.OnClick = function()
        featUI.Visible = false
        featUI.Open = false
        featDetailUI.Visible = false
        featDetailUI.Open = false

        -- Gather the selected abilities and any boosts from passives
        local boosts = {}
        for _, passive in ipairs(extraPassives) do
            table.insert(boosts, passive.Boost)
        end
        for _, abilitySelector in ipairs(abilityInfo) do
            for _, ability in ipairs(abilitySelector.State) do
                if ability.Current > ability.Initial then
                    local boost = "Ability(" .. ability.Name .. "," .. tostring(ability.Current - ability.Initial) .. ")"
                    table.insert(boosts, boost)
                end
            end
        end

        for skillName, skillState in pairs(skillStates) do
            if skillState.Proficient then
                table.insert(boosts, "ProficiencyBonus(Skill," .. skillName .. ")")
            end
            if skillState.Expertise then
                table.insert(boosts, "ExpertiseBonus(" .. skillName .. ")")
            end
        end

        local payload = {
            PlayerId = playerInfo.ID,
            Feat = {
                FeatId = feat.ID,
                PassivesAdded = feat.PassivesAdded,
                Boosts = boosts
            }
        }
        local payloadStr = Ext.Json.Stringify(payload)
        Ext.Net.PostMessageToServer(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, payloadStr)
    end

    ConfigureEnableOnAllResourcesAllocated(select, sharedResources)
end

---Creates a button in the feat selection window for the feat.
---@param win ExtuiWindow The window to close on completion.
---@param buttonWidth number The width of the button.
---@param playerInfo table The player id for the feat.
---@param feat table The feat to create the button for.
---@return ExtuiButton The button created.
local function MakeFeatButton(win, buttonWidth, playerInfo, feat)
    local featButton = win:AddButton(feat.DisplayName)
    featButton.Size = {buttonWidth-30, 48}
    featButton:SetStyle("ButtonTextAlign", 0.5, 0.5)
    AddTooltip(featButton, TidyDescription(feat.Description))
    featButton.OnClick = function()
        ShowFeatDetailSelectUI(feat, playerInfo)
    end
    return featButton
end

---Shows the Feat Selector UI
---@param message table
function E6_FeatSelectorUI(message)
    local windowDimensions = {500, 1450}

    if featUI == nil then
        local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8") -- Feats
        featUI = Ext.IMGUI.NewWindow(featTitle)
        featUI.Closeable = true
        featUI.NoMove = true
        featUI.NoResize = true
        featUI.NoCollapse = true
        featUI:SetSize(windowDimensions)
        featUI:SetPos({800, 100})
        featUI.OnClose = function()
            if featDetailUI then
                featDetailUI.Visible = false
                featDetailUI.Open = false
            end
        end
    end

    featUI.Visible = true
    featUI.Open = true
    featUI:SetFocus()
    uiPendingCount = uiPendingTickCount

    ClearChildren(featUI)

    local allFeats = E6_GatherFeats()

    local featList = {}
    local featMap = {}
    for _,featId in ipairs(message.SelectableFeats) do
        local feat = allFeats[featId]
        local featName = feat.DisplayName
        featMap[featName] = feat
        table.insert(featList, featName)
    end

    message.FeatMap = featMap

    table.sort(featList, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    for _, featName in ipairs(featList) do
        local feat = featMap[featName]
        if feat == nil then
            _E6Error("Failed to find feat for name: " .. featName)
        else
            MakeFeatButton(featUI, windowDimensions[1], { ID = message.PlayerId, Name = message.PlayerName, Abilities = message.Abilities, PlayerPassives = message.PlayerPassives, Proficiencies = message.Proficiencies, ProficiencyBonus = message.ProficiencyBonus }, feat)
        end
    end

end

---Checks the feat windows to determine if they have lost focus, in which case, close them.
local function E6_CheckUIFocus(tickParams)
    if true then
        return -- skipping it all for now
    end

    -- There is a tick timing event between creating the window, and drawing the window with focus.
    if uiPendingCount > 0 then
        uiPendingCount = uiPendingCount - 1
        return
    end

    local isOpen = false
    local queue = Dequeue:new()
    if featUI then
        queue:pushright(featUI)
        isOpen = featUI.Open
    end
    if featDetailUI then
        queue:pushright(featDetailUI)
        isOpen = isOpen or featDetailUI.Open
    end
    if not isOpen then
        return
    end

    while queue:count() > 0 do
        local ui = queue:popleft()
        if ui then
            if ui.Focus then
                return
            end
            pcall(function ()
                if ui.Children then
                    for _,child in ipairs(ui.Children) do
                        if child then
                            queue:pushright(child)
                        end
                    end
                end
            end)
        end
    end

    if featUI then
        featUI.Visible = false
        featUI.Open = false
    end
    if featDetailUI then
        featDetailUI.Visible = false
        featDetailUI.Open = false
    end
end

---Checking every tick seems less than optimal, but checking focus is proving a little 
---more involved to operate reliably by callbacks.
Ext.Events.Tick:Subscribe(E6_CheckUIFocus)
