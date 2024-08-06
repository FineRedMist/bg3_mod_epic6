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
    --IsUnique = "1",
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
        _E6P("Created feat passive: " .. passiveName)
        --_D(passive)
        passive:Sync()
    end
    return passive
end

local function E6_GenerateEpicFeat(feat)
    if feat.Spec == nil or feat.Desc == nil then
       return false
    end

    -- Create the passive granted by the spell.
    E6_CreatePassive(feat, feat.PassiveName)
end

function E6_GenerateDynamicFeats(featSet)
    for _,feat in pairs(featSet) do
        E6_GenerateEpicFeat(feat)
    end
end

