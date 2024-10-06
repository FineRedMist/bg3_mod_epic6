Ext.Require("Client/E6_NetClientHandlers.lua")
Ext.Require("Client/E6_SharedResource.lua")
Ext.Require("Client/UI/E6_InitUI.lua")
Ext.Require("Client/E6_NetSubscribedEvents.lua")

SubscribedEvents.SubscribeToEvents()

_E6P("Viewport size: " .. E6_ToJson(Ext.IMGUI.GetViewportSize(), {}))