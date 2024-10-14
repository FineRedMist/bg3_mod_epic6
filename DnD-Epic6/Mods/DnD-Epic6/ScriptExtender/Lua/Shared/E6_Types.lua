

---@class SelectAbilitiesType
---@field Count integer The number of passive abilities to select.
---@field Max integer The maximum value the ability can be raised to.
---@field Source string The source of the ability.
---@field SourceId GUIDSTRING The GUID that maps to the selector list.

---@class SelectSkillsType
---@field Count integer The number of passive skills to select.
---@field Source string The source of the skill.
---@field SourceId GUIDSTRING The GUID that maps to the selector list.

---@class SelectSkillExpertiseType
---@field Count integer The number of passive skills to select.
---@field Arg3 any The third argument to pass when selecting a passive.
---@field Source string The source of the skill.
---@field SourceId GUIDSTRING The GUID that maps to the selector list.

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

---@class FeatType
---@field ID GUIDSTRING The GUID of the feat.
---@field ShortName string The short name of the feat.
---@field DisplayName string The display name of the feat.
---@field Description string The description of the feat.
---@field CanBeTakenMultipleTimes boolean Whether the feat can be taken multiple times.
---@field PassivesAdded string[] The passives added by the feat.
---@field SelectAbilities SelectAbilitiesType[] The abilities to select from the feat. May be empty (but not nil).
---@field SelectSkills SelectSkillsType[] The skills to select from the feat. May be empty (but not nil).
---@field SelectSkillExpertise SelectSkillExpertiseType[] The skill expertise to select from the feat. May be empty (but not nil).
---@field SelectPassives SelectPassiveType[] The passives to select from the feat. May be empty (but not nil).
---@field AddSpells AddSpellsType[] The spells to add from the feat. May be empty (but not nil).
---@field SelectSpells SelectSpellsType[] The spells to select from the feat. May be empty (but not nil).
---@field HasRequirements function[] The requirements to take the feat. May be empty (but not nil). The function takes two arguments, the EntityHandle of the character, and the derived player information.
