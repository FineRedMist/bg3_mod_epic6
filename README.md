# bg3_mod_epic6
My current progress on creating the D&amp;D Epic 6 implementation for BG3

The current implementation has hit an impasse. 

I am posting it so that others can pick up any useful ideas or tools from it while I work on an alternative.

## What is Epic 6?
D&amp;D Epic 6 limits level progressing to 6th level (where power between casters and melee start to diverge substantially). After which, at 10k experience, you earn a feat.

## Outline of Basic Method

My initial idea was to see if I could trigger a variant of the level up UI to grant feats, but this looked exceedingly non-trivial.

Instead, I came up with an idea to generate spells that would effectively grant feats.

### Basic Functionality

There is (flaky) logic that runs during Tick to examine the party members and determine if they have reached level 6. If so, it determines how much experience has been earned and calculates the number of feats to grant.

For testing purposes, the module changes the required amount of experience for levels and feats to a very small number.

There are two action resources used to manage feats: 
 * FeatPoint - the number of feats you can cash in
 * UsedFeatPoints - the number of feats that have been consumed

Tick then uses the current experience of the character, computes what the feat points should be and then subtracts the used ones to determine whether there are any to grant. I would have preferred if there was an event to bind to when granted experience, but could not find one.

### Granting Feats

The feats are defined as a boost, and spells are shouts.

By creating the shout with the data entry:

```   data "SpellProperties" "ApplyStatus(E6_FEAT_Actor_SharedDev,-1,-1)"```

It would keep the boost until the next long rest.

However if the boost has the flags

```   data "StatusPropertyFlags" "IgnoreResting"```

Then it would be on permanently.

To get the feat to clear on respec, however, the boost has:

```   data "StatusGroups" "SG_RemoveOnRespec"```

To indicate that a feat got used, the boost also has:

```   data "Boosts" "ActionResource(UsedFeatPoints,1,0)"```

Which would on granting the feat, increase the UsedFeatPoints to indicate consumption of a feat.

So the full combo is:

```
new entry "E6_Shout_Actor_SharedDev"
type "SpellData"
data "SpellType" "Shout"
data "AIFlags" "CanNotUse"
data "TargetConditions" "Self()"
data "CastTextEvent" "Cast"
data "SpellAnimation" "b3b2d16b-61c7-4082-8394-0c04fb9ffdec,,;81c58c55-625d-46c3-bbb7-179b23ef725e,,;3c35a4e1-4441-4603-9c71-82179057d452,,;18c8ab7a-cfef-45b9-851d-e2bc52c9ebc3,,;e601e8fd-4017-4d26-a63a-e1d7362c99b3,,;,,;0b07883a-08b8-43b6-ac18-84dc9e84ff50,,;,,;,,"
data "SpellFlags" "IgnoreSilence"
data "DamageType" "None"
data "PrepareEffect" "c520a0bf-adc6-44f6-abcd-94bc0925b881"
data "VerbalIntent" "Utility"
data "UseCosts" "FeatPoint:1"
data "Requirements" "!Combat"
data "SpellContainerID" "E6_Shout_EpicFeats"
data "RequirementConditions" "not HasPassive('Actor', context.Source)"
data "DisplayName" "h043b0a57ga233g4e36ga311g02054a355b31;1"
data "Description" "h744a3cbcgdc82g4bddg9484g4c296893ae24;4"
data "Icon" "Action_Perform_Voice"
data "SpellProperties" "ApplyStatus(E6_FEAT_Actor_SharedDev,-1,-1)"
```

and 

```
new entry "E6_FEAT_Actor_SharedDev"
type "StatusData"
data "StatusType" "BOOST"
data "StatusPropertyFlags" "IgnoreResting;DisableCombatlog;ApplyToDead;DisableOverhead;ExcludeFromPortraitRendering;DisablePortraitIndicator"
data "StatusGroups" "SG_RemoveOnRespec"
data "HideOverheadUI" "1"
data "IsUnique" "1"
data "Boosts" "ActionResource(UsedFeatPoints,1,0)"
data "Passives" "Actor"
```

## Dynamic Generation

My initial attempt at implementing this was in lua (seen under the https://github.com/FineRedMist/bg3_mod_epic6/tree/main/DnD-Epic6/Mods/DnD-Epic6/ScriptExtender/Lua/Dynamic folder). The problem was spells created entirely through lua using the script extender wouldn't enable targeting (https://github.com/Norbyte/bg3se/issues/339). Unfortunately, I had to shelve this method.

## Static Generation

Static generation is quite a bit more messy. Dynamic generation can query what is loaded and how and just generate on the fly. However, static generation has no insight into which modules are loaded and what is in each module. It has to gather the feats from the game that are present, and then any other mods that provide feats, and do so in such a way that if a mod is present or absent, things just work. Particularly when mods replace the implementation of an existing mod.

This required using the LSLib library to go through the game's pak files to extract information about modules, feats, feat descriptions, abilities, skills, spells, and data in the various stat files (which are used to find the passives that allow grabbing icon names for the 'feat' spells).

So I created a separate C# tool (in a diferent repo) to generate the boosts and shouts. It also generates a json file the lua code reads to combine with the modules that are loaded to wire up the spells (as setting the ContainerSpells property of a spell and syncing works fine).

This was generally working fine with the initial implementation of feats without selectors (selectors allowing selecting say abilities to increase, skills to acquire, or spells to learn).

However, I hit an impasse when I first started working on abilities, which is exhibited in this iteration of the mod.

To handle choosing two ability scores, the root spell for granting the feats links to the ASI spell which is a container with children for choosing Strength, Dexterity, etc. Each of those is a container for choosing the second ability score to increase which is the final spell for applying the boosts.

Unfortunately, spell containers can only be one level, it isn't implemented in Baldur's Gate 3 as a multilevel system (I don't know if this is a limitation of the UI, the spell system, or both). So attempting to select a child container spell results in being kicked out as it can't render the next level for the next set of children.

## Impasse

Without a way to select this way, I'm trying to figure out alternatives.

Now that the Script Extender is adding some UI support, I may revisit that. It also might be possible to tweak the UI to allow multi-level spell selection.

In the meantime, I post this work in progress if others may find the ideas and structure useful.