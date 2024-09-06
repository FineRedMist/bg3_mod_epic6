
---Returns true if selecting the passive won't cause the player to lose out on something important (like saving throw proficiency, stat increase, etc)
---@param playerInfo table The player info to query against
---@param passive string The name of the passive
---@param passiveStat table The stat retrieved for the passive
local function IsPassiveSafe(playerInfo, passive, passiveStat)
    -- If we already have the passive, return false
    if playerInfo.PlayerPassives[passive] then
        return false
    end
    local boostEntry = passiveStat.Boosts
    local boosts = SplitString(boostEntry, ";")
    for _,boost in ipairs(boosts) do
        -- Check ability scores
        local ability, amount, capIncrease = ParseAbilityBoost(boost)
        if ability then
            local playerAbility = playerInfo.Abilities[ability]
            if playerAbility.Current + amount > playerAbility.Maximum + capIncrease then
                return false
            end
        end
    
        -- Check saving throw proficiencies
        local proficiencyType, proficiency = ParseProficiencyBonusBoost(boost)
        if proficiencyType == "SavingThrow" then
            if playerInfo.Proficiencies.SavingThrows[proficiency] then
                return false
            end
        end
    end
    return true
end

local proficiencyIconMap = {
    battleaxes = "ico_proficiency_battleAxe",
    clubs = "ico_proficiency_club",
    daggers = "ico_proficiency_dagger",
    darts = "ico_proficiency_dart",
    flails = "ico_proficiency_flail",
    glaives = "ico_proficiency_glaive",
    greataxes = "ico_proficiency_greatAxe",
    greatclubs = "ico_proficiency_greatClub",
    greatswords = "ico_proficiency_greatSword",
    halbards = "ico_proficiency_halberd",
    handaxes= "ico_proficiency_handAxe",
    handcrossbows = "ico_proficiency_handCrossbow",
    javelins = "ico_proficiency_javelin",
    lightarmour = "ico_proficiency_lightArmour",
    lightcrossbows = "ico_proficiency_lightCrossbow",
    lighthammers = "ico_proficiency_lightHammer",
    longbows = "ico_proficiency_longBow",
    longswords = "ico_proficiency_longSword",
    maces = "ico_proficiency_mace",
    mauls = "ico_proficiency_maul",
    mediumarmour = "ico_proficiency_mediumArmour",
    morningstars = "ico_proficiency_morningStar",
    pikes = "ico_proficiency_pike",
    quarterstaffs = "ico_proficiency_quarterstaff",
    rapiers = "ico_proficiency_rapier",
    scimitars = "ico_proficiency_scimitar",
    shields = "ico_proficiency_shield",
    shortbows = "ico_proficiency_shortBow",
    shortswords = "ico_proficiency_shortSword",
    sickles = "ico_proficiency_sickle",
    slings = "ico_proficiency_sling",
    spears = "ico_proficiency_spear",
    tridents = "ico_proficiency_trident",
    warhammers = "ico_proficiency_warhammer",
    warpicks = "ico_proficiency_warPick",
}

---Identifies the icon to display for the passive
---@param passiveStat table
---@return string
local function GetPassiveIcon(passive, passiveStat)
    local icon = passiveStat.Icon
    if icon and string.len(icon) > 0 then
        _E6P("Passive " .. passive .. " is getting the icon for proficiency: " .. icon)
        return icon
    end

    -- Check for proficiencies
    local boosts = SplitString(passiveStat.Boosts, ";")
    for _,boost in ipairs(boosts) do
        local proficiency = ParseProficiencyBoost(boost)
        if proficiency then
            local lowerProf = string.lower(proficiency)
            local mapped = proficiencyIconMap[lowerProf]
            if mapped then
                mapped = "Assets/Shared/ProficiencyIcons/" .. mapped .. ".DDS"
                _E6P("Passive " .. passive .. " is getting the icon for proficiency: " .. mapped)
                return mapped
            end
            if string.sub(proficiency, string.len(proficiency)) == "s" then
                proficiency = string.sub(proficiency, 1, string.len(proficiency) - 1)
            end
            icon = "ico_proficiency_" .. proficiency
            _E6P("Passive " .. passive .. " is getting the icon for proficiency: " .. icon)
            return icon
        end
    end
    _E6Error("Could not find icon for passive " .. passive)
    return "Item_Unknown"
