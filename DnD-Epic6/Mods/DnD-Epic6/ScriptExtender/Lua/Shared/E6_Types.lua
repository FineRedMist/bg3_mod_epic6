
-----------------------------------------------------------------------------------------------------------------------
-- Feat Information
-----------------------------------------------------------------------------------------------------------------------

---@class SelectAbilitiesType
---@field Count integer The number of passive abilities to select.
---@field Max integer The maximum value the ability can be raised to.
---@field Source string The source of the ability.
---@field SourceId GUIDSTRING The GUID that maps to the selector list.

---@class SelectSkillsType
---@field Count integer The number of passive skills to select.
---@field Source string The source of the skill.
---@field SourceId GUIDSTRING The GUID that maps to the selector list.

---@class SelectSkillExpertiseType : SelectSkillsType
---@field Arg3 any The third argument to pass when selecting a passive.

---@class SelectPassiveType
---@field Count integer The number of passive abilities to select.
---@field Unknown any An unknown field
---@field Arg3 any The third argument to pass when selecting a passive.
---@field SourceId GUIDSTRING The GUID that maps to the selector list.

---@class SelectSpellBaseType
---@field SpellsId GUIDSTRING The GUID that maps to the selector list.
---@field SelectorId string? A string selector that provides information for the spell selection. I think it maps to the spellbook for listing details like Magic Initiate, but haven't figured it out yet.
---@field ActionResource string? The action resource to use for casting the spell.
---@field PrepareType SpellPrepareType? The type of preparation for the spell, may be blank.
---@field CooldownType SpellCooldownType? The cooldown type for the spell, may be blank.
---@field Ability AbilityId The ability ID to apply for adding spells. This is retrieved by specialist functions between AddSpells and SelectSpells, as the source has different names.

---@class AddSpellsType : SelectSpellBaseType

---@class SelectSpellsType : SelectSpellBaseType
---@field Count integer The number of spells to select.

---@class SelectSpellInfoType : SelectSpellBaseType
---@field SpellId GUIDSTRING The GUID of the spell.
---@field Level integer The level of the spell.

---@class FeatType A feat, with a lot of information transformed into something more usable.
---@field ID GUIDSTRING The GUID of the feat.
---@field ShortName string The short name of the feat.
---@field DisplayName string The display name of the feat.
---@field Description string The description of the feat.
---@field CanBeTakenMultipleTimes boolean Whether the feat can be taken multiple times.
---@field PassivesAdded string[] The passives added by the feat.
---@field SelectAbilities SelectAbilitiesType[] The abilities to select from the feat. May be empty (but not nil).
---@field SelectSkills SelectSkillsType[] The skills to select from the feat. May be empty (but not nil).
---@field SelectSkillsExpertise SelectSkillExpertiseType[] The skill expertise to select from the feat. May be empty (but not nil).
---@field SelectPassives SelectPassiveType[] The passives to select from the feat. May be empty (but not nil).
---@field AddSpells AddSpellsType[] The spells to add from the feat. May be empty (but not nil).
---@field SelectSpells SelectSpellsType[] The spells to select from the feat. May be empty (but not nil).
---@field HasRequirements function[] The requirements to take the feat. May be empty (but not nil). The function takes two arguments, the EntityHandle of the character, and the derived player information.

-----------------------------------------------------------------------------------------------------------------------
-- Player Information
-----------------------------------------------------------------------------------------------------------------------

---@class AbilityScoreType The ability score type for the player.
---@field Current integer The current value of the ability score.
---@field Maximum integer The maximum value of the ability score.

---@class ProficiencyType The ability score type for the player.
---@field Proficient boolean? Whether the character is proficient in a skill, nil implies false.
---@field Expertise boolean? Whether the character has expertise in a skill, nil implies false.

---@class ProficiencyInformationType The proficiency information for the player.
---@field Skills table<string, ProficiencyType> The mapping of skill names to the proficiency information.
---@field SavingThrows table<string, boolean> The mapping of saving throw names to whether the character is proficient in the saving throw.
---@field Equipment table<string, boolean> The mapping of equipment names to whether the character is proficient in the equipment.

---@class SelectedSpellsType The selected spells for the player.
---@field Added table<string, boolean> The mapping of spell list ID to whether the spell group has been added.
---@field Selected table<string, string[]> The mapping of spell list ID to the selected spells from that list.

---@class PlayerInformationType Information about the player for determine what is legal to select for the feat.
---@field ID string The unique id of the player
---@field Name string? The name of the character the player is playing
---@field PlayerFeats table<string, number> The mapping of feat IDs to the number of times the feat has been taken by the player.
---@field PlayerPassives table<string, number> The mapping of passive IDs to the number of times the passive has been taken by the player.
---@field SelectableFeats string[] The list of feat IDs that the player can select from.
---@field Abilities table<string, AbilityScoreType>? The mapping of ability names to the ability score information.
---@field Proficiencies ProficiencyInformationType? The proficiency information for the player.
---@field ProficiencyBonus integer The proficiency bonus for the player.
---@field Spells SelectedSpellsType The selected spells for the player.

-----------------------------------------------------------------------------------------------------------------------
-- Selected Feat Information
-----------------------------------------------------------------------------------------------------------------------

---@class SelectedFeatType The selected feat information to send to the server.
---@field FeatId GUIDSTRING The GUID of the feat.
---@field PassivesAdded string[] The passives added by the feat.
---@field Boosts string[] The boosts added by the feat.

---@class SelectedFeatPayloadType The selected feat payload to send to the server.
---@field PlayerId string The player id for the feat.
---@field Feat SelectedFeatType The feat to send to the server.

-----------------------------------------------------------------------------------------------------------------------
-- Gathered Passive Information (client side only)
-----------------------------------------------------------------------------------------------------------------------

---@class ExtraPassiveType The extra passive information to track on the client for UI
---@field DisplayName string The display name of the passive.
---@field Description string The description of the passive.
---@field Icon string The icon of the passive.
---@field Boost string The boost to apply for the passive.
