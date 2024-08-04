local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

local function E6_FindIcon(passives)
    for _,v in ipairs(passives) do
        local passive = Ext.Stats.Get(v, -1, false, true)
        if passive and passive.Icon then
            return passive.Icon
        end
    end
    return nil
end

local function E6_AppendCondition(current, newCondition)
    local result = current
    if string.len(current) ~= 0 then
        result = result .. " and "
    end
    return result .. newCondition
end

local function E6_GetConditionsForPassives(passives, requirements)
    local result = ""
    for _,v in ipairs(passives) do
        result = E6_AppendCondition(result, "not HasPassive('" .. v .. "')")
    end
    if requirements ~= nil and string.len(requirements) ~= 0 then
        result = E6_AppendCondition(result, requirements)
    end
    return result
end

local function E6_SetRaw(target, properties)
    for k,v in pairs(properties) do
        target:SetRawAttribute(k, v)
    end
end

--[[
new entry "E6_FEAT_ALERT"
type "StatusData"
data "StatusType" "BOOST"
data "DisplayName" "h96fd2278gd794g485fg920fg5ffa868bcf87;1"
data "Description" "h00cc62cegda83g4cf3gb18eg202e5bf8a0f7;3"
data "Icon" "PassiveFeature_Generic_Threat"
data "StatusPropertyFlags" "IgnoreResting;DisableCombatlog;ApplyToDead;DisableOverhead;ExcludeFromPortraitRendering;DisablePortraitIndicator"
data "StatusGroups" "SG_RemoveOnRespec"
data "HideOverheadUI" "1"
data "IsUnique" "1"
data "Passives" "Alert"
]]
local basePassive = {
    StatusType = "BOOST",
    StatusPropertyFlags = "IgnoreResting;DisableCombatlog;ApplyToDead;DisableOverhead;ExcludeFromPortraitRendering;DisablePortraitIndicator",
    StatusGroups = "SG_RemoveOnRespec",
    HideOverheadUI = "1",
    IsUnique = "1",
    Boosts = "ActionResource(UsedFeatPoints,1,0)" -- Indicates we have redeemed an epic feat.
}
local function E6_CreateBasePassive(passiveName)
    local passive = Ext.Stats.Create(passiveName, "StatusData", nil)
    E6_SetRaw(passive, basePassive)
    return passive
end

local function E6_CreatePassive(feat, passiveName)
    local passive = Ext.Stats.Get(passiveName)
    if passive == nil then
        passive = E6_CreateBasePassive(passiveName)
        --_D(feat)
        local props = {
            -- DisplayName = feat.Desc.DisplayName.Handle .. ";" .. feat.Desc.DisplayName.Version,
            -- Description = feat.Desc.Description.Handle .. ";" .. feat.Desc.Description.Version,
            -- Icon = E6_FindIcon(featPassives) or "Action_Paladin_LayOnHands_BigHeal",
            Passives = feat.Spec.PassivesAdded
        }
        E6_SetRaw(passive, props)
        --_D(passive)
        passive:Sync()
    end
    return passive
end