end

---Adds the ability selector to the feat details, if ability selection is present.
---@param parent ExtuiTreeParent The parent container to add the ability selector to.
---@param feat table
---@param playerInfo table The ability information to render
---@return SharedResource[] The collection of shared resources to bind the Select button to disable when there are still resources available.
function AddPassiveSelectorToFeatDetailsUI(parent, feat, playerInfo, selectedPassives)
    if #feat.SelectPassives == 0 then
        return {}
    end

    local sharedResources = {}

    parent:AddSpacing()
    parent:AddSeparator()
    parent:AddSpacing()

    local uniquingName = feat.ShortName .. "_Passives"
    for passiveIndex, featPassiveInfo in ipairs(feat.SelectPassives) do
        local sharedResource = SharedResource:new(featPassiveInfo.Count)
        table.insert(sharedResources, sharedResource)

        local passiveList = Ext.StaticData.Get(featPassiveInfo.SourceId, Ext.Enums.ExtResourceManagerType.PassiveList)

        local titleCell = CreateCenteredControlCell(parent, uniquingName .. "_Title_" .. tostring(passiveIndex), parent.Size[1] - 60)
        local title = titleCell:AddText("")

        local locString = "h447df23cgb2f2g405bgbe3eg1617f0209e39" -- Select Features: {Count}/{Max}
        if featPassiveInfo.Count == 1 then
            locString = "h8125b54ag30d6g49b0g87c0g579c827eb7da" -- Select Feature: {Count}/{Max}
        end
        locString = Ext.Loca.GetTranslatedString(locString)

        local function updateTitle(_,_)
            title.Label = SubstituteParameters(locString, {Count = sharedResource.count, Max = sharedResource.capacity})
        end
        sharedResource:add(updateTitle)

        updateTitle(nil, nil)

        local iconsPerRow = ComputeIconsPerRow(#passiveList.Passives)
        local iconRowCount = 0
        local row = 0

        local function AddRow()
            iconRowCount = 0
            row = row + 1
            return CreateCenteredControlCell(parent, uniquingName .. "_Passives_" .. tostring(passiveIndex) .. "_" .. tostring(row), parent.Size[1] - 60)
        end

        local passiveCell = AddRow()

        for _,passive in ipairs(passiveList.Passives) do
            local passiveStat = Ext.Stats.Get(passive, -1, true, true)
            --_E6P("Passive " .. passive .. ": " .. E6_ToJson(passiveStat, {}))
            local iconId = GetPassiveIcon(passive, passiveStat)
            local IconControl = nil
            if not IsPassiveSafe(playerInfo, passive, passiveStat) then
                IconControl = passiveCell:AddImage(iconId)
                IconControl.Enabled = false
            else
                IconControl = passiveCell:AddImageButton("", iconId)
                IconControl.OnClick = function()
                    if selectedPassives[passive] then
                        selectedPassives[passive] = nil
                        sharedResource:ReleaseResource()
                        MakeBland(IconControl)
                    else
                        selectedPassives[passive] = true
                        sharedResource:AcquireResource()
                        MakeSpicy(IconControl)
                    end
                end
                sharedResource:add(function(hasResources, _)
                    if hasResources then
                        IconControl.Enabled = true
                    else
                        IconControl.Enabled = selectedPassives[passive] ~= nil
                    end
                end)
            end
            AddLocaTooltipTitled(IconControl, passiveStat.DisplayName, passiveStat.Description)
            IconControl.SameLine = true

            iconRowCount = iconRowCount + 1
            if iconRowCount >= iconsPerRow then
                passiveCell = AddRow()
            end
        end
    end

    return sharedResources
end

