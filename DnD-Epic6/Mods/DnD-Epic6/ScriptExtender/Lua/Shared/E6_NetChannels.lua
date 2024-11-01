NetChannels = {}

-- Define channel constants for communication between the client and server

-- Server to client message to tell the client to show the feat selector for the given character id.
NetChannels.E6_SERVER_TO_CLIENT_SHOW_FEAT_SELECTOR = "E6_Server_To_Client_Show_Feat_Selector"
-- Server to client message to tell the client to hide the feat selector UI.
NetChannels.E6_SERVER_TO_CLIENT_CLOSE_UI = "E6_Server_To_Client_Close_UI"
-- Client to server message that contains the player id and the selected boosts to apply for the feat.
NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC = "E6_Client_To_Server_Selected_Feat_Spec"
-- Client to server message to export the character (expensive)
NetChannels.E6_CLIENT_TO_SERVER_EXPORT_CHARACTER = "E6_Client_To_server_Export_Character"
-- Client to server message to set the amount of experience to use per feat.
NetChannels.E6_CLIENT_TO_SERVER_SET_XP_PER_FEAT = "E6_Client_To_Server_Set_XP_Per_Feat"
-- Client to server message to switch the character to show feats for.
NetChannels.E6_CLIENT_TO_SERVER_SWITCH_CHARACTER = "E6_Client_To_Server_Switch_Character"

return NetChannels