
---@type ExtuiWindow?
local featUI = nil
---@type ExtuiWindow?
local featDetailUI = nil
---@type number
local uiPendingCount = 0
---The number of ticks to wait before checking the UI focus.
---@type number
local uiPendingTickCount = 2

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

local abilityPassives = {
    Strength = {
        ShortName = "h1579d774gdbcdg4a97gb3fage409138d104d",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_1",
        Description = "haaf3959ag320eg4f68ga9c9gc143d7f64a8c",
        Icon = "E6_Ability_Strength" },
    Dexterity = {
        ShortName = "h8d7356d7g4c37g41e4gb8a2gef3459e12b97",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_2",
        Description = "hbf128ebdgdfffg4ea9gbf4bg1659ccefd287",
        Icon = "E6_Ability_Dexterity" },
    Constitution = {
        ShortName = "h20676a9ag9216g47dbgba3ag82bd734cfd53",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_3",
        Description = "h7a02f64dg4593g408fgbf93gb0dbabc182c9",
        Icon = "E6_Ability_Constitution" },
    Intelligence = {
        ShortName = "ha1a41e74g2804g4a70g9a85g6235163d41da",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_4",
        Description = "h411a732ag4b4cg4094g9a5egd325fecf4645",
        Icon = "E6_Ability_Intelligence" },
    Wisdom = {
        ShortName = "h2e9f1067g2dceg4640g8816gc6394e9f0303",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_5",
        Description = "h35233e68gf68ag461cgac5fgc15806be3dc7",
        Icon = "E6_Ability_Wisdom" },
    Charisma = {
        ShortName = "ha2fc9b3dg3305g404eg9256gf25a06d0b2aa",
        DisplayName = "h6c83537fg6358g41e0g8a18g32cc8316ced2_6",
        Description = "h441085efge3a5g4004gba8dgf2378e8986c8",
        Icon = "E6_Ability_Charisma" }
}

local skillLoca = {
    Athletics = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_12", Description = "ha90cb8b6g3aa7g4b94ga7e3gfa0823672af1" },
    Acrobatics = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_4", Description = "h241bfb0fgffa2g4ccega96fgb26da384ecf8" },
    SleightOfHand = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_5", Description = "ha18e79b2g111ag441egb532g3ff79d4ba842" },
    Stealth = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_6", Description = "hb2487d1bga7a8g4a2dgb6a8g447842179f6d" },
    Arcana = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_7", Description = "hda75bbd8g5613g4f40g8b8dgb8d3f4f6855d" },
    History = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_8", Description = "ha31089eegb95fg44d8gb191g302341c0b57a" },
    Investigation = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_9", Description = "h2a7019efgfaf7g455fg8fd9g4b7c275fbbfa" },
    Nature = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_10", Description = "h94f2954eg8a71g49c9ga9bdg66b65a04a23c" },
    Religion = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_11", Description = "h3adc18e5gc8c3g459dgbe82gb27aca09da54" },
    AnimalHandling = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_13", Description = "hfa186a8cg869cg4ecdgadf3gb7326ab444c4" },
    Insight = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_14", Description = "h2eb576b5gc088g40e6gad9ag52751e1f9be7" },
    Medicine = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_15", Description = "h0eb7380bg4477g4d04ga797ge577e24aa856" },
    Perception = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_16", Description = "h7896bd12g83b9g4058gbc2cg477ba13c728a" },
    Survival = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_17", Description = "had65a34cg53b1g4d6ag86d2g04258e4ed338" },
    Deception = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_0", Description = "h5febcaf6g13f4g4662g9c68ge24ec3c2d80a" },
    Intimidation = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_1", Description = "h5e849499g23bfg4e5dga9f3gb6ce36f9abc2" },
    Performance = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_2", Description = "ha6c0ffb0g73ccg4435g9d7ag8a24ee90a849" },
    Persuasion = { DisplayName = "h65e11968gf9b6g4c47g9efcg03fb60fb923c_3", Description = "h3d5ecb16g20f8g4febgba03g41ae11b9ddf2" },
}

