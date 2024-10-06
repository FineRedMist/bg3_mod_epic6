
---@param feat table
---@param skillsToShow table
---@param skillColumns table
---@param skillsFromFeat table
---@param expertise boolean
local function GatherSkillsToShow(feat, skillsToShow, skillColumns, skillsFromFeat, expertise)
    for _, skill in ipairs(skillsFromFeat) do
        local skillList = Ext.StaticData.Get(skill.SourceId, Ext.Enums.ExtResourceManagerType.SkillList)
        local skillGroup = {}
        if skillList then
            for _,skillEnum in ipairs(skillList.Skills) do
                local skillName = skillEnum.Label
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


---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param feat table
---@param playerInfo table The ability information to render
---@param abilityResources table<string, SharedResource> The shared resources tracking ability scores to update skill levels.
---@param skillStates table<string, table> The skill states to update when the feat is committed.
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
function AddSkillSelectorToFeatDetailsUI(parent, feat, playerInfo, abilityResources, skillStates)
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
    local skillTitleCell = CreateCenteredControlCell(parent, uniquingName .. "_Title", GetWidthFromViewport(parent) - 60)
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
        local rawText = Ext.Loca.GetTranslatedString("h0b1dd211g01a2g41d3g8b3fg0d5b4bda3712") -- {Count}/{Max}
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
        for _, skill in ipairs(AbilitySkillMap[ability]) do
            if skillsToShow[skill] then
                table.insert(abilitySkills, {Ability = ability, Skill = skill, DisplayName = SkillLoca[skill].DisplayName, Description = SkillLoca[skill].Description})
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
            -- Don't add checkboxes for proficiences or expertise that I already possess.
            if column.IsExpertise then
                if not isExpert then
                    addCheckbox = true
                end
            else
                if not isProficient then
                    addCheckbox = true
                end
            end
            if addCheckbox then
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
            -- {Ability} Modifier: {AbilityMod}
            local tooltipTextId = "hb0265d8egc78ag416eg810ag2b94aaf0941b"
            if hasProficiency then
                bonus = bonus + playerInfo.ProficiencyBonus
                -- {Ability} Modifier: {AbilityMod}
                -- Proficiency Bonus: {ProficiencyBonus}
                tooltipTextId = "h4aabf6e2gf7d1g4d29ga2a2g0b1703d10f23"
            end
            if hasExpertise then
                bonus = bonus + playerInfo.ProficiencyBonus
                -- {Ability} Modifier: {AbilityMod}
                -- Proficiency Bonus: {ProficiencyBonus}
                -- Expertise Bonus: {ProficiencyBonus}
                tooltipTextId = "h522a98b0gd1b0g4bd8ga74dgb33b8cdaa8cb"
            end

            local text = signNumber(bonus)
            skillBonusText.Label = text
            local tooltip = Ext.Loca.GetTranslatedString(tooltipTextId)
            local abilityName = Ext.Loca.GetTranslatedString(AbilityPassives[skill.Ability].DisplayName)
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
                UI_SetEnable(wiring.Checkbox, checkboxEnabled)
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

