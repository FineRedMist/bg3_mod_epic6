Ext.Require("Server/E6_FeatPoints.lua")
Ext.Require("Server/E6_SpellFeatHandler.lua")
Ext.Require("Server/E6_NetServerHandlers.lua")
Ext.Require("Server/E6_NetSubscribeEvents.lua")

E6_FeatPointInit()
E6_SpellFeatHandlerInit()
SubscribedEvents.SubscribeToEvents()