local abilitySkillMap = {
    Strength = { "Athletics" },
    Dexterity = { "Acrobatics", "SleightOfHand", "Stealth" },
    Intelligence = { "Arcana", "History", "Investigation", "Nature", "Religion" },
    Constitution = {},
    Wisdom = { "AnimalHandling", "Insight", "Medicine", "Perception", "Survival" },
    Charisma = { "Deception", "Intimidation", "Performance", "Persuasion" }
}
---Adds the list of passives to the cell.
---@param cell ExtuiTableCell
---@param feat table
---@param extraPassives table Passives to add to the passives list for when there is only one ability to select. 
local function AddPassivesToCell(cell, feat, extraPassives)
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
local function AddPassivesToFeatDetailsUI(parent, feat, extraPassives)
    if #feat.PassivesAdded > 0 then
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()
        AddLocaTitle(parent, "hffc72a17g6934g42f8ga935g447764ee6f43")
        local passivesCell = CreateCenteredControlCell(parent, "Passives", parent.Size[1] - 60)
        AddPassivesToCell(passivesCell, feat, extraPassives)
    end
end

---Creates a control for manipulating the ability scores
---@param parent ExtuiTreeParent
---@param sharedResource SharedResource
---@param pointInfo table
---@param state table
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
---@return table?
local function AddAbilityControl(parent, sharedResource, pointInfo, state, abilityResources)
    local abilityName = state.Name
    local id = pointInfo.ID
    local maxPoints = pointInfo.Max

    local win = parent:AddChildWindow(abilityName .. id .. "_Window")
    win.Size = {100, 180}
    win.SameLine = true
    local passiveInfo = abilityPassives[abilityName]
    AddLocaTooltipTitled(win, passiveInfo.DisplayName, passiveInfo.Description)
    AddLocaTitle(win, abilityPassives[abilityName].ShortName)

    local addButtonCell = CreateCenteredControlCell(win, abilityName .. id .. "_+", win.Size[1] - 40)
    local addButton = addButtonCell:AddImageButton("", "ico_plus_h")

    local currentScoreCell = CreateCenteredControlCell(win, abilityName .. id .. "_Current", win.Size[1] - 40)
    local currentScore = currentScoreCell:AddText(tostring(state.Current))

    local minButtonCell = CreateCenteredControlCell(win, abilityName .. id .. "_-", win.Size[1] - 40)
    local minButton = minButtonCell:AddImageButton("", "ico_min_h")

    local updateButtons = function()
        addButton.Enabled = sharedResource.count > 0 and state.Current < state.Maximum and state.Current - state.Initial < maxPoints
        minButton.Enabled = state.Current > state.Initial and sharedResource.count < sharedResource.capacity
    end

    -- In case there is more than one selection that is possible for an ability (haven't found any yet, but paranoid).
    -- Might be worthwhile to create some test feats to validate this.
    local abilityResource = nil
    if abilityResources[abilityName] then
        abilityResource = abilityResources[abilityName]
    else
        abilityResource = SharedResource:new(state.Current, 100)
        abilityResources[abilityName] = abilityResource
    end

    addButton.OnClick = function()
        if sharedResource:AcquireResource() then
            state.Current = state.Current + 1
            abilityResource:ReleaseResource()
        end
        updateButtons()
    end

    minButton.OnClick = function()
        if sharedResource:ReleaseResource() then
            state.Current = state.Current - 1
            abilityResource:AcquireResource()
        end
        updateButtons()
    end

    abilityResource:add(function(_, _)
        currentScore.Label = tostring(abilityResource.count)
    end)

    sharedResource:add(function(_, _)
        updateButtons()
    end)
end

---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param abilityInfo table The ability information to render
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
local function AddAbilitySelectorToFeatDetailsUI(parent, abilityInfo, abilityResources)
    local resources = {}
    for _,abilityListSelector in ipairs(abilityInfo) do
        parent:AddSpacing()
        parent:AddSeparator()
        parent:AddSpacing()

        local pointCount = SharedResource:new(abilityListSelector.PointCount)
        table.insert(resources, pointCount)
        local pointText = AddLocaTitle(parent, "h8cb5f019g91b8g4873ga7c4g2c79d5579a78")

        pointCount:add(function(_, _)
            local text = Ext.Loca.GetTranslatedString("h8cb5f019g91b8g4873ga7c4g2c79d5579a78")
            text = SubstituteParameters(text, { Count = pointCount.count, Max = abilityListSelector.PointCount })
            pointText.Label = text
        end)
        local abilitiesCell = CreateCenteredControlCell(parent, abilityListSelector.ID, parent.Size[1] - 60)

        for _,ability in ipairs(abilityListSelector.State) do -- TODO: Will likely get renamed in the future
            AddAbilityControl(abilitiesCell, pointCount, abilityListSelector, ability, abilityResources)
        end

        pointCount:trigger()
    end
    return resources
end

---@param feat table
---@param skillsToShow table
---@param skillColumns table
---@param skillsFromFeat table
---@param expertise boolean
local function GatherSkillsToShow(feat, skillsToShow, skillColumns, skillsFromFeat, expertise)
    for _, skill in ipairs(skillsFromFeat) do
        --_E6P("Skill ID (" .. feat.ShortName .. "): " .. skill.SourceId)
        local skillList = Ext.StaticData.Get(skill.SourceId, Ext.Enums.ExtResourceManagerType.SkillList)
        local skillGroup = {}
        if skillList then
            for _,skillEnum in ipairs(skillList.Skills) do
                local skillName = skillEnum.Label
                --_E6P("--Skill Name: " .. skillName)
                table.insert(skillGroup, skillName)
                skillsToShow[skillName] = true
            end
            table.insert(skillColumns, {Points = skill.Count, Info = skill, IsExpertise = expertise, Group = skillGroup, Resource = SharedResource:new(skill.Count)})
        end
    end
end

local imageLookup = {
    Proficient = {ImageName = "E6_Proficient", Title = "h5cab4ab6g7b46g46cegb82fg3ea721099318", Description = "hda608d66g306eg4739g8ea2g974918945bb8"},
    Expertise = {ImageName = "E6_Expertise", Title = "h601ff4c6g67b8g4f32gaaf7g8b29d6daa426", Description = "hb7bf72ebgcd1ag40fbg9f1eg85d9a5853d4d"}
}
---Adds the given image by name to the parent container.
---@param parent ExtuiTreeParent The parent to add the image to.
---@param name string The name of the image in the lookup table that has the tooltip information as well.
---@param size table[2]? The size of the image to render. Optional. Defaults to {48, 48}.
local function AddSkillImage(parent, name, size)
    local imageInfo = imageLookup[name]
    local image = parent:AddImage(imageInfo.ImageName, size or {48, 48})
    AddLocaTooltipTitled(image, imageInfo.Title, imageInfo.Description)
end

local function AddProficiencyImage(parent, isProficient, isExpert)
    if isExpert then
        AddSkillImage(parent, "Expertise")
    elseif isProficient then
        AddSkillImage(parent, "Proficient")
    end
end

local checkBoxColors = {Border = NormalizedRGBA(110, 91, 83, 0.76), BorderShadow = NormalizedRGBA(60, 50, 46, 0.76)}
local checkBoxBorder = {ChildBorderSize = 1.0, FrameBorderSize = 1.0}
local function SpicyCheckbox(parent)
    local checkbox = parent:AddCheckbox("")
    for k, v in pairs(checkBoxColors) do
        checkbox:SetColor(k, v)
    end
    for k, v in pairs(checkBoxBorder) do
        checkbox:SetStyle(k, v)
    end
    return checkbox
end


---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param feat table
---@param playerInfo table The ability information to render
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
---@param skillStates table<string, table> The skill states to update when the feat is committed.
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
local function AddSkillSelectorToFeatDetailsUI(parent, feat, playerInfo, abilityResources, skillStates)
    if #feat.SelectSkills == 0 and #feat.SelectSkillsExpertise == 0 then
        return {}
    end

    local resources = {}

    local skillsToShow = {}
    local skillColumns = {}
    GatherSkillsToShow(feat, skillsToShow, skillColumns, feat.SelectSkills, false)
    GatherSkillsToShow(feat, skillsToShow, skillColumns, feat.SelectSkillsExpertise, true)

    for _, column in ipairs(skillColumns) do
        table.insert(resources, column.Resource)
    end

    parent:AddSpacing()
    parent:AddSeparator()
    parent:AddSpacing()

    local uniquingName = feat.ShortName .. "_Skills"
    local skillTitleCell = CreateCenteredControlCell(parent, uniquingName .. "_Title", parent.Size[1] - 60)
    skillTitleCell:AddText(Ext.Loca.GetTranslatedString("h03cd984dg2334g4bb7g86bfg0b9419b803cf")) -- Skills

    -- The layout is (with a column before and after to center):
    -- <skill proficiency icon>  <skills column> <skill check amount> <proficiency column> ... <expertise column> ...
    --                              <blank>                            <proficiency icon>  ...  <expertise icon> ...
    --                              <blank>                            <# of total points> ...  <# of total points> ...
    --  <possible image>         <skill name>     <+/- #>               <check box>        ...    <check box> ...

    -- only selectable skills are listed, grouped by ability then alphabetically
    -- If the player has proficiency/expertise, the box is checked and greyed out
    -- If not, the box is unchecked and available to be checked, unless the resource count of the column goes to zero
    -- If the player checks a proficiency box, then an expertise box, then the proficiency box becomes read only and the expertise box needs to be unchecked to reenable the proficiency box
    local columnsBeforeCheckboxes = 4
    local columnsAfterCheckboxes = 1
    local tableNameId = uniquingName .. "_Table"
    local columnCount = columnsBeforeCheckboxes + #skillColumns + columnsAfterCheckboxes
    local skillTable = parent:AddTable(tableNameId, columnCount)
    for i = 1, columnCount do
        local widthType = Ext.Enums.GuiTableColumnFlags.WidthFixed
        if i == 1 or i == columnCount then
            widthType = Ext.Enums.GuiTableColumnFlags.WidthStretch
        end
        skillTable:AddColumn(tableNameId .. "_" .. tostring(i), widthType)
    end

    -- Skill point images
    local row = skillTable:AddRow()
    for i = 1, columnsBeforeCheckboxes do
        row:AddCell()
    end
    for _, column in ipairs(skillColumns) do
        local cell = row:AddCell()
        AddProficiencyImage(cell, true, column.IsExpertise)
    end

    -- Skill point count row
    row = skillTable:AddRow()
    for i = 1, columnsBeforeCheckboxes do
        row:AddCell()
    end
    for _, column in ipairs(skillColumns) do
        local cell = row:AddCell()
        ---@type SharedResource
        local pointCount = column.Resource
        local rawText = Ext.Loca.GetTranslatedString("h0b1dd211g01a2g41d3g8b3fg0d5b4bda3712")
        local pointText = cell:AddText(rawText)
        pointCount:add(function(_, _)
            local text = SubstituteParameters(rawText, { Count = pointCount.count, Max = pointCount.capacity })
            pointText.Label = text
        end)
        pointCount:trigger()
    end

    -- Determine the order of skills to show (grouped by ability, then alphabetically)
    local sortedSkills = {}
    for _,ability in ipairs({"Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"}) do
        local abilityResource = abilityResources[ability]
        if not abilityResource then
            abilityResource = SharedResource:new(playerInfo.Abilities[ability].Current, 100)
            abilityResources[ability] = abilityResource
        end

        local abilitySkills = {}
        for _, skill in ipairs(abilitySkillMap[ability]) do
            if skillsToShow[skill] then
                table.insert(abilitySkills, {Ability = ability, Skill = skill, DisplayName = skillLoca[skill].DisplayName, Description = skillLoca[skill].Description})
            end
        end

        table.sort(abilitySkills, function(a, b)
            return string.lower(a.DisplayName) < string.lower(b.DisplayName)
        end)

        for _,skill in ipairs(abilitySkills) do
            table.insert(sortedSkills, skill)
        end
    end

    -- now add a row for each skill
    for _,skill in ipairs(sortedSkills) do
        local row = skillTable:AddRow()
        local skillName = skill.Skill

        -- First column is a centering column
        row:AddCell()

        -- Second column is an icon indicating whether the player is already proficient or an expert
        local playerProficiency = playerInfo.Proficiencies.Skills[skillName]
        local isProficient = false
        local isExpert = false
        if playerProficiency then
            isProficient = playerProficiency.Proficient
            isExpert = playerProficiency.Expertise
        end
        local skillStateCell = row:AddCell()
        AddProficiencyImage(skillStateCell, isProficient, isExpert)

        -- Third column is the skill name
        local skillNameCell = row:AddCell()
        local skillNameText = Ext.Loca.GetTranslatedString(skill.DisplayName)
        local skillTextbox = skillNameCell:AddText(skillNameText)
        AddLocaTooltip(skillTextbox, skill.Description)

        -- Fourth column is the skill bonus total
        local skillBonusCell = row:AddCell()
        local skillBonusText = skillBonusCell:AddText("+0")
        local abilityResource = abilityResources[skill.Ability]

        -- Remaining columns are the skill check boxes (less the last centering column)
        local rowSkillWiring = {}
        for _, column in ipairs(skillColumns) do
            local cell = row:AddCell()
            local addCheckbox = false
            local checkBoxType = "proficiency"
            -- Don't add checkboxes for proficiences or expertise that I already possess.
            if column.IsExpertise then
                if not isExpert then
                    checkBoxType = "expertise"
                    addCheckbox = true
                end
            else
                if not isProficient then
                    addCheckbox = true
                end
            end
            if addCheckbox then
                _E6P("Adding " .. checkBoxType .. " checkbox for " .. skillName)
                local checkBox = SpicyCheckbox(cell)
                local skillInstance = {Name = skillName, Checkbox = checkBox, PointResource = column.Resource, IsExpertise = column.IsExpertise}
                table.insert(rowSkillWiring, skillInstance)
            end
        end

        -- Last column is a centering column
        row:AddCell()

        local wiringProficiency = function()
            for _,wiring in ipairs(rowSkillWiring) do
                if wiring.Checkbox.Checked and not wiring.IsExpertise then
                    return true
                end
            end
            return false
        end
        local wiringExpertise = function()
            for _,wiring in ipairs(rowSkillWiring) do
                if wiring.Checkbox.Checked and wiring.IsExpertise then
                    return true
                end
            end
            return false
        end

        local getProficient = function()
            return isProficient or wiringProficiency()
        end

        local getExpertise = function()
            return isExpert or wiringExpertise()
        end

        local signNumber = function(value)
            if value < 0 then
                return tostring(value)
            else
                return "+" .. tostring(value)
            end
        end

        -- Now that I have all the check boxes for the skill, I can wire them up
        -- I need to have an update for the skill bonus text to update based on:
        --  changes to the ability score
        --  changes in the proficiency allocation
        --  the initial proficiency/expertise state
        local updateSkillBonus = function()
            local abilityBonus = math.floor((abilityResource.count - 10)/2)
            local bonus = abilityBonus
            local hasProficiency = getProficient()
            local hasExpertise = getExpertise()
            local tooltipTextId = "hb0265d8egc78ag416eg810ag2b94aaf0941b"
            if hasProficiency then
                bonus = bonus + playerInfo.ProficiencyBonus
                tooltipTextId = "h4aabf6e2gf7d1g4d29ga2a2g0b1703d10f23"
            end
            if hasExpertise then
                bonus = bonus + playerInfo.ProficiencyBonus
                tooltipTextId = "h522a98b0gd1b0g4bd8ga74dgb33b8cdaa8cb"
            end

            local text = signNumber(bonus)
            skillBonusText.Label = text
            local tooltip = Ext.Loca.GetTranslatedString(tooltipTextId)
            local abilityName = Ext.Loca.GetTranslatedString(abilityPassives[skill.Ability].DisplayName)
            AddTooltip(skillBonusText, SubstituteParameters(tooltip, { Ability = abilityName, AbilityMod = signNumber(abilityBonus), ProficiencyBonus = signNumber(playerInfo.ProficiencyBonus) }))
        end

        updateSkillBonus()

        abilityResource:add(function(_, _)
            updateSkillBonus()
        end)

        -- Check boxes need to follow the rules of:
        --  If I set proficiency in any other column, all other proficiency check boxes are disabled
        --  If I set expertise in any other column, all other proficiency and expertise check boxes are disabled (forcing the proficiency to be checked)
        --  If there is no proficiency for a skill, the expertise box is disabled
        local updateSkillRowStates = function()
            local isSelectedProficient = wiringProficiency()
            local isSelectedExpertise = wiringExpertise()

            for _,wiring in ipairs(rowSkillWiring) do
                local hasResources = wiring.PointResource.count > 0
                local isChecked = wiring.Checkbox.Checked
                local checkboxEnabled = true
                checkboxEnabled = true
                -- Disable all other unselected proficiency checkboxes
                if isSelectedProficient then
                    if not wiring.IsExpertise and not isChecked then
                        checkboxEnabled = false
                    end
                end
                if isSelectedExpertise then
                    -- Disable all other expertise checkboxes
                    if wiring.IsExpertise and not isChecked then
                        checkboxEnabled = false
                    end
                    -- Disable the proficiency checkbox if the expertise checkbox is checked to ensure it doesn't get unchecked
                    if not wiring.IsExpertise and isChecked then
                        checkboxEnabled = false
                    end
                else
                    -- Disable the expertise checkbox if the proficiency checkbox is unchecked
                    if wiring.IsExpertise and not isSelectedProficient and not isProficient then
                        checkboxEnabled = false
                    end
                end
                if not hasResources and not isChecked then
                    checkboxEnabled = false
                end
                wiring.Checkbox.Enabled = checkboxEnabled
            end
        end

        for _,wiring in ipairs(rowSkillWiring) do
            wiring.Checkbox.OnChange = function()
                local isChecked = wiring.Checkbox.Checked
                if isChecked then
                    wiring.PointResource:AcquireResource()
                    if not skillStates[skillName] then
                        skillStates[skillName] = {}
                    end
                    if wiring.IsExpertise then
                        skillStates[skillName].Expertise = true
                    else
                        skillStates[skillName].Proficient = true
                    end
                elseif not isChecked then
                    if wiring.IsExpertise then
                        skillStates[skillName].Expertise = nil
                    else
                        skillStates[skillName].Proficient = nil
                    end
                    wiring.PointResource:ReleaseResource()
                end
                updateSkillBonus()
                updateSkillRowStates()
            end
            wiring.PointResource:add(function(_, _)
                updateSkillRowStates()
            end)
        end
    end


    for _, resource in ipairs(resources) do
        resource:trigger()
    end

    return resources
end

---Gather the abilities and map any single attribute increases to extraPassives
---@param feat table
---@param playerInfo table
---@param extraPassives table
local function GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    local results = {}
    for _,abilityListSelector in ipairs(feat.SelectAbilities) do
        local abilityList = Ext.StaticData.Get(abilityListSelector.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if abilityList then
            local pointCount = abilityListSelector.Count
            local result = { ID = abilityListSelector.SourceId, PointCount = pointCount, Max = abilityListSelector.Max, State = {} }
            table.insert(results, result)

            for _,abilityEnum in ipairs(abilityList.Spells) do -- TODO: Will likely get renamed in the future
                local abilityName = abilityEnum.Label
                local abilityInfo = playerInfo.Abilities[abilityName]
                if abilityInfo.Current < abilityInfo.Maximum then
                    table.insert(result.State, { Name = abilityName, Initial = abilityInfo.Current, Current = abilityInfo.Current, Maximum = abilityInfo.Maximum }) -- The ability name is repeated for UI purposes.
                end
            end

            -- We shouldn't encounter zero, we prefiltered on the server to remove them.
            if #result.State == 1 then
                local ability = result.State[1]
                local abilityName = ability.Name
                table.insert(extraPassives, {
                    DisplayName = abilityPassives[abilityName].DisplayName,
                    Description = abilityPassives[abilityName].Description,
                    Icon = abilityPassives[abilityName].Icon,
                    Boost = "Ability(" .. abilityName .. "," .. tostring(pointCount) .. ")",
                })
                table.remove(results, #results) -- Remove the entry so it doesn't show up in the selector
            end
        end
    end
    return results
end

---The details panel for the feat.
---@param feat table The feat to create the window for.
---@param playerInfo table The player id for the feat.
local function ShowFeatDetailSelectUI(feat, playerInfo)
    local windowDimensions = {1000, 1450}
    if not featDetailUI then
        local featDetails = Ext.Loca.GetTranslatedString("h43800b7agdc92g46b6g82dcg22fb987efe6c")
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
    local abilityInfo = GatherAbilitySelectorDetails(feat, playerInfo, extraPassives)
    AddPassivesToFeatDetailsUI(childWin, feat, extraPassives)
    local sharedResources = AddAbilitySelectorToFeatDetailsUI(childWin, abilityInfo, abilityResources)
    local skillSharedResources = AddSkillSelectorToFeatDetailsUI(childWin, feat, playerInfo, abilityResources, skillStates)

    for _, resource in ipairs(skillSharedResources) do
        table.insert(sharedResources, resource)
    end

    local centerCell = CreateCenteredControlCell(featDetailUI, "Select", windowDimensions[1] - 30)
    local select = centerCell:AddButton(Ext.Loca.GetTranslatedString("h04f38549g65b8g4b72g834eg87ee8863fdc5"))

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
    CalculateLayout()

    if featUI == nil then
        local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8")
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
            MakeFeatButton(featUI, windowDimensions[1], { ID = message.PlayerId, Name = message.PlayerName, Abilities = message.Abilities, Proficiencies = message.Proficiencies, ProficiencyBonus = message.ProficiencyBonus }, feat)
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
