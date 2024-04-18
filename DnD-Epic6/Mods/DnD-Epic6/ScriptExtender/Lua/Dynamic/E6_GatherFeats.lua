--[[
Get the list of mods and order them based on which overrides others.
May have to use dependencies to help figure that out.

Then find all the Feat.lsx files
<Directory>/Public/<Directory>/Feats.lsx

                <node id="Feat">
                    <attribute id="CanBeTakenMultipleTimes" type="bool" value="true"/>
                    <attribute id="Name" type="FixedString" value="AbilityScoreIncrease"/>
                    <attribute id="PassivesAdded" type="LSString" value="Actor"/>
                    <attribute id="Selectors" type="LSString" value="SelectAbilities(b9149c8e-52c8-46e5-9cb6-fc39301c05fe,2,2,FeatASI)"/>
                    <attribute id="Requirements" type="LSString" value="FeatRequirementAbilityGreaterEqual(&apos;Dexterity&apos;,13)"/>
                    <attribute id="UUID" type="guid" value="d215b9ad-9753-4d74-8ff9-24bf1dce53d6"/>
                </node>

<Directory>/Public/<Directory>(Dev)?/FeatDescriptions.lsx

                <node id="FeatDescription">
                    <attribute id="Description" type="TranslatedString" handle="hdf3e5485gb8a0g4cfdgb6a8g739df90f7fc6" version="4"/>
                    <attribute id="DisplayName" type="TranslatedString" handle="h758e5f63gaf43g4cb8g823fgfd38226d2ecd" version="1"/>
                    <attribute id="ExactMatch" type="FixedString" value="AbilityScoreIncrease"/>
                    <attribute id="FeatId" type="guid" value="d215b9ad-9753-4d74-8ff9-24bf1dce53d6"/>
                    <attribute id="UUID" type="guid" value="7956d6f3-cef7-4470-ad62-c208231d3258"/>
                </node>

Note that the feat descriptions may come from earlier modules while the feats could be modified. For example the AbilityScoreIncrease description is in Sahred/Public/Shared/Feats, while the feat definition is in Shared/Public/SharedDev/Feats.

I also want an icon, so for passives, I can get the icon of the first passive listed:
    In Passive.txt, get Icon field.
]]

local xml2lua = Ext.Require("Dynamic/xml2lua/xml2lua.lua")
local handler = Ext.Require("Dynamic/xml2lua/xmlhandler/tree.lua")

local function E6_GetXml2Lua(xmlText)
    local localHandler = handler:new()
    local xmlparser = xml2lua.parser(localHandler)
    xmlparser:parse(xmlText)
    return localHandler.root
end

local function E6_FeatSupported(feat)
    if feat.Selectors then
        return false
    end
    --[[
    if feat.Requirements then
        return false
    end
    ]]
    return true
end

local function E6_ParseGenericXmlNode(node)
    local result = {}
    for _,a in ipairs(node) do
        local id = a._attr.id
        local type = a._attr.type
        local value = a._attr.value
        if type == "bool" then
            if value == "0" or string.lower(value) == "false" then
                result[id] = false
            else
                result[id] = true
            end
        elseif type == "FixedString" or type == "LSString" or type == "guid" then
            result[id] = value
        elseif type == "TranslatedString" then
            local handle = a._attr.handle
            local version = a._attr.version
            local translated = Ext.Loca.GetTranslatedString(handle)
            local details = { ID = id, Handle = handle, Version = version, Translated = translated }
            result[id] = details
            --_D(details)
        elseif type == "int32" or type == "int64" then
            result[id] = tonumber(value)
        else
            Ext.Utils.PrintError("DnD-Epic6: Unexpected member type: " .. type)
        end
    end
    return result
end

local function E6_MergeNode(featSet, node, nodeTypeId, nodeIdField, featSetNodeName, inclusionFunction)
    if node._attr == nil then
        _P("DnD-Epic6: E6_MergeNode(" .. nodeTypeId .. "): _attr was null")
        return
    end
    if node._attr.id ~= nodeTypeId then
        _P("DnD-Epic6: E6_MergeNode(" .. nodeTypeId .. "): _attr.id mismatched (" .. node._attr .. ")")
        return
    end
    if node.attribute == nil then
        _P("DnD-Epic6: E6_MergeNode: attribute was null")
        return
    end

    local entry = E6_ParseGenericXmlNode(node.attribute)

    local id = entry[nodeIdField]
    if id == nil then
        return
    end
    if inclusionFunction ~= nil and not inclusionFunction(entry) then
        return
    end

    if featSet[id] == nil then
        featSet[id] = {}
    end
    featSet[id][featSetNodeName] = entry
end

local function E6_MergeFeat(featSet, featNode)
    E6_MergeNode(featSet, featNode, "Feat", "UUID", "Spec", E6_FeatSupported)
end

local function E6_MergeFeatDescription(featSet, featNode)
    E6_MergeNode(featSet, featNode, "FeatDescription", "FeatId", "Desc", nil)
end

local function E6_MergeXml(featSet, xml, regionId, mergerFunction)
    local save = xml.save
    if save == nil then
        return
    end
    local region = save.region
    if region == nil or region.node == nil then
        return
    end
    if region._attr == nil or region._attr.id ~= regionId then
        return
    end
    local children = save.region.node.children
    if children == nil or children.node == nil then
        return
    end
    for _,v in ipairs(children.node) do
        mergerFunction(featSet, v)
    end
end

local function E6_MergeFeats(featSet, xml)
    E6_MergeXml(featSet, xml, "Feats", E6_MergeFeat)
end

local function E6_MergeFeatDescriptions(featSet, xml)
    E6_MergeXml(featSet, xml, "FeatDescriptions", E6_MergeFeatDescription)
end

local function E6_ProcessFile(featSet, filePath, mergerFunction)
    local file = Ext.IO.LoadFile(filePath, "data")
    if file == nil then
        return
    end

    _P("DnD-Epic6: " .. filePath .. " has length: " .. tostring(#file))
    local xml = E6_GetXml2Lua(file)
    if xml ~= nil then
        mergerFunction(featSet, xml)
    end
end

-- Gather the mods in dependency/load order.
function E6_ProcessFeats()
    -- Maps feat uuid to the properties, merging feat and featdescription lsx files.
    -- We go in mod order and overwrite any settings found.
    -- First:
    --  featSet[uuid].Desc = <description>
    --  featSet[uuid].Spec = <specification>
    local featSet = {}
    for _,uuid in ipairs(Ext.Mod.GetLoadOrder()) do
        local v = Ext.Mod.GetMod(uuid)
        local mod = {Name = v.Info.Name, ID = v.Info.ModuleUUID, Directory = v.Info.Directory}
        local basePath = "Public/" .. mod.Directory .. "/Feats/"
        E6_ProcessFile(featSet, basePath .. "Feats.lsx", E6_MergeFeats)
        E6_ProcessFile(featSet, basePath .. "FeatDescriptions.lsx", E6_MergeFeatDescriptions)
    end

    return featSet
end