--[[
new entry "Shout_Feat_Alert"
type "SpellData"
data "SpellType" "Shout"
data "Level" ""
data "SpellSchool" ""
data "AIFlags" "CanNotUse"
data "SpellContainerID" EpicSpellContainerName
data "SpellProperties" "ApplyStatus(FEAT_ALERT,-1,-1)"
data "TargetConditions" "Self()"
data "Icon" "PassiveFeature_Generic_Threat"
data "DisplayName" "h96fd2278gd794g485fg920fg5ffa868bcf87;1"
data "Description" "h00cc62cegda83g4cf3gb18eg202e5bf8a0f7;3"
data "CastTextEvent" "Cast"
data "UseCosts" "FeatPoint:1"
data "Requirements" "!Combat"
data "RequirementConditions" "not HasPassive('Alert')"
data "SpellAnimation" "9313094a-bae2-454f-9701-f920d0e8e98d,,;,,;ab7b6aac-b3c9-4918-8f17-f777a94dcb5e,,;57211a11-ed0b-46d7-9369-81df25a85df6,,;808fdfab-2e6c-472e-b3c4-19ce4a719d9d,,;,,;ea745d30-eb87-447f-b190-c81298e27d9c,,;,,;,,"
data "SpellFlags" ""
data "DamageType" "None"        
]]
local baseSpell = {
    SpellType = "Shout",
    Level = "",
    SpellSchool = "",
    AIFlags = "CanNotUse",
    SpellContainerID =  "E6_Shout_EpicFeats",
    TargetConditions = "Self()",
    CastTextEvent = "Cast",
    UseCosts = "FeatPoint:1",
    SpellFlags = "",
    DamageType = "None",
    SpellAnimation = "9313094a-bae2-454f-9701-f920d0e8e98d,,;,,;ab7b6aac-b3c9-4918-8f17-f777a94dcb5e,,;57211a11-ed0b-46d7-9369-81df25a85df6,,;808fdfab-2e6c-472e-b3c4-19ce4a719d9d,,;,,;ea745d30-eb87-447f-b190-c81298e27d9c,,;,,;,,",
    Requirements = "!Combat"
}

local function E6_CreateBaseSpell(spellName)
    local spell = Ext.Stats.Create(spellName, "SpellData", nil)
    E6_SetRaw(spell, baseSpell)
    return spell
end

local function E6_CreateSpell(feat, passiveName, featPassives)
    local spellName = "E6_Shout_Feat_" .. feat.Spec.Name
    local spell = Ext.Stats.Get(spellName)
    if spell == nil then
        spell = E6_CreateBaseSpell(spellName)
        local props = {
            SpellProperties = "ApplyStatus(" .. passiveName .. ",-1,-1)",
            Icon = E6_FindIcon(featPassives) or "Action_Paladin_LayOnHands_BigHeal",
            DisplayName = feat.Desc.DisplayName.Handle .. ";" .. feat.Desc.DisplayName.Version,
            Description = feat.Desc.Description.Handle .. ";" .. feat.Desc.Description.Version,
            RequirementConditions = E6_GetConditionsForPassives(featPassives, feat.Spec.Requirements)
        }
        E6_SetRaw(spell, props)

        spell:Sync()
    end
    --_D(spell)
    return spellName
end

local function E6_AddSpellToContainerSpell(spellContainer, spellName)
    if spellContainer.ContainerSpells == nil or string.len(spellContainer.ContainerSpells) == 0 then
        spellContainer.ContainerSpells = spellName
    else
        spellContainer.ContainerSpells = spellContainer.ContainerSpells .. ";" .. spellName
    end
    return true
end

local function E6_GenerateEpicFeat(epicSpellContainer, feat)
    if feat.Spec == nil or feat.Desc == nil then
       return false
    end

    -- Create the passive granted by the spell.
    local passiveName = "E6_FEAT_" .. string.upper(feat.Spec.Name)
    local featPassives = split(feat.Spec.PassivesAdded, ";")
    E6_CreatePassive(feat, passiveName)

    -- Create the spell to link to the passive.
    local spellName = E6_CreateSpell(feat, passiveName, featPassives)

    return E6_AddSpellToContainerSpell(epicSpellContainer, spellName)
end

function E6_GenerateDynamicFeats(featSet)
    local epicSpellContainer = Ext.Stats.Get(EpicSpellContainerName, -1, true, true)
    if epicSpellContainer == nil then
        _E6Error("Failed to get the " .. EpicSpellContainerName)
        return
    end

    local containerNeedsSync = false
    for _,feat in pairs(featSet) do
        if E6_GenerateEpicFeat(epicSpellContainer, feat) then
            containerNeedsSync = true
        end
    end

    if containerNeedsSync then
        epicSpellContainer:Sync()
    end
end

