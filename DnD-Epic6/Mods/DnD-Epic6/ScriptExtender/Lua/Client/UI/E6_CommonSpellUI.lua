---@class SelectSpellInfoUIType : SelectSpellInfoType
---@field IsSelected boolean Whether the spell is enabled.
---@field CanSelect boolean Whether the spell can be selected (if you already have it, you can't select it again).
---@field DisplayName string The display name of the spell.
---@field Description string The description of the spell.
---@field DescriptionParams string[]? The parameters for the description.
---@field Icon string The icon of the spell.
---@field Stat SpellData The spell data for the spell.

---Checks the player's grant map for either added or selected spells to determine if the spell can be selected.
---To be denied granting, the spell must match the resource and ability of the spell grant.
---@param grantMap SpellGrantMapType The mapping of added or selected spells to their grant information.
---@param spell SelectSpellInfoUIType The spell to check for.
---@return boolean True if the spell can be selected, false otherwise.
local function CanSelectFromSpellGrant(grantMap, spell)
    if not grantMap then
        return true
    end
    local grantInfo = grantMap[spell.SpellId]
    if not grantInfo then -- No previous grants for this spell id.
        return true
    end
    for _,spellGrant in ipairs(grantInfo) do
        if spellGrant.ResourceId == spell.ActionResource and spellGrant.AbilityId == spell.Ability then -- Already seleected.
            return false
        end
    end
    return true -- Couldn't find the matching resource and ability for the grant.
end

---A shared cache mapping of spell list ids to the corresponding spells in the list.
---@type table<GUIDSTRING,table<GUIDSTRING,boolean>>
local spellListMap = {}

---Determines if the spell list contains the given spell id.
---@param spellList GUIDSTRING The ID of the list.
---@param spellId GUIDSTRING The spell ID to query for.
---@return boolean? True if the spell list contains the spell, false otherwise.
local function SpellListContainsSpell(spellList, spellId)
    if not spellListMap[spellList] then
        spellListMap[spellList] = {}
        ---@type ResourceSpellList
        local spells = Ext.StaticData.Get(spellList, Ext.Enums.ExtResourceManagerType.SpellList)
        if spells then
            for _,spell in ipairs(spells.Spells) do
                spellListMap[spellList][spell] = true
            end
        end
    end
    return spellListMap[spellList][spellId]
end

---Determines if the player can select the spell.
---@param unlockSpell SelectSpellInfoUIType The spell to unlock.
---@param playerInfo PlayerInformationType Information about the player to alter the spell selector.
---@return boolean True if the spell can be selected, false otherwise.
local function CanSelectSpell(unlockSpell, playerInfo)
    for spellsId,spellGrantInfo in pairs(playerInfo.Spells.Added) do
        for _,spellGrant in ipairs(spellGrantInfo) do
            if spellGrant.ResourceId == unlockSpell.ActionResource and spellGrant.AbilityId == unlockSpell.Ability then
                if SpellListContainsSpell(spellsId, unlockSpell.SpellId) then
                    return false
                end
            end
        end
    end

    for _,spellGrant in pairs(playerInfo.Spells.Selected) do
        if not CanSelectFromSpellGrant(spellGrant, unlockSpell) then
            return false
        end
    end
    return true
end

---Creates a spell information UI type for a givne spell id in the add spells collection
---@param spellCollection SelectSpellBaseType The spell collection information (AddSpellsType or SelectSpellsType)
---@param spellId string The id of the spell.
---@param playerInfo PlayerInformationType? The player information type to know whether the spell is selectable.
---@return SelectSpellInfoUIType? The spell information for the UI
function SpellInfoFromSpellCollection(spellCollection, spellId, playerInfo)
    local spellStat = Ext.Stats.Get(spellId, -1, true, true)
    if not spellStat then
        return nil
    end

    local result = DeepCopy(spellCollection)
    result.Level = spellStat.Level
    result.SpellId = spellId
    result.DisplayName = spellStat.DisplayName
    result.Description = spellStat.Description
    result.DescriptionParams = SplitString(spellStat.DescriptionParams, ";")
    result.Icon = spellStat.Icon
    result.Stat = spellStat
    
    if playerInfo then
        result.IsSelected = false
        result.CanSelect = CanSelectSpell(result, playerInfo)
    else
        result.IsSelected = true
        result.CanSelect = true
    end

    return result
end

local cantripSchoolText = {
    Abjuration = 'h84d192f5g6473g4932gb6a8g1387eae58320',
    Conjuration = 'he52cfcbag8a50g453agb4c8g2fac2ff17c10',
    Divination = 'h39ad0edbg77d3g4021g9e2eg191042e6d467',
    Enchantment = 'h79636df9g296cg4bfdga59cgb7db7d3419ab',
    Evocation = 'h42bcd6b2g9deag452cgb9adg4ce569758b0f',
    Illusion = 'h6b2a69f0g57e8g45c0gb271gbd317790bc8f',
    Necromancy = 'h1431ea5eg3cd6g464dga8c6gfd9653e48f7e',
    Transmutation = 'h2e7f0955g4be5g4a21g8f1cg221d590807d4',
}

local levelSpellSchoolText = {
    Abjuration = 'h3d4828d5gd55ag409dgae7dg3bd8a511ab88',
    Conjuration = 'ha6d3a561g6626g44fegbbd4g77ad67a79367',
    Divination = 'h4059b271gffb3g401dga73ag759f7727aa35',
    Enchantment = 'h53d95750g137ag47f1ga9f4g80a302360a96',
    Evocation = 'h3fe64b3dgfa67g41acg8626g616f6431c50e',
    Illusion = 'h777f9097ge5e2g4741g8b78gde7559263ce5',
    Necromancy = 'h3818a08fg8f0fg47d1gaadegffd9ad47278e',
    Transmutation = 'had85051cg9819g432ag8014gcd586df07944',
}

---Adds an icon for a spell to the given parent. This centralizes logic for spells always added and those that can be selected.
---@param parent ExtuiTreeParent The control to add the spell image (button) to.
---@param spell SelectSpellInfoUIType The spell to add.
---@param playerInfo PlayerInformationType The player information to resolve the spell casting ability.
---@param isButton boolean Whether the spell should be added as a button.
---@return ExtuiImage|ExtuiImageButton The image control for the spell.
function AddSpellIcon(parent, spell, playerInfo, isButton)
    local icon = nil
    if isButton then
        icon = parent:AddImageButton("", spell.Icon, DefaultIconSize)
    else
        icon = parent:AddImage(spell.Icon, DefaultIconSize)
    end

    local modifier = "0"
    local abilityValue = playerInfo.Abilities[spell.Ability]
    if abilityValue then
        modifier = tostring(GetAbilityModifier(abilityValue.Current))
    end

    local resolver = ParameterResolver:new(playerInfo, { SpellCastingAbility=modifier, SpellCastingAbilityModifier=modifier })
    local builder = AddTooltip(icon)
    builder.preText = { function(text) return resolver:Resolve(text) end }
    builder:AddFormattedText(SetWhiteText, spell.DisplayName)

    local school = spell.Stat.SpellSchool.Label
    if school and school ~= "None" then
        local schoolText = nil
        if spell.Level == 0 then
            schoolText = cantripSchoolText[school]
        else
            schoolText = levelSpellSchoolText[school]
        end
        if schoolText then
            builder:AddText(schoolText, spell.Level)
        end
    end
    builder:AddSpacing()
    builder:AddLoca(spell.Description, spell.DescriptionParams)
    return icon
end
