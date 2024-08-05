
local E6_ActiveFeatSelectorUI = nil

local function CalculateLayout()
    _E6P("Client UI Layout value: " .. tostring(Ext.ClientUI.GetStateMachine().State.Layout))
end

---@param ent EntityHandle
function E6_FeatSelectorUI(ent)
    if E6_ActiveFeatSelectorUI ~= nil then
        return
    end

    --CalculateLayout()

    local featTitle = Ext.Loca.GetTranslatedString("h1a5184cdgaba1g432fga0d3g51ac15b8a0a8")
    local win = Ext.IMGUI.NewWindow(featTitle)
    win.Closeable = true
    win.AlwaysAutoResize = true
    win:AddText("Select a feat to learn for: " .. ent.CharacterCreationStats.Name)
    local button = win:AddButton("Close")
    button.OnClick = function()
        E6_ActiveFeatSelectorUI = nil
        win:Destroy()
    end
    win:SetFocus()
    E6_ActiveFeatSelectorUI = ent.CharacterCreationStats.Name
end