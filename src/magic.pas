{ Magic: the spell menus, spell targeting and casting, one cast handler per spell id run through the spell dispatch
  table, and the effect handlers for the dragons' breath and the charming gaze. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Magic;

interface

uses Types, Crt, GDConsts, GDVars, C_Effect, C_Terr, C_Dir, C_Keys, C_Status, C_Cond,
  C_Stat, C_Class, C_Ifc, C_Npc, C_Race, C_Spell, Border, Music, Blit, TextRend, GameIo, FxEngine, CharHlp, ClassCal,
  MenuCore, Pathing, CbtMap, C_Equip;

{ Run the spell menu GenerateSpellList built and return the chosen spell id, 0 on Escape. selectionType picks the title
  and prompt (1..5; any other gets the default title and no prompt); type 4 offers no Exit. For type 3 the chosen scroll
  goes to GDVars.selectedItem and its slot to GDVars.scribeSpellIndex. The list is freed.
  @param(selectionType The menu's action.)
  @param(index The highlighted entry, kept between calls; negative asks for a full redraw.)
  @returns(The chosen spell id, or 0.) }
function SpellSelection(selectionType: Byte; var index: Integer): Byte;

{ Build the spell menu for GDVars.curChar; True when it is not empty. menuType 0: the memorized spells ready to cast; 5:
  those still being memorized; 1: the known spells it has slots for; 2: the current scroll's spells; 3: every carried
  scroll's; 6: the scroll spells still to scribe; 4: the magic-user spells it has slots for and does not know; 8: those
  of level GDVars.spellFilter it does not know. 0, 5 and 1 are filtered by ClassCanCastSpell. All but the scroll menus
  get spell-level heading lines.
  @param(menuType Which spells are listed.)
  @returns(True when the list is not empty.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Computes a spell's range in combat cells: its base plus its per-level range at the caster's level, or at level 6 when
  cast from an item. Power Word Kill reaches a quarter of that; an area spell reaches at least 1 cell, and a range of
  $FF means touch, 1 cell.
  @param(spell The spell.)
  @returns(The range in combat cells.) }
function CalcSpellRange(spell: Byte): Byte;

{ The target hook outside combat (GDVars.spellFns.selectTarget). By the spell's targeting: 1 the caster; 2 a party
  member picked with 'Cast Spell on whom', starting at the last one picked (none cancels the cast); 3 the whole roster.
  Any other targeting cannot be cast. 'bad spell ' for an id outside 1..$7F.
  @param(spell The spell.)
  @param(ai Unused.)
  @param(cast Receives False when nothing was chosen.) }
procedure NoncombatCastTargetMenu(spell, ai: Byte; var cast: Boolean);

{ Casts a spell for the current character. Outside combat a combat-only spell is refused: from memory it offers to lose
  the spell, from an item it asks whether to use the item (the selected flag reports yes). With the announce flag set
  the cast is announced. Then the target selector picks the targets. Once picked, in combat (not for spell 124) the
  caster turns and a missile flies to the target (Fireball, Necklace Of Missiles, Flame Strike and spell 115 with their
  own missile; Fireball and Lightning Bolt with their own sound), and Stinking Cloud, Cloud Kill, Ice Storm and the
  fireball kinds burst. Invisibility ends, the memorized copy is spent (not for an item), and the spell's handler runs
  from the dispatch table. With no pick, combat asks whether to abort (the abort flag aborts at once) and spends the
  spell; outside combat it just stops.
  @param(spell The spell.)
  @param(flag Nonzero aborts a cancelled aim without asking; passed to the target selector.)
  @param(ai Nonzero announces the cast.)
  @param(selected Receives True when the cast went ahead.) }
procedure CastSpell(spell, flag, ai: Byte; var selected: Boolean);

{ Tells whether an item is readable.
  @param(item The item, or nil.)
  @returns(True for a scroll: item type 39 or 40.) }
function ItemReadable(item: Pointer): Boolean;

{ Take spell off a scroll: clear the slot that holds it, count a quantity of 100..102 down, and remove the scroll from
  the character once all three slots are empty.
  @param(character The character holding the scroll, a Types.PCharacter.)
  @param(item The scroll, a Types.PItem.)
  @param(spell The spell.) }
procedure RemoveSpellFromScroll(character, item: Pointer; spell: Byte);

{ Reports a cast: in combat "Casts a Spell" and the spell's name on row 23; outside combat the caster's name, the given
  text and the spell's name in the text window, then a pause.
  @param(character The caster.)
  @param(message Printed after the caster's name outside combat.)
  @param(spell The spell cast.) }
procedure PrintCastSpellMsg(character: Pointer; message: Types.TStr40; spell: Byte);

{ Remove Curse: cures the target's strength-draining disease or, if it has none, unequips the first cursed item it
  carries and ends that item's magic. }
procedure SpellRemoveCurse;

{ Fills the spell dispatch table (slot 0 NoncombatCastTargetMenu, then spells 1..126) and the breath and gaze effect
  handlers, clears the effect-lock and using-item flags and sets the redraw flag. }
procedure InitSpellFns;

{ Tells whether a character can cast a spell by class. A cleric spell needs Wisdom over 8 and either cleric levels or a
  paladin past level 8; a druid spell, Wisdom over 8 and a ranger past level 6; a magic-user spell, Intelligence over 8
  and either magic-user levels, a ranger past level 8 or, when read from an item, a thief past level 10. A human
  magic-user cannot cast in combat with something in equipment slot 2. Magic-item spells are never cast this way.
  @param(character The caster.)
  @param(spell The spell.)
  @param(flag True when the spell is read from an item.)
  @returns(True when the character can cast it.) }
function ClassCanCastSpell(character: Pointer; spell, flag: Byte): Boolean;

{ Casts Bless on the caster's own side. }
procedure SpellBless;

{ Casts Curse on the caster's enemies. }
procedure SpellCurse;

{ Cure Light Wounds: restores 1d8 hit points. }
procedure SpellCureLightWounds;

{ Casts Cause Light Wounds: 1d8 magic damage. }
procedure SpellCauseLightWounds;

{ Applies a detection spell's effect to the targets. }
procedure SpellDetection;

{ Applies a protection spell's effect to the targets. }
procedure SpellProtection;

{ Applies Resist Cold's effect to the targets. }
procedure SpellResistCold;

{ Casts Burning Hands: fire damage of 1 point per caster level. }
procedure SpellBurningHands;

{ Charm Person: a target of the monster race without bit 1 of immunities, or with iconDimensions over 1, 'is
  unaffected'; a charmed target loses the charm ('is uncharmed'); otherwise it 'is charmed', the effect level carrying
  the caster's side, and the charm handler runs. }
procedure SpellCharmPerson;

{ Casts Enlarge: a Strength by caster level (18 with exceptional 0, 1, 51, 76, 91 and 100 for levels 1..6, then 19, 20,
  21, and 22 above); if it beats the target's and the target has neither Globe of Invulnerability nor Minor Globe of
  Invulnerability, the Enlarge effect makes it 'stronger'. }
procedure SpellEnlarge;

{ Casts Reduce: removes Enlarge from the target unless it saves against spells ("has been reduced"). }
procedure SpellReduce;

{ Casts Friends: the effect with strength 2d4, then the caster's Charisma is recalculated. }
procedure SpellFriends;

{ Casts Magic Missile: (caster level + 1) div 2 missiles of 1d4 + 1 magic damage. }
procedure SpellMagicMissile;

{ Applies Shield's effect to the targets. }
procedure SpellShield;

{ Casts Shocking Grasp: 1d8 plus the caster level in electrical damage. }
procedure SpellShockingGrasp;

{ Casts Sleep with a 4d4 hit-dice pool. Each target costs by its level: 0..1 costs 1, 2 costs 2, 3 costs 4, 4 costs 6, 5
  costs 10 for a creature of the monster race and 20 otherwise, and higher levels cost 20. Animated dead, targets
  already asleep and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target
  order. }
procedure SpellSleep;

{ Hold Person and Hold Monsters: puts the hold effect on up to four targets, with a save modifier by their number: -2 or
  -3 for one, depending on the spell, -1 for two and 0 for three or four. Note: more targets leave the modifier
  undefined. }
procedure SpellHold;

{ Applies Resist Fire's effect to the targets. }
procedure SpellResistFire;

{ Applies Silence's effect to the targets. }
procedure SpellSilence;

{ Casts Slow Poison: on a poisoned target that is not animated, raises 0 hit points to 1, sets it okay and in play,
  applies the spell and re-arms the poison damage for 10. }
procedure SpellSlowPoison;

{ Casts Snake Charm: charms snakes in play and not yet charmed whose hit points, in total, fit in the caster's current
  hit points. }
procedure SpellSnakeCharm;

{ Spell 28, Spiritual Hammer: remove the target's spiritual hammer effect, resolve the spell (run on removal), then run
  that effect's handler on the target. }
procedure SpellSpiritualHammer;

{ Applies the Invisibility spells' effect to the targets. }
procedure SpellInvisibility;

{ Applies Knock's effect to the targets. }
procedure SpellKnock;

{ Mirror Image: 1d4 images, kept in the effect's top bits above the caster's level. }
procedure SpellMirrorImage;

{ Applies Ray of Enfeeblement's effect to the targets. }
procedure SpellRayOfEnfeeblement;

{ Casts Stinking Cloud, Cloud Kill or Blade Barrier: spreads a timed patch of cloud or blades over 4 or 9 cells around
  the target point, links it into the cloud list and lets every creature inside feel it at once. }
procedure SpellStinkingCloud;

{ Strength: raises Strength by a die that goes with the target's class (d4 magic-user, d6 cleric or thief, d8 fighter,
  paladin or ranger); a fighter type goes on into exceptional strength past 18. }
procedure SpellStrength;

{ Casts Heal: removes the target's diseases, blindness and feeblemindedness (recalculating Intelligence and Wisdom),
  then heals it to 1d4 below its maximum. Note: a target already within 1d4 of its maximum heals nothing. }
procedure SpellHeal;

{ Casts Cure Blindness: ends the first target's blindness ('can see'). }
procedure SpellCureBlindness;

{ Casts Cause Blindness: blinds the targets. }
procedure SpellCauseBlindness;

{ Casts Cure Disease: cures the target's disease effects ('cured'). }
procedure SpellCureDisease;

{ Casts Cause Disease, resolving the spell (run on removal) with the Diseased effect's name. }
procedure SpellCauseDisease;

{ Spells 41 and 46, Dispel Magic: try to remove each target's effects (all but in love, Kampfult tentacles and effects
  147 to 151, and those at strength $FF). Each succeeds on d100 at most 50, +5 per casting level above the effect's
  level or -2 per level below; with the debug flag set every roll is shown. A target that lost any 'is affected'. In
  combat the cloud patches in the nine cells round the target cell are tried the same way against their cloud's level,
  and the clouds are aged. Note: below the cloud's level the chance uses the last effect's level (spellTempsView[1])
  rather than the cloud's. }
procedure SpellDispelMagic;

{ Prayer: the effect records the caster's side. }
procedure SpellPrayer;

{ Bestow Curse. }
procedure SpellBestowCurse;

{ Applies Blink's effect to the targets. }
procedure SpellBlink;

{ Spells 47, 64 and 115, Fireball, Necklace Of Missiles and spell 115: (1d3 * 2 + 1)d6 for spell 64, else casting level
  d6, plus the casting level for spell 115, as element 9. When gameState^.location is 0 or overMap is 1 the targets are
  every creature Pathing.BuildTargetList lists from the target cell. The blast is drawn at the target cell. }
procedure SpellFireball;

{ Casts Haste on the caster's side; it removes Slow instead where there is one. }
procedure SpellHaste;

{ Spell 51, Lightning Bolt: element $0C, casting level d6, along LightningPath with count 9. }
procedure SpellLightningBolt;

{ Casts Slow on the caster's enemies; it removes Haste instead where there is one. }
procedure SpellSlow;

{ Casts Harm: diseases the target and leaves it 1d4 hit points. }
procedure SpellHarm;

{ Removes Slow from the target, or else applies the Potion of Speed's effect. }
procedure SpellPotionOfSpeed;

{ Casts Cure Serious Wounds: heals the target 2d8 + 1. }
procedure SpellCureSeriousWounds;

{ Gives the target frost giant strength: Strength 21 for 1d4 * 10 + 40, announced when that beats the target's own; the
  effect is added either way. }
procedure SpellGiantStrength;

{ Javelin of Lightning: a 20-point bolt 3 cells long. }
procedure SpellJavelinOfLightning;

{ Applies the Wand of Paralyzation's effect to the targets ("is paralyzed"). }
procedure SpellWandOfParalyzation;

{ Heals the first target 2d4 + 2 hit points for the Potion of Healing. }
procedure SpellPotionOfHealing;

{ Makes the caster 1d4 + 1 years younger, but no younger than 18. }
procedure SpellYouth;

{ Deals the Wand of Magic Missiles' 2d4 + 2 magic damage. }
procedure SpellWandOfMagicMissiles;

{ Casts Cause Serious Wounds: deals 2d8 + 1 magic damage. }
procedure SpellCauseSeriousWounds;

{ Casts Neutralize Poison: cures the poison of a target that is not animated (Poisoned and both slow-poison effects
  removed with the effect lock), raising 0 hit points to 1 and setting it okay; an unpoisoned target "is unaffected". }
procedure SpellNeutralizePoison;

{ Casts Poison: applies the spell, then, unless the effects of the caster's target cancel the poison attack, runs the
  poison attack's handler (a poison bite) for the caster. }
procedure SpellPoison;

{ Casts Sticks to Snakes: a first target below attack level 6 takes the spell's effect at the caster's level and has the
  snakes effect's handler run if it already has it; a stronger one, unless helpless, 'smashes them flat'. }
procedure SpellSticksToSnakes;

{ Casts Cure Critical Wounds: heals the target 3d8 + 3. }
procedure SpellCureCriticalWounds;

{ Casts Cause Critical Wounds: deals 3d8 + 3 magic damage. }
procedure SpellCauseCriticalWounds;

{ Casts Dispel Evil: gives the caster the dispel evil effect for the spell's duration and applies the spell. }
procedure SpellDispelEvil;

{ Flame Strike: 6d8 damage. }
procedure SpellFlameStrike;

{ Casts Raise Dead: raises a dead or animated target that is not an elf and has Constitution left: its poison is removed
  under the effect lock, it becomes okay with 1 hit point and loses a point of base Constitution ("is raised"). }
procedure SpellRaiseDead;

{ Casts Slay Living: unless the first target's effects cancel it (then it 'is unaffected'), the target is slain ('is
  slain') when it fails a saving throw (type 4) and lacks immunity bit 8; otherwise it takes 2d8 + 1 magic damage. }
procedure SpellSlayLiving;

{ Entangle (slot 78): outdoors only (location 0 or the overland map), each target saves (type 4) against losing its
  turns for the spell's duration ('is entangled'), a save negating it. }
procedure SpellEntangle;

{ Casts Faerie Fire: ApplyEffectToTargets ("is highlighted"). }
procedure SpellFaerieFire;

{ Invisibility to Animals: makes the targets invisible, each with the message 'is invisible'. }
procedure SpellInvisibilityToAnimals;

{ Casts Charm Monsters: ApplyEffectToTargets ("is charmed"), then the charm handler for each charmed target. }
procedure SpellCharmMonsters;

{ Casts Confusion: with the multi-target flag raised throughout, at most 2d8 targets each save (type 4) or are confused
  for the spell's duration ('is confused'). }
procedure SpellConfusion;

{ Dimension Door (slot 83): free the caster of the cannot-move effect ('is free to move'), redraw its old cell, place it
  at the target cell, bring the view to it, and say it 'teleports' (whether or not the placement succeeded). }
procedure SpellDimensionDoor;

{ Casts Fear: with the multi-target flag raised throughout, a cone of 3 rays reaching 6 from the caster toward the
  target cell. Each target that fails a save (type 4) gets the fear effect for the spell's duration ('runs in terror')
  and, if the effect took, flees: fleeing and quick fight set, NPC value $B3 unless above $7F, combat target cleared.
  One that saves 'is unaffected'. }
procedure SpellFear;

{ Fire Shield (slot 85): 'Flame type: Hot Cold' (a random pick for a quick-fighting caster) gives the caster the fire
  shield with hot or cold flames for the spell's duration ('is Protected'), with the fire shield effect (112) when it
  took; any other answer asks 'Abort Spell'. }
procedure SpellFireShield;

{ Casts Fumble: a first target that fails a save (type 4) becomes clumsy ('is clumsy'), one that saves is slowed ('is
  slowed'), each effect with its handler run; then the spell's table effect is resolved on the targets as well ('is
  clumsy'). }
procedure SpellFumble;

{ Ice Storm (slot 87): resolve the spell with 3d10 damage (element mask 10). }
procedure SpellIceStorm;

{ Minor Globe of Invulnerability: protects the targets, each with the message 'is protected'. }
procedure SpellMinorGlobeOfInvulnerability;

{ Barkskin: gives the targets the barkskin effect. }
procedure SpellBarkskin;

{ Casts Cone of Cold: sets the multi-target flag; a cone of 2 rays toward the target cell, reaching (caster level + 1)
  div 2 cells, at least 1, deals caster level + caster-level d4 cold damage (element mask 10). }
procedure SpellConeOfCold;

{ Feeblemind: the target's save is adjusted by its class for the roll (cleric -1, magic-user +4, others +2). A
  feebleminded target also loses the spells it has already cast from memory. }
procedure SpellFeeblemind;

{ Scroll of Protection. }
procedure SpellScrollOfProtection;

{ Casts Charm Person or Mammal: charms the target when it is a person (a race below monster) or a creature of type bit
  2, then runs the charm's handler; the charm's strength holds the caster's team in bit 7 and the caster level. Any
  other target is not charmed. }
procedure SpellCharmPersonOrMammal;

{ Potion of Invisibility. }
procedure SpellPotionOfInvisibility;

{ Cure Light Wounds: restores 1d8 hit points. }
procedure SpellDruidCureLightWounds;

{ Potion of Extra Healing: restores 2d4+2 hit points. }
procedure SpellPotionOfExtraHealing;

{ Bestow Curse. }
procedure SpellMageBestowCurse;

{ Restoration: gives back one drained level, in the class whose next level costs the least experience, with a share of
  the hit points the drain took. }
procedure SpellRestoration;

{ Energy Drain: the caster drains a level from the target through the level-drain effect handler. }
procedure SpellEnergyDrain;

{ Destruction: unless magic resistance (condition 9, element $48) or immunities bit 3 stops it, the target 'is
  destroyed'; otherwise it 'is unaffected'. }
procedure SpellDestruction;

{ Resurrection: brings back a dead target that is not an elf and has constitution left, at full hit points and cured of
  poison. }
procedure SpellResurrection;

{ Hold Animal: the fewer the targets, the harder the save. }
procedure SpellHoldAnimal;

{ Protection from Fire: a ranger gets the druid's form of the protection, anyone else the spell's. }
procedure SpellProtectionFromFire;

{ Casts Death Spell: spends a budget of 2 * 4d20 on the targets in order, each costing by its hit dice (0: 1, 1: 2, 2-3:
  8, 4-5: 16, 6: 16 up to 51 maximum hit points else 20, 7-8: 20, more: 162). A target the budget covers that magic
  resistance (element $40) and immunities bit 3 do not protect drops dead; the rest leave the list. }
procedure SpellDeathSpell;

{ Casts Disintegrate: unless magic resistance (element $48) stops it, a target that fails its saving throw disintegrates
  and loses its items; otherwise it is unaffected. }
procedure SpellDisintegrate;

{ Casts Globe of Invulnerability: applies its effect, protecting the targets. }
procedure SpellGlobeOfInvulnerability;

{ Stone to Flesh (slot 113): a target in play with effect 134 'is killed'; a stone creature 'becomes flesh' (strength
  $FF, then 1) or 'is still flesh'. Otherwise a statue (status 7) returns to play with 1 hit point ('is no longer a
  statue'), and in combat leaves the downed list and its cell is restored; then ResolveSpell runs. }
procedure SpellStoneToFlesh;

{ Casts Flesh to Stone: unless the target's effects cancel it, the target turns to stone on a failed save against
  spells. }
procedure SpellFleshToStone;

{ Casts Mass Invisibility on the caster's side, in combat passing over those with an enemy next to them. }
procedure SpellMassInvisibility;

{ Casts Power Word Stun: stuns the target for 4d4 rounds at up to 30 hit points, 2d4 up to 60, 1d4 up to 90, and not at
  all above. }
procedure SpellPowerWordStun;

{ Fire Touch: covers the targets in flame. }
procedure SpellFireTouch;

{ Iron Skin: protects the targets. }
procedure SpellIronSkin;

{ Mass Charm: charms enemies, up to twice the caster's level in total hit dice, each saving at -2. A creature without
  the charmable flag, one bigger than one combat cell, or one of the caster's side is unaffected. }
procedure SpellMassCharm;

{ Otto's Irresistible Dance: on a hit, the target dances helplessly. }
procedure SpellIrresistibleDance;

{ Power Word Blind: blinds targets until their maximum hit points pass 100 in all. }
procedure SpellPowerWordBlind;

{ Meteor Swarm: four meteors, one per aim mode, each landing on or beside the target point. A creature on a meteor's
  path takes 10d4; one caught in its blast takes 10d4, halved by a save. Note: dir is never reset before the facing
  search. }
procedure SpellMeteorSwarm;

{ Power Word Kill: slays one target of 11 to 60 hit points or, failing that, every target of 10 or less. }
procedure SpellPowerWordKill;

{ Monster Summoning (slot 126): bring up to two of the roster's status-9 creatures onto the caster's side, each onto a
  free cell of the wanted terrain ($17 inside a non-overland location, $45 otherwise) next to a party member, starting
  with the roster head and ending with the caster ('gates in'); 'summons is not answered' when none comes. }
procedure SpellMonsterSummoning;

{ Breathes poison, as an effect handler: three uses from round 0, with the multi-target flag raised throughout. With a
  target chosen, it breathes on the creatures within 3 cells of the end of a 3-cell line toward it, each taking the
  breather's maximum hit points, half on save 3; then a use is spent and its turn ends. Nothing happens when no target
  is caught.
  @param(cr The creature the effect is on.)
  @param(eff The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffBreathePoison(var cr: Pointer; eff: Pointer; removed: Boolean);

{ Lightning breath effect: up to three uses a battle, the count set to 3 in round 0 and kept at 3 or less. With a target
  chosen, aiming as for Lightning Bolt, it breathes lightning along a 9-cell path doing the breather's maximum hit
  points; then a use is spent and its turn ends.
  @param(cr The creature the effect is on.)
  @param(eff The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffBreatheLightning(var cr: Pointer; eff: Pointer; removed: Boolean);

{ Breathes as a red, white or black dragon, as an effect handler: three times a fight, a cone of fire or cold or a line
  of acid that does the dragon's hit points in damage, halved by a save. The biggest red dragon breathes 24d10+12. The
  dragon will not breathe while a creature of its own side is in the way. The multi-target flag is raised while it runs.
  @param(cr The creature the effect is on.)
  @param(eff The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffDragonBreath(var cr: Pointer; eff: Pointer; removed: Boolean);

{ A charming gaze: when a target is chosen, the creature gazes and casts Charm Person on it.
  @param(cr The creature the effect is on.)
  @param(eff Unused.)
  @param(removed Unused.) }
procedure EffGazeCharm(var cr: Pointer; eff: Pointer; removed: Boolean);

implementation

const
  { effect ids only this unit names }
  { Reading Magic }
  EFF_READ_MAGIC = 16;
  { effect 124 }
  EFF_CHARM_GAZE = 124;
  { stone flesh kills }
  EFF_STONE_FLESH_KILLS = 134;

function ClassCanCastSpell(character: Pointer; spell, flag: Byte): Boolean;
begin
  spell := spell and C_Spell.ID_MASK;
  ClassCanCastSpell := False;
  case GDConsts.spellTable[spell].spellBand of
    C_Spell.CLERIC_LIST: ClassCanCastSpell := Boolean(Types.PCharacter(character)^.stats[C_Stat.WISDOM].current > 8) and
      ((ClassCal.EffectiveClassLevel(character, C_Class.CLERIC) > 0) or
       (ClassCal.EffectiveClassLevel(character, C_Class.PALADIN) > 8));
    C_Spell.DRUID_LIST: ClassCanCastSpell := Boolean(Types.PCharacter(character)^.stats[C_Stat.WISDOM].current > 8) and
      (ClassCal.EffectiveClassLevel(character, C_Class.RANGER) > 6);
    C_Spell.MAGIC_USER_LIST: if Types.PCharacter(character)^.stats[C_Stat.INTELLIGENCE].current > 8 then begin
         if (ClassCal.EffectiveClassLevel(character, C_Class.MAGE) > 0) and
             ((Types.PCharacter(character)^.race <> C_Race.HUMAN) or
              (Types.PCharacter(character)^.equipped[C_Equip.ARMOR] = nil) or
              (GDVars.locState.current <> C_Ifc.IN_COMBAT)) then
           ClassCanCastSpell := True;
         if ClassCal.EffectiveClassLevel(character, C_Class.RANGER) > 8 then
           ClassCanCastSpell := True;
         if (flag <> 0) and (ClassCal.EffectiveClassLevel(character, C_Class.THIEF) > 10) then
           ClassCanCastSpell := True
       end;
    C_Spell.ITEM_LIST: ClassCanCastSpell := False
  end
end;

function SpellSelection(selectionType: Byte; var index: Integer): Byte;
var
  item: Pointer;
  scan: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
  initial: Byte;
begin
  prompt := GDConsts.chooseSpellPrompt;
  bottomRow := 22;
  initial := 0;
  MenuCore.ResetMenuSlots(0);
  redraw := False;
  GDVars.horizChoice := 1;
  case selectionType of
    1: title := GDConsts.castMenu;
    2: begin
         title := GDConsts.memorizeMenu;
         bottomRow := 15;
         redraw := Boolean(GDVars.memorizeRedraw)
       end;
    3: title := GDConsts.scribeMenu;
    4: title := GDConsts.learnMenu;
    5: begin
         prompt := GDConsts.spellsOkPrompt;
         title := GDConsts.keepMenu
       end else
    initial := $FF;
    title := GDConsts.blankMenuText;
    prompt := GDConsts.emptyQuery
  end;
  addExit := selectionType <> 4;
  if index < 0 then begin
    redraw := True;
    index := 0
  end;
  if (selectionType = 4) or (selectionType = 1) then redraw := True;
  item := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, title, 1, 5, 38, bottomRow, GDVars.selectorVars.spellList, addExit, initial,
                                redraw, index, item)
  until (ch = #0) or (ch = C_Keys.ESCAPE);
  scan := GDVars.selectorVars.spellList;
  count := 0;
  while scan <> item do begin
    if scan^.inUse = 0 then Inc(count);
    scan := scan^.next
  end;
  if ch <> #0 then
    SpellSelection := 0
  else
    SpellSelection := GDVars.selectorVars.spellIds[count];
  if selectionType = 3 then begin
    GDVars.selectedItem := GDVars.selectorVars.scrollPtrs[count];
    GDVars.scribeSpellIndex := GDVars.selectorVars.scrollSlots[count]
  end;
  MenuCore.FreeStringList(Pointer(GDVars.selectorVars.spellList))
end;

{ Appends a spell to the scroll spell list (and its id list), with a level heading when its level differs from the last
  spell's.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddScrollSpellLine(spell: Byte);
var
  item: Types.PItemRec;
  count: ShortInt;
  lastLevel: Byte;
begin
  item := GDVars.selectorVars.spellList;
  if GDVars.selectorVars.spellList = nil then begin
    GetMem(item, SizeOf(Types.TItemRec));
    GDVars.selectorVars.spellList := item;
    lastLevel := 0;
    count := 0
  end else begin
    count := 1;
    while item^.next <> nil do begin
      if item^.inUse = 0 then Inc(count);
      item := item^.next
    end;
    lastLevel := GDConsts.spellTable[GDVars.selectorVars.spellIds[count - 1]].spellLevel;
    GetMem(item^.next, SizeOf(Types.TItemRec));
    item := item^.next
  end;
  item^.next := nil;
  if GDConsts.spellTable[spell and C_Spell.ID_MASK].spellLevel <> lastLevel then begin
    item^.name := GDConsts.spellLevelNames[GDConsts.spellTable[spell and C_Spell.ID_MASK].spellLevel];
    item^.inUse := 1;
    GetMem(item^.next, SizeOf(Types.TItemRec));
    item := item^.next;
    item^.next := nil
  end;
  if spell > C_Spell.ID_MASK then
    item^.name := ' *'
  else
    item^.name := '  ';
  item^.name := item^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  item^.inUse := 0;
  GDVars.selectorVars.spellIds[count] := spell and C_Spell.ID_MASK
end;

{ Adds a spell to the menu list (and its id list), before the first spell of a higher level; a repeat of the same spell
  is merged into a count "(n)".
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddSpellToList(spell: Byte);
var
  carry: Byte;
  tmp: Byte;
  item: Types.PItemRec;
  scan: Types.PItemRec;
  newNode: Types.PItemRec;
  count: ShortInt;
  k: Byte;
  found: Boolean;
  newLevel: Byte;
begin
  item := GDVars.selectorVars.spellList;
  found := False;
  newLevel := GDConsts.spellTable[spell and C_Spell.ID_MASK].spellLevel;
  if GDVars.selectorVars.spellList = nil then begin
    GameIo.ZeroFill(GDVars.selectorVars.spellCounts, $8D);
    GetMem(item, SizeOf(Types.TItemRec));
    item^.next := nil;
    GDVars.selectorVars.spellList := item;
    count := 0;
    GDVars.selectorVars.spellCounts[count] := 1
  end else begin
    count := 0;
    while (item <> nil) and not found do begin
      if item^.inUse = 0 then begin
        if not ((GDConsts.spellTable[GDVars.selectorVars.spellIds[count]].spellLevel > newLevel) or
                (GDVars.selectorVars.spellIds[count] = (spell and C_Spell.ID_MASK))) then begin
          Inc(count);
          item := item^.next
        end else
          found := True
      end else begin
        item := item^.next;
        Inc(count)
      end
    end;
    if GDVars.selectorVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
      scan := GDVars.selectorVars.spellList;
      if scan <> item then begin
        while scan^.next <> item do scan := scan^.next;
        GetMem(newNode, SizeOf(Types.TItemRec));
        newNode^.next := scan^.next;
        scan^.next := newNode;
        item := newNode
      end else begin
        GetMem(newNode, SizeOf(Types.TItemRec));
        newNode^.next := item;
        GDVars.selectorVars.spellList := newNode;
        item := newNode
      end;
      carry := 1;
      for k := count to 140 do begin
        tmp := GDVars.selectorVars.spellCounts[k];
        GDVars.selectorVars.spellCounts[k] := carry;
        carry := tmp
      end
    end else
      Inc(GDVars.selectorVars.spellCounts[count])
  end;
  if spell > C_Spell.ID_MASK then
    item^.name := ' *'
  else
    item^.name := '  ';
  item^.name := item^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  item^.inUse := 0;
  if GDVars.selectorVars.spellCounts[count] > 1 then
    item^.name := item^.name + ' (' + CharHlp.Uint8Str(GDVars.selectorVars.spellCounts[count]) + ')';
  if GDVars.selectorVars.spellIds[count] <> (spell and C_Spell.ID_MASK) then begin
    carry := GDVars.selectorVars.spellIds[count];
    GDVars.selectorVars.spellIds[count] := spell and C_Spell.ID_MASK;
    for k := count + 1 to 140 do begin
      tmp := GDVars.selectorVars.spellIds[k];
      GDVars.selectorVars.spellIds[k] := carry;
      carry := tmp
    end
  end
end;

{ Add the spells of the scroll in GDVars.selectedItem to the menu: those still to scribe (above $80) when forScribe,
  otherwise every one; only once the scroll is identified (unidMask bits 0..2 clear), which effect $10 on
  GDVars.curChar, or a cleric holding a scroll of base-item slot $0C, makes it. With oneItem a slot-$0C scroll is
  skipped.
  @param(forScribe True lists only the spells still to scribe.)
  @param(oneItem True leaves out slot-12 scrolls.) }
procedure AddScrollSpells(forScribe, oneItem: Boolean);
var
  i: Byte;
  eff: Pointer;
begin
  if oneItem and (GDVars.baseItems[GDVars.selectedItem^.itemType].slot = 12) then
    Exit;
  if CharHlp.HasEffect(GDVars.curChar, Magic.EFF_READ_MAGIC, eff) or
      ((ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.CLERIC) > 0) and
       (GDVars.baseItems[GDVars.selectedItem^.itemType].slot = 12)) then
    GDVars.selectedItem^.unidMask := GDVars.selectedItem^.unidMask and $F8;
  if (GDVars.selectedItem^.unidMask and 7) = 0 then
    for i := 1 to 3 do
      if (forScribe and (GDVars.selectedItem^.spells[i] > C_Spell.PENDING_FLAG)) or
          ((not forScribe) and (GDVars.selectedItem^.spells[i] > 0)) then begin
        Magic.AddScrollSpellLine(GDVars.selectedItem^.spells[i]);
        GDVars.selectorVars.scrollPtrs[GDVars.selectorVars.scrollCount] := GDVars.selectedItem;
        GDVars.selectorVars.scrollSlots[GDVars.selectorVars.scrollCount] := i;
        Inc(GDVars.selectorVars.scrollCount)
      end
end;

{ Clear the scroll table and add the spells of every scroll GDVars.curChar carries (ItemReadable).
  @param(forScribe Passed to AddScrollSpells.)
  @param(allItems Passed to AddScrollSpells as its oneItem.) }
procedure AddAllScrollSpells(forScribe, allItems: Boolean);
var
  i: Byte;
begin
  for i := 0 to 48 do begin
    GDVars.selectorVars.scrollPtrs[i] := nil;
    GDVars.selectorVars.scrollSlots[i] := 0
  end;
  GDVars.selectorVars.scrollCount := 0;
  GDVars.selectedItem := GDVars.curChar^.items;
  while GDVars.selectedItem <> nil do begin
    if Magic.ItemReadable(GDVars.selectedItem) then
      Magic.AddScrollSpells(forScribe, allItems);
    GDVars.selectedItem := GDVars.selectedItem^.next
  end
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  classIdx: Byte;
  i: Integer;
  item: Types.PItemRec;
  newNode: Types.PItemRec;
  prevLevel: Byte;
  level: Byte;
  doBuild: Boolean;
begin
  doBuild := True;
  GenerateSpellList := False;
  GDVars.selectorVars.spellList := nil;
  GameIo.ZeroFill(GDVars.selectorVars.spellIds, $8D);
  with GDVars.curChar^ do begin
  case menuType of
    0: for i := 0 to 140 do
         if (memorized[i] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, memorized[i] and C_Spell.ID_MASK, 0) and
             (memorized[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(memorized[i]);
    5: for i := 0 to 140 do
         if (GDVars.curChar^.memorized[i] > C_Spell.ID_MASK) and
             Magic.ClassCanCastSpell(GDVars.curChar, memorized[i] and C_Spell.ID_MASK, 0) then
           Magic.AddSpellToList(memorized[i]);
    1: for i := 1 to 126 do
         if (knownSpells[i] <> 0) and
             (spellSlots[ShortInt(GDConsts.spellTable[i].spellBand), GDConsts.spellTable[i].spellLevel] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, i, 0) then
           Magic.AddSpellToList(i);
    2: begin
         GDVars.selectorVars.scrollCount := 0;
         Magic.AddScrollSpells(False, False);
         doBuild := False
       end;
    3: begin Magic.AddAllScrollSpells(False, True); doBuild := False end;
    6: begin Magic.AddAllScrollSpells(True, True); doBuild := False end;
    4: for classIdx := 1 to 126 do begin
         level := GDConsts.spellTable[classIdx].spellLevel;
         if (spellSlots[C_Spell.MAGIC_USER_LIST, level] > 0) and
             (GDConsts.spellTable[classIdx].spellBand = C_Spell.MAGIC_USER_LIST) and (knownSpells[classIdx] = 0) then
           Magic.AddSpellToList(classIdx)
       end;
    8: for classIdx := 1 to $7E do begin
         level := GDConsts.spellTable[classIdx].spellLevel;
         if (level = GDVars.spellFilter) and (GDConsts.spellTable[classIdx].spellBand = 2) and
             (knownSpells[classIdx] = 0) then
           Magic.AddSpellToList(classIdx)
       end
  end;
  end;
  if GDVars.selectorVars.spellList <> nil then begin
    if doBuild then begin
      i := 0;
      level := GDConsts.spellTable[GDVars.selectorVars.spellIds[i]].spellLevel;
      GetMem(newNode, SizeOf(Types.TItemRec));
      newNode^.next := GDVars.selectorVars.spellList;
      GDVars.selectorVars.spellList := newNode;
      GDVars.selectorVars.spellList^.name :=
          GDConsts.spellLevelNames[GDConsts.spellTable[GDVars.selectorVars.spellIds[i]].spellLevel];
      GDVars.selectorVars.spellList^.inUse := 1;
      item := GDVars.selectorVars.spellList;
      repeat
        prevLevel := level;
        if GDVars.selectorVars.spellIds[i] <> 0 then
          level := GDConsts.spellTable[GDVars.selectorVars.spellIds[i]].spellLevel;
        if prevLevel < level then begin
          GetMem(newNode, SizeOf(Types.TItemRec));
          newNode^.next := item^.next;
          item^.next := newNode;
          item := item^.next;
          item^.name := GDConsts.spellLevelNames[level];
          item^.inUse := 1
        end;
        Inc(i);
        item := item^.next
      until item = nil
    end;
    GenerateSpellList := True
  end
end;

function CalcSpellRange(spell: Byte): Byte;
var
  spellRange: Byte;
begin
  if GDVars.usingItem = 0 then
    spellRange := GDConsts.spellTable[spell].rangeBase +
      GDConsts.spellTable[spell].rangePerLevel * CharHlp.GetCasterLevel(spell, False)
  else
    spellRange := GDConsts.spellTable[spell].rangePerLevel * 6 + GDConsts.spellTable[spell].rangeBase;
  if spell = 125 then spellRange := spellRange div 4;
  if (spellRange = 0) and (GDConsts.spellTable[spell].area <> 0) then spellRange := 1;
  if spellRange = $FF then spellRange := 1;
  CalcSpellRange := spellRange
end;

{ The duration of spell's effect: its base plus its per-level duration at the caster's level, except for Slow Poison,
  Potion of Speed, Potion of Frost, Wand of Paralyzation, Otto's Irresistible Dance and Mind Blank, which have their
  own.
  @param(spell The spell.)
  @returns(The duration.) }
function CalcSpellDuration(spell: Byte): Word;
var
  duration: Word;
begin
  case spell of
    26: duration := 3780;
    57, 61: duration := FxEngine.RollDice(5, 4);
    59: duration := FxEngine.RollDice(1, 4) * 10 + 40;
    122: duration := 1440;
    121: duration := FxEngine.RollDice(1, 4) + 1;
  else
    duration := GDConsts.spellTable[spell].durBase +
      GDConsts.spellTable[spell].durPerLevel * CharHlp.GetCasterLevel(spell, False)
  end;
  CalcSpellDuration := duration
end;

{ Applies a spell to each target. The save is rolled only when the spell has a saving throw. A spell of fixed range 255
  needs an attack roll as well; a miss counts as saved and zeroes the damage for this and each later target. The damage
  is dealt with the save reducing it, and the spell's effect, if any, is added. With no targets it returns at once,
  leaving the element mask set.
  @param(spell The spell.)
  @param(effect The effect's strength; 0 for the casting level.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(damage The damage; 0 for none.)
  @param(element The damage's element mask.)
  @param(message Printed after each target's name when the effect takes hold.) }
procedure ResolveSpell(spell, effect: Byte; onRemove: Boolean; damage, element: Word; message: Types.TStr40);
var
  effectLevel: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Types.PCharacter;
  saved: Boolean;
begin
  if damage = 0 then GDVars.effectMask := 0 else GDVars.effectMask := element;
  if GDVars.castTargetCount = 0 then Exit;
  if effect = 0 then
    effectLevel := CharHlp.GetCasterLevel(spell, True)
  else
    effectLevel := effect;
  for i := 1 to GDVars.castTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      if GDConsts.spellTable[spell].saveEffect = 0 then
        saved := False
      else
        saved := Boolean(FxEngine.RollSavingThrow(GDVars.spellTargets[i], GDConsts.spellTable[spell].saveType, 0));
      if GDConsts.spellTable[GDVars.opMode].rangeBase = $FF then begin
        CharHlp.RecalcStats(GDVars.spellTargets[i]);
        FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, GDVars.spellTargets[i]);
        if not FxEngine.AttackRoll(GDVars.curChar, GDVars.spellTargets[i],
                                   GDVars.spellTargets[i]^.acCur[0]) then begin
          damage := 0;
          saved := True
        end
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(GDVars.spellTargets[i], damage, GDConsts.spellTable[spell].saveEffect,
                                        Byte(saved));
      if GDConsts.spellTable[spell].effectId > 0 then
        FxEngine.AddEffectWithMessage(GDVars.spellTargets[i], GDConsts.spellTable[spell].effectId,
                                      Magic.CalcSpellDuration(spell), effectLevel, Byte(onRemove),
                                      GDConsts.spellTable[spell].saveEffect, Byte(saved), message)
    end;
  GDVars.effectMask := 0
end;

procedure NoncombatCastTargetMenu(spell, ai: Byte; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  GDVars.spellTargets[1] := GDVars.curChar;
  GDVars.castTargetCount := 1;
  cast := True;
  if not (spell in [1..$7F]) then GDVars.showMessage('bad spell ');
  case GDConsts.spellTable[spell].targeting of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         if GDVars.lastSpellTarget <> nil then GDVars.spellTargets[1] := GDVars.lastSpellTarget;
         CharHlp.SelectChar('Cast Spell on whom', True, 1, GDVars.spellTargets[1]);
         GDVars.lastSpellTarget := GDVars.spellTargets[1];
         if GDVars.spellTargets[1] = nil then begin
           GDVars.castTargetCount := 0;
           cast := False
         end
       end;
    3: begin
         GDVars.spellTargets[GDVars.castTargetCount] := GDVars.partyHead;
         while GDVars.spellTargets[GDVars.castTargetCount]^.next <> nil do begin
           GDVars.spellTargets[GDVars.castTargetCount + 1] := GDVars.spellTargets[GDVars.castTargetCount]^.next;
           Inc(GDVars.castTargetCount)
         end
       end else
    cast := False
  end
end;

procedure CastSpell(spell, flag, ai: Byte; var selected: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  x: ShortInt;
  y: ShortInt;
  direction: Byte;
  caster: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  buf: array[0..3] of Byte;
  pace: Byte;
begin
  caster := GDVars.curChar;
  ok := True;
  if (GDVars.locState.current <> C_Ifc.IN_COMBAT) and (GDConsts.spellTable[spell].targeting = 0) then begin
    if GDVars.usingItem = 0 then begin
      TextRend.DisplayString(1, 19, LightGreen, Black, GDConsts.spellNames[spell]);
      TextRend.DisplayString(1, 20, LightGreen, Black, GDConsts.cantCastHereMsg);
      if MenuCore.YesNoMenu(GDConsts.itemDropQuery, GDConsts.yesChoice) = GDConsts.yesChoice then
        CharHlp.RemoveSpell(caster, spell)
    end else begin
      TextRend.DisplayString(1, 19, LightGreen, Black, GDConsts.thatItemMsg);
      TextRend.DisplayString(1, 20, LightGreen, Black, GDConsts.combatOnlyItemMsg);
      if MenuCore.YesNoMenu(GDConsts.useItemPrompt, GDConsts.yesChoice) = GDConsts.yesChoice then
        selected := True
    end;
    ai := 0;
    ok := False
  end;
  if (ai <> 0) and (GDVars.usingItem = 0) then
    Magic.PrintCastSpellMsg(caster, GDConsts.castsWord, spell);
  while ok do begin
    GDVars.spellFns.selectTarget(spell, flag, selected);
    if selected then begin
      ok := False;
      if (GDVars.locState.current = C_Ifc.IN_COMBAT) and (spell <> 124) then begin
        if spell in [47, 64, 74, 115] then
          Blit.BuildIconFrames(30)
        else
          Blit.BuildIconFrames(17);
        x := CbtMap.CombatCellX(caster);
        y := CbtMap.CombatCellY(caster);
        direction := C_Dir.NORTH;
        while not Pathing.IsDirToward(x, y, GDVars.targetCoordX, GDVars.targetCoordY, direction) do
          Inc(direction);
        if spell in [47, 64, 74, 115] then begin
          pace := 1;
          CharHlp.BuildIconFacingsDir(direction, 30)
        end else
          pace := 4;
        GDVars.combatGfxOn := 1;
        CbtMap.SetCreatureFacing(caster, direction, 1, 0);
        case spell of
          47: Music.SendSoundCommand(GDConsts.soundIds[9]);
          51: Music.SendSoundCommand(GDConsts.soundIds[6])
        else
          Music.SendSoundCommand(GDConsts.soundIds[0])
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.targetCoordX, GDVars.targetCoordY, pace, 30);
        case spell of
          34: CharHlp.ScatterCombatIcon(1, 25, Byte(GDConsts.soundIds[9]));
          91: CharHlp.ScatterCombatIcon(1, 26, Byte(GDConsts.soundIds[9]));
          64, 47, 115:
            if (GDVars.gameState^.location = 0) or (GDVars.gameState^.overMap = 1) or (spell = 64) then
              CharHlp.ScatterCombatIcon(2, 23, Byte(GDConsts.soundIds[9]))
            else
              CharHlp.ScatterCombatIcon(3, 23, Byte(GDConsts.soundIds[9]));
          87: CharHlp.ScatterCombatIcon(2, 24, Byte(GDConsts.soundIds[9]))
        end;
        if CbtMap.CombatIconVisible(caster, 0) then begin
          CbtMap.SetCreatureFacing(caster, caster^.combatAddr^.direction, 1, 1);
          CbtMap.SetCreatureFacing(caster, caster^.combatAddr^.direction, 0, 0)
        end
      end;
      FxEngine.RemoveInvisibility(caster);
      if (GDVars.usingItem = 0) and (spell > 0) then
        CharHlp.RemoveSpell(caster, spell);
      GDVars.opMode := spell;
      GDVars.spellFns.spells[GDVars.opMode];
      GDVars.opMode := 0;
      GDVars.effectInProgress := 0
    end else if GDVars.locState.current <> C_Ifc.IN_COMBAT then
      ok := False
    else if (flag <> 0) or (MenuCore.YesNoMenu(GDConsts.abortSpellPrompt,
                                               GDConsts.yesChoice) = GDConsts.yesChoice) then begin
      CharHlp.PrintBottomLine(GDConsts.spellAbortedMsg);
      if (GDVars.usingItem = 0) and (spell > 0) then
        CharHlp.RemoveSpell(caster, spell);
      ok := False
    end
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.locState.current = C_Ifc.IN_COMBAT then Border.EraseBox(0, 23, 39, 23)
end;

{ Fills the spell targets with the creatures, other than the caster, on a line from the origin through the aimed cell,
  extended to the cone's length and cut short by walls, and with two or three rays on one or two more lines to cells
  beside its end; 255 rays take instead the creatures within 3 cells of the line's end. Note: once a creature has been
  met twice on the main line, no later creature on it is added; and the area list of 255 rays overwrites the line's list
  without ending it, so creatures past its length stay.
  @param(x The column of the cone's origin.)
  @param(y The row of the cone's origin.)
  @param(targetCellX The column of the aimed cell.)
  @param(targetCellY The row of the aimed cell.)
  @param(rays The number of lines (1, 2 or 3), or 255 for an area at the end.)
  @param(reach The cone's length in cells.) }
procedure CollectConeTargets(x, y, targetCellX, targetCellY: ShortInt; rays, reach: Byte);
type
  TCollectedTargets = record
    { unused }
    centerDirectionLead: Byte;
    centerDirection: Byte;
    destinationIndex: Byte;
    listCount: Byte;
    terrainIndex: Byte;
    list: array[0..30] of Byte
  end;
var
  side2X: ShortInt;
  side2Y: ShortInt;
  side1X: ShortInt;
  side1Y: ShortInt;
  walk: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  walkOk: Boolean;
  i: Byte;
  n: Byte;
  lastDirection: Byte;
  directions: array[0..49] of Byte;
  collectedTargets: TCollectedTargets;
  walkDistance: Word;
  found: Boolean;

  { Starts a line walk from (startX, startY) to (endX, endY). }
  procedure SetLine(startX, startY, endX, endY: ShortInt);
  begin
    walk.x1 := startX; walk.y1 := startY;
    walk.x2 := endX; walk.y2 := endY;
    Pathing.PathFind(walk)
  end;

  { Keeps a cell inside the arena. }
  procedure ClampCell(var cellX, cellY: ShortInt);
  begin
    if cellX > 49 then cellX := 49 else if cellX < 0 then cellX := 0;
    if cellY > 24 then cellY := 24 else if cellY < 0 then cellY := 0
  end;

  { Adds each creature on the rest of the walked line to the list, once. }
  procedure CollectAlong;
  var
    j: Byte;
    collected: Boolean;
  begin
    repeat
      done := not Pathing.NextPathStep(walk);
      if not done then begin
        CbtMap.GetArenaContents(walk.cx, walk.cy, collectedTargets.list[0], collectedTargets.terrainIndex);
        j := 1;
        collected := False;
        if collectedTargets.list[0] > 0 then
          repeat
            if collectedTargets.list[j] = collectedTargets.list[0] then
              collected := True
            else if collectedTargets.list[j] = 0 then begin
              collectedTargets.list[j] := collectedTargets.list[0];
              collected := True
            end else
              Inc(j)
          until collected
      end
    until done
  end;

begin
  n := 0;
  SetLine(x, y, targetCellX, targetCellY);
  repeat
    done := not Pathing.NextPathStep(walk);
    if not done then begin
      directions[n] := walk.dir;
      Inc(n)
    end
  until done;
  lastDirection := n - 1;
  n := 0;
  reach := reach shl 1;
  i := walk.dist;
  done := False;
  while (i < reach) and not done do begin
    if (targetCellX < 49) and (targetCellX > 0) and (targetCellY < 24) and (targetCellY > 0) then begin
      case directions[n] of
        0, 2, 4, 6: Inc(i, 2);
        1, 3, 5, 7: Inc(i, 3)
      end;
      Inc(targetCellX, GDConsts.dirDx[directions[n]]);
      Inc(targetCellY, GDConsts.dirDy[directions[n]]);
      if n = lastDirection then n := 0 else Inc(n)
    end else
      done := True
  end;
  ClampCell(targetCellX, targetCellY);
  walkDistance := reach;
  walkOk := Pathing.WalkLine(x, y, targetCellX, targetCellY, walkDistance);
  SetLine(x, y, targetCellX, targetCellY);
  GameIo.ZeroFill(collectedTargets.list[1], 30);
  collectedTargets.listCount := 1;
  repeat
    done := not Pathing.NextPathStep(walk);
    if not done then begin
      CbtMap.GetArenaContents(walk.cx, walk.cy, collectedTargets.list[0], collectedTargets.terrainIndex);
      if collectedTargets.list[0] > 0 then begin
        if collectedTargets.listCount > 1 then begin
          for GDVars.scratchIndex := 1 to collectedTargets.listCount - 1 do
            if collectedTargets.list[GDVars.scratchIndex] = collectedTargets.list[0] then
              found := True
        end else
          found := False;
        if not found then begin
          collectedTargets.list[collectedTargets.listCount] := collectedTargets.list[0];
          Inc(collectedTargets.listCount)
        end;
        collectedTargets.centerDirection := walk.dir
      end
    end
  until done;
  if (rays > 1) and (rays <> $FF) then begin
    side2X := targetCellX + GDConsts.sideRayDx1[collectedTargets.centerDirection];
    side2Y := targetCellY + GDConsts.sideRayDy1[collectedTargets.centerDirection];
    ClampCell(side2X, side2Y);
    side1X := targetCellX + GDConsts.sideRayDx2[collectedTargets.centerDirection];
    side1Y := targetCellY + GDConsts.sideRayDy2[collectedTargets.centerDirection];
    ClampCell(side1X, side1Y);
    SetLine(x, y, side1X, side1Y);
    CollectAlong;
    if rays > 2 then begin
      SetLine(x, y, side2X, side2Y);
      CollectAlong
    end
  end;
  if rays = $FF then begin
    Pathing.BuildTargetList(targetCellX, targetCellY, 3, $FF, 1);
    for GDVars.scratchIndex := 1 to GDVars.targetCount do
      collectedTargets.list[GDVars.scratchIndex] := GDVars.rankedTargets[GDVars.scratchIndex].entity
  end;
  collectedTargets.listCount := 1;
  collectedTargets.destinationIndex := 1;
  GDVars.castTargetCount := 0;
  if collectedTargets.list[1] <> 0 then
    repeat
      if GDVars.creatureArr[collectedTargets.list[collectedTargets.listCount]] <> GDVars.curChar then begin
        Inc(GDVars.castTargetCount);
        GDVars.spellTargets[collectedTargets.destinationIndex] :=
          GDVars.creatureArr[collectedTargets.list[collectedTargets.listCount]];
        Inc(collectedTargets.destinationIndex)
      end;
      Inc(collectedTargets.listCount)
    until collectedTargets.list[collectedTargets.listCount] = 0
end;

{ Apply the current spell's effect to the targets, last first, a bolt flying to each but the last. Each saves with
  saveMod. Spells $0A, $17, $31, $51, $5E, $60, $6C and $78 affect only targets with bit 1 of immunities; Hold Person
  ($17, $31) never affects race 6; $6C needs bit $40 of creatureType. Charm Monsters ($51) records the caster's side in
  the effect level.
  @param(saveMod The modifier to each target's save.)
  @param(message The message.) }
procedure ApplyEffectToTargets(saveMod: ShortInt; message: Types.TStr40);
var
  target: Types.PCharacter;
  saved: Boolean;
  i: Byte;
  saveNegates: Boolean;
  effectLevel: Byte;
  onRemove: Boolean;
begin
  for i := GDVars.castTargetCount downto 1 do
    if GDVars.spellTargets[i] <> nil then begin
      onRemove := False;
      target := GDVars.spellTargets[i];
      if i < GDVars.castTargetCount then begin
        Music.SendSoundCommand(GDConsts.soundIds[0]);
        Blit.BuildIconFrames(17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.curChar), CbtMap.CombatCellY(GDVars.curChar),
                                        CbtMap.CombatCellX(target), CbtMap.CombatCellY(target), 4, 30)
      end;
      saved := Boolean(FxEngine.RollSavingThrow(target, GDConsts.spellTable[GDVars.opMode].saveType, saveMod));
      saveNegates := Boolean(GDConsts.spellTable[GDVars.opMode].saveEffect);
      if (GDVars.opMode in [$0A, $17, $31, $51, $5E, $60, $6C, $78]) and ((target^.immunities and 2) = 0) then
        saved := True;
      if (target^.race = C_Race.MONSTER) and ((GDVars.opMode = 23) or (GDVars.opMode = 49)) then
        saved := True;
      if ((target^.creatureType and $40) = 0) and (GDVars.opMode = 108) then
        saved := True;
      if GDVars.opMode = 81 then begin
        effectLevel := GDVars.curChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.opMode, True);
        onRemove := True
      end else
        effectLevel := CharHlp.GetCasterLevel(GDVars.opMode, True);
      FxEngine.AddEffectWithMessage(target, GDConsts.spellTable[GDVars.opMode].effectId,
                                    Magic.CalcSpellDuration(GDVars.opMode), effectLevel, Byte(onRemove),
                                    Byte(saveNegates), Byte(saved), message)
    end
end;

{ Resolves the current spell on the targets of one side; Bless in combat also skips a target with an enemy next to it.
  @param(hostFlag The side affected.)
  @param(message The effect's message.) }
procedure CastOneSide(hostFlag: ShortInt; message: Types.TStr40);
var
  i: Byte;
begin
  GDVars.effectInProgress := 1;
  for i := 1 to GDVars.castTargetCount do
    if (GDVars.spellTargets[i]^.side <> hostFlag) or
        ((GDVars.opMode = 1) and (GDVars.locState.current = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargets[i], 1, False) > 0)) then
      GDVars.spellTargets[i] := nil;
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, message)
end;

procedure SpellBless;
begin
  Magic.CastOneSide(GDVars.curChar^.side, GDConsts.isText + GDVars.effectNames^[C_Effect.BLESS])
end;

procedure SpellCurse;
begin
  Magic.CastOneSide(ShortInt(CharHlp.EnemyTeam(GDVars.curChar)),
                    GDConsts.isText + GDVars.effectNames^[C_Effect.CURSE])
end;

procedure SpellCureLightWounds;
begin
  if GDVars.castTargetCount = 0 then begin
  end else
    if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(1, 8), False) then
      CharHlp.AnnounceHealStatus(GDVars.spellTargets[1])
end;

procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(1, 8), 8, '')
end;

procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is affected')
end;

procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is protected')
end;

procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is cold-resistant')
end;

procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, CharHlp.GetCasterLevel(GDVars.opMode, False), 9, '')
end;

procedure SpellCharmPerson;
var
  effect: Pointer;
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if target <> nil then
    if ((target^.race = C_Race.MONSTER) and ((target^.immunities and 2) = 0)) or (target^.iconDimensions > 1) then
      CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
    else if CharHlp.HasEffect(target, C_Effect.CHARM, effect) then begin
      FxEngine.RemoveEffect(target, C_Effect.CHARM, nil);
      CharHlp.PrintCreatureMessage(target, 'is uncharmed', 10, 1)
    end else begin
      Magic.ResolveSpell(GDVars.opMode, GDVars.curChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.opMode, True),
                         True, 0, 0, 'is charmed');
      if CharHlp.HasEffect(target, C_Effect.CHARM, effect) then
        FxEngine.CallEffectHandler(C_Effect.CHARM, target, effect, False)
    end
end;

procedure SpellEnlarge;
var
  effectStrength: Byte;
  target: Types.PCharacter;
  effect: Pointer;
begin
  target := GDVars.spellTargets[1];
  GDVars.spellTempsView[0] := 18;
  GDVars.spellTempsView[1] := 0;
  case CharHlp.GetCasterLevel(GDVars.opMode, False) of
    1: GDVars.spellTempsView[1] := 0;
    2: GDVars.spellTempsView[1] := 1;
    3: GDVars.spellTempsView[1] := 51;
    4: GDVars.spellTempsView[1] := 76;
    5: GDVars.spellTempsView[1] := 91;
    6: GDVars.spellTempsView[1] := 100;
    7: GDVars.spellTempsView[0] := 19;
    8: GDVars.spellTempsView[0] := 20;
    9: GDVars.spellTempsView[0] := 21;
  else
    GDVars.spellTempsView[0] := 22
  end;
  if FxEngine.AdjustForNewStrength(target, GDVars.spellTempsView[0], GDVars.spellTempsView[1], effectStrength) and
      not CharHlp.HasEffect(target, C_Effect.GLOBE_OF_INVULNERABILITY, effect) and
      not CharHlp.HasEffect(target, C_Effect.MINOR_GLOBE, effect) then begin
    CharHlp.PrintCreatureMessage(target, 'is stronger', 10, 1);
    FxEngine.AddEffect(target, C_Effect.ENLARGE, Magic.CalcSpellDuration(GDVars.opMode), effectStrength, True);
    FxEngine.RecalcAbility(target, C_Stat.STRENGTH)
  end else
    CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
end;

procedure SpellReduce;
var
  effect: Pointer;
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if target <> nil then
    if GDVars.castTargetCount > 0 then
      if not Boolean(FxEngine.RollSavingThrow(target, 4, 0)) then
        if CharHlp.HasEffect(target, C_Effect.ENLARGE, effect) then begin
          FxEngine.RemoveEffect(target, C_Effect.ENLARGE, nil);
          FxEngine.RecalcAbility(target, C_Stat.STRENGTH);
          CharHlp.PrintCreatureMessage(target, 'has been reduced', 10, 1)
        end
end;

procedure SpellFriends;
var
  { Unused in this version; see the other implementations of this routine. }
  oldCha: Byte;
begin
  Magic.ResolveSpell(GDVars.opMode, FxEngine.RollDice(2, 4), True, 0, 0, 'is friendly');
  FxEngine.RecalcAbility(GDVars.curChar, C_Stat.CHARISMA)
end;

procedure SpellMagicMissile;
var
  casterLevel: Byte;
begin
  casterLevel := CharHlp.GetCasterLevel(GDVars.opMode, False) + 1;
  Magic.ResolveSpell(GDVars.opMode, 0, False, casterLevel div 2 + FxEngine.RollDamageDice(casterLevel div 2, 4), 8,
                     '')
end;

procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is shielded')
end;

procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False,
               FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.opMode, False), $0C, '')
end;

procedure SpellSleep;
var
  i: Byte;
  effect: Pointer;
begin
  GDVars.effectInProgress := 1;
  GDVars.spellTempsView[0] := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.castTargetCount do begin
    case GDVars.spellTargets[i]^.hitDice of
      0..1: GDVars.spellTempsView[1] := 1;
      2: GDVars.spellTempsView[1] := 2;
      3: GDVars.spellTempsView[1] := 4;
      4: GDVars.spellTempsView[1] := 6;
      5: if GDVars.spellTargets[i]^.race = C_Race.MONSTER then GDVars.spellTempsView[1] := 10
         else GDVars.spellTempsView[1] := 20;
    else
      GDVars.spellTempsView[1] := 20
    end;
    if (GDVars.spellTargets[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(GDVars.spellTargets[i], C_Effect.ASLEEP, effect)) and
        (GDVars.spellTempsView[0] >= GDVars.spellTempsView[1]) then
      Dec(GDVars.spellTempsView[0], GDVars.spellTempsView[1])
    else
      GDVars.spellTargets[i] := nil
  end;
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'falls asleep')
end;

procedure SpellHold;
var
  saveMod: ShortInt;
begin
  case GDVars.castTargetCount of
    1: if GDVars.opMode = 23 then saveMod := -2 else saveMod := -3;
    2: saveMod := -1;
    3, 4: saveMod := 0
  end;
  Magic.ApplyEffectToTargets(saveMod, 'is held')
end;

procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is fire resistant')
end;

procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is silenced')
end;

procedure SpellSlowPoison;
var
  effect: Pointer;
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if target^.status = C_Status.ANIMATED then
    GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(target, C_Effect.POISONED, effect) then begin
    if target^.hpCur = 0 then target^.hpCur := 1;
    target^.status := C_Status.OKAY;
    target^.inPlay := 1;
    Magic.ResolveSpell(GDVars.opMode, $FF, True, 0, 0, 'is affected');
    FxEngine.AddEffect(target, C_Effect.SLOW_POISON_HIT, 10, $FF, True)
  end
end;

procedure SpellSnakeCharm;
var
  target: Types.PCharacter;
  effect: Pointer;
begin
  GDVars.spellTempsView[0] := GDVars.curChar^.hpCur;
  GDVars.castTargetCount := 0;
  target := GDVars.partyHead;
  while target <> nil do begin
    if ((target^.creatureType and $10) <> 0) and (target^.inPlay <> 0) and
        (not CharHlp.HasEffect(target, C_Effect.HELPLESS_51, effect)) and
        (GDVars.spellTempsView[0] >= target^.hpCur) then begin
      GDVars.spellTempsView[0] := GDVars.spellTempsView[0] - target^.hpCur;
      Inc(GDVars.castTargetCount);
      GDVars.spellTargets[GDVars.castTargetCount] := target
    end;
    target := target^.next
  end;
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0,
                     GDConsts.isText + GDVars.effectNames^[C_Effect.CHARM])
end;

procedure SpellSpiritualHammer;
var
  { Unused in this version; see the other implementations of this routine. }
  targetLead: array[1..6] of Byte;
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  FxEngine.RemoveEffect(target, C_Effect.SPIRITUAL_HAMMER, nil);
  Magic.ResolveSpell(GDVars.opMode, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_Effect.SPIRITUAL_HAMMER, GDVars.spellTargets[1], nil, False)
end;

procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is invisible')
end;

procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'Knock-Knock')
end;

procedure SpellMirrorImage;
var
  strength: Byte;
begin
  strength := FxEngine.RollDice(1, 4) shl 5;
  strength := strength or CharHlp.GetCasterLevel(GDVars.opMode, True);
  Magic.ResolveSpell(GDVars.opMode, strength, False, 0, 0, 'is duplicated')
end;

procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is weakened')
end;

procedure SpellStinkingCloud;
var
  cellX: Integer;
  cellY: Integer;
  cloud: Pointer;
  direction: Byte;
  count: Byte;
  terrainIndex: Byte;
  j: Byte;
  i: Byte;
  creatureIndex: Byte;
  occupants: array[1..9] of Byte;
begin
  GameIo.ZeroFill(occupants, SizeOf(occupants));
  GetMem(cloud, SizeOf(Types.TCloudNode));
  GameIo.ZeroFill(cloud^, SizeOf(Types.TCloudNode));
  with Types.PCloudNode(cloud)^ do begin
    x := GDVars.targetCoordX;
    y := GDVars.targetCoordY;
    owner := GDVars.curChar;
    lvl := CharHlp.GetCasterLevel(GDVars.opMode, True);
    ttl := lvl;
    case GDVars.opMode of
      34: begin count := 4; terrain := C_Terr.TERRAIN_STINK_CLOUD end;
      91: begin count := 9; terrain := C_Terr.TERRAIN_CLOUDKILL end;
      101: begin
        count := 4;
        terrain := C_Terr.TERRAIN_BLADE_BARRIER;
        ttl := ttl * 3
      end
    end;
    for i := 1 to count do begin
      direction := GDConsts.patchDirections[i];
      cellX := x + GDConsts.dirDx[direction];
      cellY := y + GDConsts.dirDy[direction];
      if (cellX >= 0) and (cellX <= 49) and (cellY >= 0) and (cellY <= 24) then begin
        CbtMap.GetArenaContents(cellX, cellY, creatureIndex, terrainIndex);
        for j := 1 to i - 1 do
          if occupants[j] = creatureIndex then creatureIndex := 0;
        occupants[i] := creatureIndex;
        terrainIndex := CbtMap.ResolveTerrain(cellX, cellY);
        live[i] := Byte((terrainIndex > 0) and (GDConsts.terrain[terrainIndex].cost < C_Terr.TERRAIN_IMPASSABLE));
        savedTerrain[i] := terrainIndex;
        if live[i] <> 0 then
          GDVars.combatMap^.cells[cellY, cellX] := terrain
      end else
        live[i] := 0
    end
  end;
  Types.PCloudNode(cloud)^.next := GDVars.cloudHead;
  GDVars.cloudHead := Types.PCloudNode(cloud);
  CbtMap.ScrollView(GDVars.targetCoordX, GDVars.targetCoordY, $FF, C_Dir.CENTER);
  for i := 1 to count do
    if occupants[i] > 0 then
      FxEngine.ConsiderTerrainEffects(GDVars.creatureArr[occupants[i]], True, False)
end;

procedure SpellStrength;
var
  target: Types.PCharacter;
  percent: Byte;
  hitDie: Byte;
  baseStrength: Byte;
  effectStrength: Byte;
begin
  percent := 0;
  target := GDVars.spellTargets[1];
  if target^.classLevels[C_Class.MAGE] > 0 then
    hitDie := FxEngine.RollDice(1, 4);
  if (target^.classLevels[C_Class.CLERIC] > 0) or (target^.classLevels[C_Class.THIEF] > 0) then
    hitDie := FxEngine.RollDice(1, 6);
  if (target^.classLevels[C_Class.FIGHTER] > 0) or (target^.classLevels[C_Class.RANGER] > 0) or
      (target^.classLevels[C_Class.PALADIN] > 0) then
    hitDie := FxEngine.RollDice(1, 8);
  baseStrength := target^.stats[C_Stat.STRENGTH].current + hitDie;
  if baseStrength > 18 then
    if (target^.classLevels[C_Class.FIGHTER] > 0) or (target^.classLevels[C_Class.RANGER] > 0) or
        (target^.classLevels[C_Class.PALADIN] > 0) then begin
      percent := target^.strExc + (baseStrength - 18) * 10;
      if percent > 100 then percent := 100;
      baseStrength := 18
    end else
      baseStrength := 18;
  if FxEngine.AdjustForNewStrength(target, baseStrength, percent, effectStrength) then begin
    effectStrength := hitDie + 100;
    FxEngine.AddEffect(target, C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.opMode), effectStrength, True);
    FxEngine.RecalcAbility(target, C_Stat.STRENGTH)
  end
end;

{ Removes the first spell target's diseases, with the effect lock set: Diseased, and the Strength-draining disease (with
  its hit-point and helpless effects, then the target's Strength is recalculated).
  @returns(True when one was removed.) }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectBusy := 1;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.DISEASE_STRENGTH) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.spellTargets[1], C_Effect.DISEASE_HIT_POINTS, nil);
    FxEngine.RemoveEffect(GDVars.spellTargets[1], C_Effect.HELPLESS, nil);
    FxEngine.RecalcAbility(GDVars.spellTargets[1], C_Stat.STRENGTH)
  end;
  GDVars.effectBusy := 0
end;

procedure SpellHeal;
var
  target: Types.PCharacter;
  hp: Byte;
begin
  target := GDVars.spellTargets[1];
  if Magic.RemoveDiseaseEffects then
    CharHlp.PrintCreatureMessage(target, GDConsts.isText + 'cured', 10, 0);
  if FxEngine.RemoveEffectWithMessage(target, C_Effect.BLIND) then
    CharHlp.PrintCreatureMessage(target, GDConsts.isText + 'no longer blind', 10, 0);
  if FxEngine.RemoveEffectWithMessage(target, C_Effect.FEEBLEMIND) then begin
    CharHlp.PrintCreatureMessage(target, 'regains intellect', 10, 0);
    FxEngine.RecalcAbility(target, C_Stat.INTELLIGENCE);
    FxEngine.RecalcAbility(target, C_Stat.WISDOM)
  end;
  hp := FxEngine.RollDice(1, 4);
  if target^.hpCur + hp > target^.hpMax then
    hp := 0
  else
    hp := target^.hpMax - target^.hpCur - hp;
  if FxEngine.RestoreHitPoints(target, hp, False) then
    CharHlp.PrintCreatureMessage(target, 'is healed', 10, 0)
end;

procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'can see')
end;

procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is blind')
end;

procedure SpellCureDisease;
begin
  if Magic.RemoveDiseaseEffects then
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], GDConsts.isText + 'cured', 10, 0)
end;

procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, True, 0, 0,
                     GDConsts.isText + GDVars.effectNames^[C_Effect.DISEASED])
end;

procedure SpellDispelMagic;
var
  i: Byte;
  casterLevel: Byte;
  target: Types.PCharacter;
  removed: Boolean;
  effect: Types.PEffect;
  nextEffect: Types.PEffect;
  x: ShortInt;
  y: ShortInt;
  terrainIndex: Byte;
  creatureIndex: Byte;
  cloud: Types.PCloudNode;
  roll: Byte;

  { Whether a dispel roll beats a cloud of the given level. }
  function CloudDispelled(level: Byte): Boolean;
  begin
    if casterLevel > level then
      GDVars.spellTempsView[0] := (casterLevel - level) * 5 + 50
    else if casterLevel < level then
      GDVars.spellTempsView[0] := 50 - (GDVars.spellTempsView[1] - casterLevel) * 2
    else
      GDVars.spellTempsView[0] := 50;
    CloudDispelled := FxEngine.RollDice(1, 100) <= GDVars.spellTempsView[0]
  end;

begin
  GDVars.effectInProgress := 1;
  casterLevel := CharHlp.GetCasterLevel(GDVars.opMode, False);
  for i := 1 to GDVars.castTargetCount do begin
    removed := False;
    target := GDVars.spellTargets[i];
    effect := target^.effects;
    while effect <> nil do begin
      nextEffect := effect^.next;
      if not (effect^.id in
              [C_Effect.IN_LOVE, C_Effect.KAMPFULT_TENTACLES,
               C_Effect.STONE_CREATURE..C_Effect.YETI_SQUEEZE_3]) then
       if effect^.strength < $FF then begin
        GDVars.spellTempsView[1] := effect^.strength and $1F;
        if casterLevel > GDVars.spellTempsView[1] then
          GDVars.spellTempsView[0] := (casterLevel - GDVars.spellTempsView[1]) * 5 + 50
        else if casterLevel < GDVars.spellTempsView[1] then
          GDVars.spellTempsView[0] := 50 - (GDVars.spellTempsView[1] - casterLevel) * 2
        else
          GDVars.spellTempsView[0] := 50;
        roll := FxEngine.RollDice(1, 100);
        if GDConsts.editorEnabled then
          GDVars.showMessage(target^.name + ' ' + GDVars.effectNames^[effect^.id] + ' ' +
                               GDVars.intToStringHook(roll) + '<=' + GDVars.intToStringHook(GDVars.spellTempsView[0]));
        if roll <= GDVars.spellTempsView[0] then begin
          FxEngine.RemoveEffect(target, effect^.id, effect);
          removed := True
        end
      end;
      effect := nextEffect
    end;
    if removed then
      CharHlp.PrintNameStringAnim(target, True, 'is affected')
  end;
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    for GDVars.scratchIndex := 0 to 8 do begin
      x := GDVars.targetCoordX + GDConsts.dirDx[GDVars.scratchIndex];
      y := GDVars.targetCoordY + GDConsts.dirDy[GDVars.scratchIndex];
      CbtMap.GetArenaContents(x, y, creatureIndex, terrainIndex);
      if (terrainIndex = C_Terr.TERRAIN_STINK_CLOUD) or (terrainIndex = C_Terr.TERRAIN_CLOUDKILL) then begin
        cloud := GDVars.cloudHead;
        if terrainIndex = C_Terr.TERRAIN_STINK_CLOUD then creatureIndex := 4
        else creatureIndex := 9;
        while cloud <> nil do begin
          for i := 1 to creatureIndex do
            if (x = cloud^.x + GDConsts.dirDx[GDConsts.patchDirections[i]]) and (y = cloud^.y +
                GDConsts.dirDy[GDConsts.patchDirections[i]]) and
                CloudDispelled(cloud^.lvl) then
              cloud^.ttl := -1;
          cloud := cloud^.next
        end;
        CbtMap.ScrollView(GDVars.targetCoordX, GDVars.targetCoordY, 3, C_Dir.CENTER)
      end
    end;
    FxEngine.CountDownAreaEffects(1)
  end
end;

procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.opMode, GDVars.curChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.opMode, True),
                     False, 0, 0, 'is praying')
end;

procedure SpellRemoveCurse;
var
  item: Types.PItem;
  found: Boolean;
  i: Byte;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.DISEASE_STRENGTH) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'is un-cursed')
  else begin
    found := False;
    item := Types.PItem(GDVars.spellTargets[1]^.items);
    while (item <> nil) and not found do begin
      if item^.cursed <> 0 then begin
        found := True;
        item^.equipped := 0;
        if item^.special > $7F then begin
          GDVars.overrideFlag := 1;
          FxEngine.CallEffectHandler(item^.special, GDVars.spellTargets[1], item, True);
          for i := C_Stat.STRENGTH to C_Stat.CHARISMA do FxEngine.RecalcAbility(GDVars.spellTargets[1], i)
        end
      end;
      item := item^.next
    end;
    if found then
      CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'has an item un-cursed')
  end
end;

procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'has been cursed!')
end;

procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is blinking')
end;

procedure SpellFireball;
var
  range: Byte;
  bonus: Byte;
  i: Byte;
begin
  GDVars.effectInProgress := 1;
  if GDVars.opMode = 64 then
    range := FxEngine.RollDice(1, 3) * 2 + 1
  else
    range := CharHlp.GetCasterLevel(GDVars.opMode, False);
  if (GDVars.gameState^.location = 0) or (GDVars.gameState^.overMap = 1) then begin
    Pathing.BuildTargetList(GDVars.targetCoordX, GDVars.targetCoordY, 2, $FF, 1);
    for i := 1 to GDVars.targetCount do
      GDVars.spellTargets[i] := GDVars.creatureArr[GDVars.rankedTargets[i].entity];
    GDVars.castTargetCount := GDVars.targetCount
  end;
  CbtMap.ScrollView(GDVars.targetCoordX, GDVars.targetCoordY, 0, C_Dir.CENTER);
  if GDVars.opMode = 115 then bonus := range else bonus := 0;
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(range, 6) + bonus, 9, '')
end;

{ Resolves Haste or Slow for up to the casting level of targets on one team, dropping the rest. A kept target with the
  opposing effect only loses it; the others take the spell's effect and have their movement and attack-rate effects run
  again.
  @param(effectId The opposing effect, Slowed or Hasted.)
  @param(side The team to keep: 0 the party's side, 1 the hostiles.)
  @param(message The effect message.) }
procedure HasteSlowLogic(effectId: Byte; side: ShortInt; message: Types.TStr40);
var
  casterLevel: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  affected: Byte;
begin
  GDVars.effectInProgress := 1;
  casterLevel := CharHlp.GetCasterLevel(GDVars.opMode, False);
  for i := 1 to GDVars.castTargetCount do
    if (GDVars.spellTargets[i]^.side = side) and (casterLevel > 0) then begin
      Dec(casterLevel);
      if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[i], effectId) then
        GDVars.spellTargets[i] := nil
    end else
      GDVars.spellTargets[i] := nil;
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, message);
  for i := 1 to GDVars.castTargetCount do
    if GDVars.spellTargets[i] <> nil then
      FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, GDVars.spellTargets[i])
end;

procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.side, 'is Hasted')
end;

{ Strikes the creature at a cell, if any, with lightning; a save halves the damage.
  @param(x The column.)
  @param(y The row.)
  @param(damage The damage.) }
procedure LightningAttackAt(x, y: ShortInt; damage: Word);
var
  creatureIndex: Byte;
  terrainIndex: Byte;
  target: Types.PCharacter;
begin
  CbtMap.GetArenaContents(x, y, creatureIndex, terrainIndex);
  if creatureIndex > 0 then begin
    target := GDVars.creatureArr[creatureIndex];
    FxEngine.InflictNonWeaponDamage(target, damage, 2, FxEngine.RollSavingThrow(target, 4, 0));
    Blit.BuildIconFrames(18)
  end
end;

{ Lightning Bolt's path: strike the creature at the target cell, then walk on from it, away from the caster, for count *
  2 path units, striking each new creature the walk enters. In a dungeon (location 1, not overMap) a wall reflects the
  bolt back the way it came; with flag set, a first bounce within 8 path units of the caster doubles the distance walked
  so far.
  @param(count The bolt's length in cells.)
  @param(damage The damage.)
  @param(flag True makes a first rebound near the caster cost double.) }
procedure LightningPath(count, damage: Word; flag: Boolean);
var
  spent: Byte;
  previousCreature: Byte;
  terrainIndex: Byte;
  creatureIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedCell: array[0..3] of Byte;
  sign: ShortInt;
  previousX: ShortInt;
  previousY: ShortInt;
  oldX: Integer;
  oldY: Integer;
  originX: Integer;
  targetCellX: Integer;
  originY: Integer;
  targetCellY: Integer;
  reverseWalk: Types.TPathReq;
  walk: Types.TPathReq;
  valid: Boolean;
begin
  Blit.BuildIconFrames(18);
  originX := CbtMap.CombatCellX(GDVars.curChar);
  originY := CbtMap.CombatCellY(GDVars.curChar);
  targetCellX := GDVars.targetCoordX;
  targetCellY := GDVars.targetCoordY;
  Magic.LightningAttackAt(targetCellX, targetCellY, damage);
  CbtMap.GetArenaContents(targetCellX, targetCellY, previousCreature, terrainIndex);
  count := count * 2;
  GDVars.effectInProgress := 1;
  spent := 0;
  sign := 1;
  while count > 0 do begin
    GameIo.ZeroFill(walk, SizeOf(walk));
    walk.x1 := targetCellX;
    walk.y1 := targetCellY;
    walk.x2 := targetCellX + (targetCellX - originX) * sign * count;
    walk.y2 := targetCellY + (targetCellY - originY) * sign * count;
    Pathing.PathFind(walk);
    repeat
      previousX := walk.cx;
      previousY := walk.cy;
      if (walk.x1 <> walk.x2) or (walk.y1 <> walk.y2) then
        repeat
          oldX := walk.cx;
          oldY := walk.cy;
          valid := Pathing.NextPathStep(walk);
          CbtMap.GetArenaContents(walk.cx, walk.cy, creatureIndex, terrainIndex)
        until (not valid) or ((creatureIndex > 0) and (creatureIndex <> previousCreature)) or (terrainIndex = 0) or
            (GDConsts.terrain[terrainIndex].cost > 1) or (walk.dist >= count);
      if terrainIndex = 0 then count := 0;
      if (walk.cx < 0) or (walk.cx > 49) or (walk.cy < 0) or (walk.cy > 24) then begin
        walk.cx := oldX;
        walk.cy := oldY
      end;
      CharHlp.CombatAnimateMovingIcon(previousX, previousY, walk.cx, walk.cy, 4, 50);
      if previousCreature <> creatureIndex then
        Magic.LightningAttackAt(walk.cx, walk.cy, damage);
      previousCreature := creatureIndex;
      if (GDConsts.terrain[terrainIndex].cost > 1) and (GDVars.gameState^.overMap = 0) and
          (GDVars.gameState^.location = 1) then begin
        targetCellX := walk.cx;
        targetCellY := walk.cy;
        sign := -1;
        GameIo.ZeroFill(reverseWalk, SizeOf(reverseWalk));
        reverseWalk.x1 := targetCellX;
        reverseWalk.y1 := targetCellY;
        reverseWalk.x2 := originX;
        reverseWalk.y2 := originY;
        Pathing.PathFind(reverseWalk);
        while Pathing.NextPathStep(reverseWalk) do ;
        if flag and (reverseWalk.dist <= 8) then
          walk.dist := walk.dist * 2;
        flag := False
      end;
      spent := walk.dist - spent;
      if spent < 2 then spent := 2;
      if spent < count then Dec(count, spent) else count := 0;
      spent := walk.dist
    until (count = 0) or
        ((GDConsts.terrain[terrainIndex].cost > 1) and (GDVars.gameState^.location = 1) and
         (GDVars.gameState^.overMap = 0))
  end;
  GDVars.effectInProgress := 0
end;

procedure SpellLightningBolt;
var
  damage: Word;
  { Unused in this version; see the other implementations of this routine. }
  boltDirection: Byte;
begin
  GDVars.effectMask := $0C;
  damage := FxEngine.RollDamageDice(CharHlp.GetCasterLevel(GDVars.opMode, False), 6);
  Magic.LightningPath(9, damage, True)
end;

procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, ShortInt(CharHlp.EnemyTeam(GDVars.curChar)), 'is Slowed')
end;

procedure SpellHarm;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  GDVars.effectMask := 8;
  FxEngine.AddEffectWithMessage(target, C_Effect.DISEASED, 0, 0, 0, 0, 0, '');
  CharHlp.PrintCreatureMessage(target, GDConsts.isText + GDVars.effectNames^[C_Effect.DISEASED], 10, 1);
  FxEngine.InflictNonWeaponDamage(target, target^.hpCur - FxEngine.RollDice(1, 4), 0, 0)
end;

procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is Speedy')
end;

procedure SpellCureSeriousWounds;
begin
  if GDVars.castTargetCount = 0 then Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 8) + 1, False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargets[1])
end;

procedure SpellGiantStrength;
var
  effectStrength: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.spellTargets[1], 21, 0, effectStrength) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'is stronger', 10, 1);
  FxEngine.AddEffect(GDVars.spellTargets[1], C_Effect.GIANT_STRENGTH, FxEngine.RollDice(1, 4) * 10 + 40,
                     effectStrength, True);
  FxEngine.RecalcAbility(GDVars.spellTargets[1], C_Stat.STRENGTH)
end;

procedure SpellJavelinOfLightning;
var
  { Unused in this version; see the other implementations of this routine. }
  blocked: Byte;
begin
  GDVars.effectMask := $0C;
  Magic.LightningPath(3, 20, False)
end;

procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is paralyzed')
end;

procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'is Healed')
end;

procedure SpellYouth;
var
  target: Types.PCharacter;
begin
  target := GDVars.curChar;
  target^.age := target^.age - (FxEngine.RollDice(1, 4) + 1);
  if target^.age < 18 then begin
    target^.age := 18;
    CharHlp.PrintCreatureMessage(target, 'is now 18 years old', 10, 1)
  end else
    CharHlp.PrintCreatureMessage(target, 'becomes younger', 10, 1)
end;

procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '')
end;

procedure SpellCauseSeriousWounds;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(2, 8) + 1, 8, '')
end;

procedure SpellNeutralizePoison;
var
  target: Types.PCharacter;
  effect: Pointer;
begin
  target := GDVars.spellTargets[1];
  if target^.status = C_Status.ANIMATED then
    GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(target, C_Effect.POISONED, effect) then begin
    if target^.hpCur = 0 then target^.hpCur := 1;
    GDVars.effectBusy := 1;
    FxEngine.RemoveEffect(target, C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(target, C_Effect.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(target, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectBusy := 0;
    CharHlp.PrintCreatureMessage(target, 'is unpoisoned', 10, 1);
    target^.inPlay := 1;
    target^.status := C_Status.OKAY
  end else
    CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
end;

procedure SpellPoison;
var
  effectNode: Pointer;
  target: Pointer;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 8, '');
  target := GDVars.curChar^.combatAddr^.other;
  GDVars.pendingEffectId := C_Effect.DEADLY_POISON_ATTACK;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, target);
  if GDVars.pendingEffectId = C_Effect.DEADLY_POISON_ATTACK then
    FxEngine.CallEffectHandler(C_Effect.DEADLY_POISON_ATTACK, GDVars.curChar, effectNode, False)
end;

procedure SpellSticksToSnakes;
var
  effect: Pointer;
begin
  if GDVars.spellTargets[1]^.hitDice < 6 then begin
    Magic.ResolveSpell(GDVars.opMode, CharHlp.GetCasterLevel(GDVars.opMode, True), False, 0, 8, '');
    if CharHlp.HasEffect(GDVars.spellTargets[1], C_Effect.SNAKE_HARASS, effect) then
      FxEngine.CallEffectHandler(C_Effect.SNAKE_HARASS, GDVars.spellTargets[1], effect, False)
  end else if not CharHlp.IsHelpless(GDVars.spellTargets[1]) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'smashes them flat', 10, 1)
end;

procedure SpellCureCriticalWounds;
begin
  if GDVars.castTargetCount = 0 then Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(3, 8) + 3, False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargets[1])
end;

procedure SpellCauseCriticalWounds;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(3, 8) + 3, 8, '')
end;

procedure SpellDispelEvil;
begin
  FxEngine.AddEffectWithMessage(GDVars.curChar, C_Effect.DISPEL_EVIL, Magic.CalcSpellDuration(73), 0, 0, 0, 0, '');
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is affected')
end;

procedure SpellFlameStrike;
begin
  GDVars.effectInProgress := 1;
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(6, 8), 9, '')
end;

procedure SpellRaiseDead;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if ((target^.status = C_Status.DEAD_STATUS) or (target^.status = C_Status.ANIMATED)) and
      (target^.stats[C_Stat.CONSTITUTION].base > 0) and (target^.race <> C_Race.ELF) then begin
    GDVars.effectBusy := 1;
    FxEngine.RemoveEffect(target, C_Effect.POISONED, nil);
    GDVars.effectBusy := 0;
    target^.status := C_Status.OKAY;
    target^.inPlay := 1;
    Dec(target^.stats[C_Stat.CONSTITUTION].base);
    FxEngine.RecalcAbility(target, C_Stat.CONSTITUTION);
    target^.hpCur := 1;
    CharHlp.PrintCreatureMessage(target, 'is raised', 10, 1)
  end
end;

procedure SpellSlayLiving;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  GDVars.effectMask := $40;
  GDVars.pendingDamage := 67;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, target);
  if GDVars.pendingDamage <> 0 then begin
    if (not Boolean(FxEngine.RollSavingThrow(target, 4, 0))) and ((target^.immunities and 8) = 0) then
      FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'is slain')
    else begin
      GDVars.effectMask := 8;
      FxEngine.InflictNonWeaponDamage(target, FxEngine.RollDamageDice(2, 8) + 1, 0, 0)
    end
  end else
    CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
end;

procedure SpellEntangle;
var
  target: Types.PCharacter;
  i: Byte;
  saved: Boolean;
begin
  GDVars.effectInProgress := 1;
  if (GDVars.gameState^.location = 0) or (GDVars.gameState^.overMap = 1) then
    for i := 1 to GDVars.castTargetCount do
      if GDVars.spellTargets[i] <> nil then begin
        target := GDVars.spellTargets[i];
        saved := Boolean(FxEngine.RollSavingThrow(target, 4, 0));
        FxEngine.AddEffectWithMessage(target, C_Effect.CONFUSED_LOSE_TURN, Magic.CalcSpellDuration(78), 0, 0, 1,
                                      Byte(saved), 'is entangled')
      end;
  GDVars.effectInProgress := 0
end;

procedure SpellFaerieFire;
begin
  Magic.ApplyEffectToTargets(0, 'is highlighted')
end;

procedure SpellInvisibilityToAnimals;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is invisible')
end;

procedure SpellCharmMonsters;
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  iTail: array[0..2] of Byte;
  effect: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  charmInfo: array[0..1] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  charmInfoTail: Byte;
begin
  Magic.ApplyEffectToTargets(0, 'is charmed');
  for i := 1 to GDVars.castTargetCount do
    if CharHlp.HasEffect(GDVars.spellTargets[i], C_Effect.CHARM, effect) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.spellTargets[i], effect, False)
end;

procedure SpellConfusion;
var
  i: Byte;
  saved: Boolean;
  target: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  eff: array[0..3] of Byte;
  maxTargets: Byte;
begin
  GDVars.effectInProgress := 1;
  maxTargets := FxEngine.RollDice(2, 8);
  if GDVars.castTargetCount > maxTargets then GDVars.castTargetCount := maxTargets;
  for i := 1 to GDVars.castTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      target := GDVars.spellTargets[i];
      saved := Boolean(FxEngine.RollSavingThrow(target, 4, 0));
      FxEngine.AddEffectWithMessage(target, C_Effect.CONFUSED, Magic.CalcSpellDuration(82), 0, 0, 1, Byte(saved),
                                    'is confused')
    end;
  GDVars.effectInProgress := 0
end;

procedure SpellDimensionDoor;
var
  caster: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  target: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  locationOk: Boolean;
  effect: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  caster := GDVars.curChar;
  if CharHlp.HasEffect(caster, C_Effect.CANNOT_MOVE, effect) then begin
    FxEngine.RemoveEffect(caster, C_Effect.CANNOT_MOVE, nil);
    CharHlp.PrintCreatureMessage(caster, 'is free to move', 10, 1);
    TextRend.PauseOnly
  end;
  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(caster));
  locationOk := CbtMap.IsValidCreatureLoc(caster, GDVars.targetCoordX, GDVars.targetCoordY, False);
  CbtMap.ScrollView(CbtMap.CombatCellX(caster), CbtMap.CombatCellY(caster), 0, C_Dir.CENTER);
  CharHlp.PrintCreatureMessage(caster, 'teleports', 10, 1)
end;

procedure SpellFear;
var
  caster: Types.PCharacter;
  target: Types.PCharacter;
  i: Byte;
  saved: Boolean;
  effect: Pointer;
begin
  GDVars.effectInProgress := 1;
  caster := GDVars.curChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(caster), CbtMap.CombatCellY(caster), GDVars.targetCoordX,
                           GDVars.targetCoordY, 3, 6);
  for i := 1 to GDVars.castTargetCount do begin
    target := GDVars.spellTargets[i];
    saved := Boolean(FxEngine.RollSavingThrow(target, 4, 0));
    if not saved then begin
      FxEngine.AddEffectWithMessage(target, C_Effect.FRIGHTENED, Magic.CalcSpellDuration(84), 0, 1, 1, Byte(saved),
                                    'runs in terror');
      if CharHlp.HasEffect(target, C_Effect.FRIGHTENED, effect) then begin
        target^.combatAddr^.turned := 1;
        target^.quickfight := 1;
        if target^.npc <= $7F then target^.npc := C_Npc.ANIMATED_PLAYER;
        target^.combatAddr^.other := nil
      end
    end else
      CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
  end;
  GDVars.effectInProgress := 0
end;

procedure SpellFireShield;
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
  done: Boolean;
  eff: Pointer;
begin
  done := False;
  repeat
    if GDVars.curChar^.quickfight <> 0 then
      ch := Chr(FxEngine.RollDice(1, 2) - 1)
    else begin
      MenuCore.ResetMenuSlots(1);
      ch := MenuCore.MenuHorizontal(GDConsts.flameTypePrompt, GDConsts.hotColdMenu, 0, 0)
    end;
    case Ord(ch) of
      0: begin
        FxEngine.AddEffectWithMessage(GDVars.curChar, C_Effect.FIRE_SHIELD_HOT, Magic.CalcSpellDuration(85), 0, 0, 0,
                                      0, GDConsts.isText + GDConsts.protectedWord);
        if CharHlp.HasEffect(GDVars.curChar, C_Effect.FIRE_SHIELD_HOT, eff) then
          FxEngine.AddEffectWithMessage(GDVars.curChar, C_Effect.FIRE_SHIELD, Magic.CalcSpellDuration(85), 0, 0, 0, 0,
                                        '');
        done := True
      end;
      1: begin
        FxEngine.AddEffectWithMessage(GDVars.curChar, C_Effect.FIRE_SHIELD_COLD, Magic.CalcSpellDuration(85), 0, 0, 0,
                                      0, GDConsts.isText + GDConsts.protectedWord);
        if CharHlp.HasEffect(GDVars.curChar, C_Effect.FIRE_SHIELD_COLD, eff) then
          FxEngine.AddEffectWithMessage(GDVars.curChar, C_Effect.FIRE_SHIELD, Magic.CalcSpellDuration(85), 0, 0, 0, 0,
                                        '');
        done := True
      end else
      done := MenuCore.YesNoMenu(GDConsts.abortSpellPrompt, GDConsts.yesChoice) = GDConsts.yesChoice
    end
  until done
end;

procedure SpellFumble;
var
  target: Types.PCharacter;
  effect: Pointer;
begin
  target := GDVars.spellTargets[1];
  GDVars.effectMask := $40;
  if not Boolean(FxEngine.RollSavingThrow(target, 4, 0)) then begin
    FxEngine.AddEffectWithMessage(target, C_Effect.CONFUSED_LOSE_TURN, Magic.CalcSpellDuration(86), 0, 0, 0, 0,
                                  'is clumsy');
    if CharHlp.HasEffect(target, C_Effect.CONFUSED_LOSE_TURN, effect) then
      FxEngine.CallEffectHandler(C_Effect.CONFUSED_LOSE_TURN, target, nil, False)
  end else begin
    FxEngine.AddEffectWithMessage(target, C_Effect.SLOWED, Magic.CalcSpellDuration(86), 0, 0, 0, 0, 'is slowed');
    if CharHlp.HasEffect(target, C_Effect.SLOWED, effect) then
      FxEngine.CallEffectHandler(C_Effect.SLOWED, target, nil, False)
  end;
  Magic.ResolveSpell(GDVars.opMode, 0, True, 0, 0, 'is clumsy')
end;

procedure SpellIceStorm;
begin
  GDVars.effectInProgress := 1;
  Magic.ResolveSpell(GDVars.opMode, 0, False, FxEngine.RollDamageDice(3, 10), 10, '')
end;

procedure SpellMinorGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is protected')
end;

procedure SpellBarkskin;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is toughened')
end;

procedure SpellConeOfCold;
var
  caster: Types.PCharacter;
  reach: Byte;
  lvl: Byte;
begin
  GDVars.effectInProgress := 1;
  caster := GDVars.curChar;
  lvl := CharHlp.GetCasterLevel(GDVars.opMode, False);
  reach := (CharHlp.GetCasterLevel(GDVars.opMode, False) + 1) shr 1;
  if reach < 1 then reach := 1;
  Magic.CollectConeTargets(CbtMap.CombatCellX(caster), CbtMap.CombatCellY(caster), GDVars.targetCoordX,
                           GDVars.targetCoordY, 2, reach);
  Magic.ResolveSpell(GDVars.opMode, 0, False, lvl + FxEngine.RollDamageDice(lvl, 4), 10, '')
end;

procedure SpellFeeblemind;
var
  i: Byte;
  saved: Byte;
  target: Types.PCharacter;
  effect: Pointer;
begin
  target := GDVars.spellTargets[1];
  saved := target^.saves[4];
  case target^.charClass of
    C_Class.CLERIC: Dec(target^.saves[4]);
    C_Class.MAGE: Inc(target^.saves[4], 4)
  else
    Inc(target^.saves[4], 2)
  end;
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, '');
  if CharHlp.HasEffect(target, C_Effect.FEEBLEMIND, effect) then begin
    FxEngine.CallEffectHandler(C_Effect.FEEBLEMIND, target, nil, False);
    for i := 0 to 140 do
      if (target^.memorized[i] and C_Spell.PENDING_FLAG) <> 0 then
        target^.memorized[i] := 0
  end;
  target^.saves[4] := saved
end;

procedure SpellScrollOfProtection;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, '')
end;

procedure SpellCharmPersonOrMammal;
var
  effect: Pointer;
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if target <> nil then
    if not ((target^.race >= C_Race.MONSTER) and ((target^.creatureType and 2) = 0)) then begin
      Magic.ResolveSpell(GDVars.opMode, GDVars.curChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.opMode, True),
                         True, 0, 0, GDConsts.isText + GDVars.effectNames^[C_Effect.CHARM]);
      if CharHlp.HasEffect(target, C_Effect.CHARM, effect) then
        FxEngine.CallEffectHandler(C_Effect.CHARM, target, effect, False)
    end else
      CharHlp.PrintCreatureMessage(target, GDConsts.isText + 'not ' + GDVars.effectNames^[C_Effect.CHARM],
                                   10, 1)
end;

procedure SpellPotionOfInvisibility;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, '')
end;

procedure SpellDruidCureLightWounds;
begin
  if GDVars.castTargetCount = 0 then Exit;
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(1, 8), False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargets[1])
end;

procedure SpellPotionOfExtraHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], True, 'is Healed')
end;

procedure SpellMageBestowCurse;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, '')
end;

procedure SpellRestoration;
var
  cls: ShortInt;
  i: ShortInt;
  minXp: LongInt;
  target: Types.PCharacter;
  diff: Byte;
  gain: Byte;
  lostLevels: Byte;
  bonus: Byte;
  classCount: Byte;
begin
  lostLevels := 0;
  target := GDVars.spellTargets[1];
  cls := C_Class.NO_CLASS;
  minXp := $7FFFFFFF;
  classCount := 0;
  for i := C_Class.CLERIC to C_Class.THIEF do
    if target^.classLevelCap[i] > 0 then Inc(classCount);
  for i := C_Class.CLERIC to C_Class.THIEF do
    if target^.classLevels[i] < target^.classLevelCap[i] then begin
      diff := target^.classLevelCap[i] - target^.classLevels[i];
      Inc(lostLevels, diff);
      if ClassCal.XpForLevel(Types.PCharacter(target), Succ(target^.classLevels[i]), i) <= minXp then begin
        minXp := ClassCal.XpForLevel(Types.PCharacter(target), Succ(target^.classLevels[i]), i);
        cls := i
      end
    end;
  if cls <> C_Class.NO_CLASS then begin
    if target^.hpMax < target^.savedHpMax then begin
      gain := (target^.savedHpMax - target^.hpMax) div lostLevels;
      if target^.classLevels[cls] + 1 < GDConsts.hitDiceLevelCap[cls] then
        bonus := CharHlp.ClassConAdj(target, cls) div classCount
      else
        bonus := 0;
      Inc(target^.hpCur, gain);
      Inc(target^.hpRolled, gain - bonus);
      Inc(target^.hpMax, gain)
    end;
    Inc(target^.classLevels[cls]);
    ClassCal.RecalcClassStats(Types.PCharacter(target));
    if (lostLevels = 1) and (target^.experience < target^.savedExperience) then
      target^.experience := target^.savedExperience
    else
      target^.experience := minXp
  end;
  target^.displayHighlight := Byte(CharHlp.CanLevelUp(target))
end;

procedure SpellEnergyDrain;
begin
  GDVars.curChar^.combatAddr^.other := GDVars.spellTargets[1];
  GDVars.effectHandlers[C_Effect.DRAIN_ONE_LEVEL](Pointer(GDVars.curChar), nil, False)
end;

procedure SpellDestruction;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  GDVars.effectMask := $48;
  GDVars.pendingDamage := $FF;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, target);
  if ((target^.immunities and 8) = 0) and (GDVars.pendingDamage <> 0) then
    FxEngine.KillCreature(target, C_Status.GONE, 'is destroyed')
  else
    CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
end;

procedure SpellResurrection;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if (target^.status = C_Status.DEAD_STATUS) and (target^.stats[C_Stat.CONSTITUTION].base > 0) and
      (target^.race > C_Race.ELF) then begin
    FxEngine.RemoveEffect(target, C_Effect.POISONED, nil);
    target^.status := C_Status.OKAY;
    target^.inPlay := 1;
    target^.hpCur := target^.hpMax;
    CharHlp.PrintCreatureMessage(target, GDConsts.isText + 'ressurected', 10, 1)
  end
end;

procedure SpellHoldAnimal;
var
  saveMod: ShortInt;
begin
  case GDVars.castTargetCount of
    1: saveMod := -4;
    2: saveMod := -2;
    3: saveMod := -1
  else
    saveMod := 0
  end;
  Magic.ApplyEffectToTargets(saveMod, 'is held')
end;

procedure SpellProtectionFromFire;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  if target <> nil then
    if ClassCal.EffectiveClassLevel(Types.PCharacter(target), C_Class.RANGER) > 0 then
      FxEngine.AddEffectWithMessage(target, C_Effect.RESIST_FIRE_DRUID, 0, CharHlp.GetCasterLevel(109, False), 0, 0,
                                    0, GDConsts.isText + GDConsts.protectedWord)
    else
      FxEngine.AddEffectWithMessage(target, C_Effect.RESIST_FIRE, Magic.CalcSpellDuration(109),
                                    ClassCal.EffectiveClassLevel(Types.PCharacter(target), C_Class.RANGER), 0,
                                    0, 0, GDConsts.isText + GDConsts.protectedWord)
end;

procedure SpellDeathSpell;
var
  target: Types.PCharacter;
  i: Byte;
begin
  GDVars.effectInProgress := 1;
  GDVars.effectMask := $40;
  GDVars.spellTempsView[0] := FxEngine.RollDice(4, 20) * 2;
  for i := 1 to GDVars.castTargetCount do begin
    target := GDVars.spellTargets[i];
    case target^.hitDice of
      0: GDVars.spellTempsView[1] := 1;
      1: GDVars.spellTempsView[1] := 2;
      2..3: GDVars.spellTempsView[1] := 8;
      4..5: GDVars.spellTempsView[1] := 16;
      6: if target^.hpMax <= 51 then GDVars.spellTempsView[1] := 16
         else GDVars.spellTempsView[1] := 20;
      7..8: GDVars.spellTempsView[1] := 20
    else
      GDVars.spellTempsView[1] := 162
    end;
    GDVars.pendingDamage := 100;
    FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, target);
    if ((target^.immunities and 8) = 0) and (GDVars.pendingDamage <> 0) and
        (GDVars.spellTempsView[0] >= GDVars.spellTempsView[1]) then begin
      Dec(GDVars.spellTempsView[0], GDVars.spellTempsView[1]);
      FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'drops dead')
    end else
      GDVars.spellTargets[i] := nil
  end
end;

procedure SpellDisintegrate;
var
  saved: Boolean;
  target: Types.PCharacter;
begin
  GDVars.effectMask := $48;
  target := GDVars.spellTargets[1];
  GDVars.pendingDamage := $FF;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, target);
  if GDVars.pendingDamage <> 0 then begin
    saved := Boolean(FxEngine.RollSavingThrow(target, 4, 0));
    if not saved then begin
      FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'disintegrates');
      while target^.items <> nil do
        CharHlp.RemoveItem(target, target^.items)
    end else
      CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
  end else
    CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
end;

procedure SpellGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, GDConsts.isText + 'protected')
end;

procedure SpellStoneToFlesh;
var
  target: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  key: Byte;
  i: Byte;
  j: Byte;
  effect: Pointer;
begin
  target := GDVars.spellTargets[1];
  if (target^.status = C_Status.OKAY) and CharHlp.HasEffect(target, Magic.EFF_STONE_FLESH_KILLS, effect) then
    FxEngine.KillCreature(target, C_Status.DEAD_STATUS, 'is killed')
  else if (target^.status = C_Status.OKAY) and
    CharHlp.HasEffect(target, C_Effect.STONE_CREATURE, effect) then begin
    if Types.PEffect(effect)^.strength = $FF then begin
      CharHlp.PrintCreatureMessage(target, 'becomes flesh', 10, 0);
      Types.PEffect(effect)^.strength := 1
    end else
      CharHlp.PrintCreatureMessage(target, 'is still flesh', 10, 0)
  end else begin
    if target^.status = C_Status.PETRIFIED then begin
      target^.status := C_Status.OKAY;
      target^.inPlay := 1;
      target^.hpCur := 1;
      CharHlp.PrintCreatureMessage(target, GDConsts.isText + 'no longer a statue', 10, 0);
      if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
        i := 1;
        while GDVars.downed[i].cr <> target do Inc(i);
        GDVars.combatMap^.cells[GDVars.downed[i].y, GDVars.downed[i].x] := GDVars.downed[i].terrain;
        for j := i to GDVars.downedCount - 1 do
          GDVars.downed[j] := GDVars.downed[j + 1];
        Dec(GDVars.downedCount);
        if CbtMap.IsValidCreatureLoc(target, CbtMap.CombatCellX(target), CbtMap.CombatCellY(target), True) then
          CbtMap.ScrollView(GDVars.targetCoordX, GDVars.targetCoordY, 0, C_Dir.CENTER)
      end
    end;
    Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, '')
  end;
end;

procedure SpellFleshToStone;
var
  saved: Boolean;
  target: Types.PCharacter;
begin
  GDVars.effectMask := $40;
  target := GDVars.spellTargets[1];
  GDVars.pendingDamage := $FF;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, target);
  if GDVars.pendingDamage <> 0 then begin
    saved := Boolean(FxEngine.RollSavingThrow(target, 4, 0));
    if not saved then
      FxEngine.KillCreature(target, C_Status.PETRIFIED, GDConsts.isText + 'turned to stone')
  end
end;

procedure SpellMassInvisibility;
var
  i: Byte;
begin
  GDVars.effectInProgress := 1;
  for i := 1 to GDVars.castTargetCount do begin
    if (GDVars.spellTargets[i]^.side <> GDVars.curChar^.side) or
        ((GDVars.locState.current = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargets[i], 1, False) > 0)) then
      GDVars.spellTargets[i] := nil
  end;
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0,
                     GDConsts.isText + GDVars.effectNames^[C_Effect.INVISIBLE])
end;

procedure SpellPowerWordStun;
var
  duration: Byte;
  target: Types.PCharacter;
begin
  GDVars.effectInProgress := 1;
  target := GDVars.spellTargets[1];
  case target^.hpCur of
    1..30: duration := FxEngine.RollDice(4, 4);
    31..60: duration := FxEngine.RollDice(2, 4);
    61..90: duration := FxEngine.RollDice(1, 4)
  else
    duration := 0
  end;
  FxEngine.AddEffectWithMessage(target, GDConsts.spellTable[117].effectId, duration, CharHlp.GetCasterLevel(117, True),
                                0, GDConsts.spellTable[117].saveEffect, 0,
                                GDConsts.isText + GDVars.effectNames^[C_Effect.STUNNED])
end;

procedure SpellFireTouch;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is covered in flame')
end;

procedure SpellIronSkin;
begin
  Magic.ResolveSpell(GDVars.opMode, 0, False, 0, 0, 'is protected')
end;

procedure SpellMassCharm;
var
  effect: Pointer;
  target: Types.PCharacter;
  done: Boolean;
  i: Byte;
  cost: Byte;
  total: Byte;
  limit: Byte;
begin
  GDVars.effectInProgress := 1;
  done := False;
  total := 0;
  i := 1;
  limit := CharHlp.GetCasterLevel(GDVars.opMode, False) * 2;
  while (i <= GDVars.castTargetCount) and not done do begin
    target := GDVars.spellTargets[i];
    if target <> nil then
      if ((target^.immunities and 2) = 0) or (target^.iconDimensions > 1) or
          (target^.side = GDVars.curChar^.side) then
        CharHlp.PrintCreatureMessage(target, 'is unaffected', 10, 1)
      else begin
        cost := target^.hitDice;
        if cost + total <= limit then begin
          Inc(total, cost);
          done := total = limit;
          FxEngine.AddEffectWithMessage(target, C_Effect.CHARM, Magic.CalcSpellDuration(GDVars.opMode),
                                        GDVars.curChar^.side * 128 + CharHlp.GetCasterLevel(GDVars.opMode, True), 1,
                                        1, FxEngine.RollSavingThrow(target, 4, -2), 'is charmed');
          if CharHlp.HasEffect(target, C_Effect.CHARM, effect) then
            FxEngine.CallEffectHandler(C_Effect.CHARM, target, effect, False)
        end
      end;
    Inc(i)
  end
end;

procedure SpellIrresistibleDance;
var
  target: Types.PCharacter;
begin
  target := GDVars.spellTargets[1];
  CharHlp.RecalcStats(target);
  FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, target);
  if FxEngine.AttackRoll(GDVars.curChar, target, target^.acCur[0]) then begin
    FxEngine.AddEffectWithMessage(target, C_Effect.CONFUSED_LOSE_TURN, Magic.CalcSpellDuration(121),
                                  CharHlp.GetCasterLevel(121, True), 0, 0, 0, GDConsts.emptyQuery);
    FxEngine.AddEffectWithMessage(target, C_Effect.DANCING, Magic.CalcSpellDuration(121),
                                  CharHlp.GetCasterLevel(121, True), 0, 0, 0, 'begins to dance wildly')
  end
end;

procedure SpellPowerWordBlind;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
  target: Types.PCharacter;
  duration: Byte;
  i: Byte;
  totalHp: Byte;
begin
  GDVars.effectInProgress := 1;
  i := 1;
  totalHp := 0;
  while (i <= GDVars.castTargetCount) and (totalHp <= 100) do begin
    target := GDVars.spellTargets[i];
    if (target^.hpMax <= 100) and (target^.hpMax + totalHp <= 100) then
      Inc(totalHp, target^.hpMax);
    Inc(i)
  end;
  duration := FxEngine.RollDice(1, 4) + 1;
  if totalHp < 51 then
    duration := duration * 10;
  i := 1;
  totalHp := 0;
  while (i <= GDVars.castTargetCount) and (totalHp <= 100) do begin
    target := GDVars.spellTargets[i];
    if (target^.hpMax <= 100) and (target^.hpMax + totalHp <= 100) then begin
      Inc(totalHp, target^.hpMax);
      FxEngine.AddEffectWithMessage(target, C_Effect.BLIND, Magic.CalcSpellDuration(GDVars.opMode), 0, 0, 0, 0,
                                    'is blinded')
    end;
    Inc(i)
  end
end;

procedure SpellMeteorSwarm;
var
  caster: Types.PCharacter;
  origX: ShortInt;
  origY: ShortInt;
  casterX: ShortInt;
  casterY: ShortInt;
  newX: ShortInt;
  newY: ShortInt;
  dir: Byte;
  oldCount: Byte;
  mode: Byte;
  i: Byte;
  reach: Word;
  ok: Boolean;

  { Picks a meteor's landing cell for a direction and mode, and tells whether the caster can see it. }
  function TryAim(direction, mode: Byte): Boolean;
  begin
    reach := $FF;
    case direction of
      1: begin
           newX := origX + GDConsts.aimDeltaX[mode];
           newY := origY + GDConsts.aimDeltaY[mode]
         end;
      2: newX := origX;
      3: begin
           newX := origX + GDConsts.aimDeltaX[mode];
           newY := origY
         end;
      4: newX := origX
    end;
    TryAim := Pathing.WalkLine(casterX, casterY, newX, newY, reach);
    reach := reach div 2
  end;

begin
  GDVars.effectInProgress := 1;
  GDVars.effectMask := 9;
  caster := GDVars.curChar;
  casterX := CbtMap.CombatCellX(caster);
  casterY := CbtMap.CombatCellY(caster);
  origX := GDVars.targetCoordX;
  origY := GDVars.targetCoordY;
  for mode := 1 to 4 do begin
    GameIo.ZeroFill(GDVars.spellTargets, SizeOf(GDVars.spellTargets));
    i := 1;
    repeat
      ok := TryAim(i, mode);
      Inc(i)
    until (i > 4) or ok;
    while not Pathing.IsDirToward(casterX, casterY, GDVars.targetCoordX, GDVars.targetCoordY, dir) do Inc(dir);
    GDVars.combatGfxOn := 1;
    CbtMap.SetCreatureFacing(caster, dir, 1, 0);
    Blit.BuildIconFrames(30);
    CharHlp.BuildIconFacingsDir(dir, 30);
    CharHlp.CombatAnimateMovingIcon(casterX, casterY, newX, newY, 1, 30);
    GDVars.targetCoordX := newX;
    GDVars.targetCoordY := newY;
    CharHlp.ScatterCombatIcon(1, 23, Byte(GDConsts.soundIds[9]));
    Magic.CollectConeTargets(casterX, casterY, newX, newY, 1, Byte(reach));
    oldCount := GDVars.castTargetCount;
    Pathing.BuildTargetList(newX, newY, 1, $FF, 1);
    for i := 1 to GDVars.targetCount do begin
      Inc(GDVars.castTargetCount);
      GDVars.spellTargets[GDVars.castTargetCount] := GDVars.creatureArr[GDVars.rankedTargets[i].entity]
    end;
    for i := 1 to GDVars.castTargetCount do
      if (GDVars.spellTargets[i] <> nil) and (GDVars.spellTargets[i]^.inPlay <> 0) then
        if i <= oldCount then
          FxEngine.InflictNonWeaponDamage(GDVars.spellTargets[i], FxEngine.RollDamageDice(10, 4), 0, 0)
        else
          FxEngine.InflictNonWeaponDamage(GDVars.spellTargets[i], FxEngine.RollDamageDice(10, 4), 2,
                                          FxEngine.RollSavingThrow(GDVars.spellTargets[i], 4, 0));
    if CbtMap.CombatIconVisible(caster, 0) then begin
      CbtMap.SetCreatureFacing(caster, caster^.combatAddr^.direction, 1, 1);
      CbtMap.SetCreatureFacing(caster, caster^.combatAddr^.direction, 0, 0)
    end
  end
end;

procedure SpellPowerWordKill;
var
  i: Byte;
begin
  GDVars.effectInProgress := 1;
  if GDVars.castTargetCount > 0 then
    if (GDVars.spellTargets[1] <> nil) and (GDVars.spellTargets[1]^.hpMax <= 60) and
        (GDVars.spellTargets[1]^.hpMax > 10) then begin
      GDVars.pendingDamage := $FF;
      FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, GDVars.spellTargets[1]);
      if GDVars.pendingDamage <> 0 then
        FxEngine.KillCreature(GDVars.spellTargets[1], C_Status.DEAD_STATUS, 'is slain')
    end else
      for i := 1 to GDVars.castTargetCount do
        if (GDVars.spellTargets[i] <> nil) and (GDVars.spellTargets[i]^.hpMax <= 10) then begin
          GDVars.pendingDamage := $FF;
          FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, GDVars.spellTargets[i]);
          if GDVars.pendingDamage <> 0 then
            FxEngine.KillCreature(GDVars.spellTargets[i], C_Status.DEAD_STATUS, 'is slain')
        end
end;

procedure SpellMonsterSummoning;
var
  x: ShortInt;
  y: ShortInt;
  newX: ShortInt;
  newY: ShortInt;
  dir: ShortInt;
  candidate: Types.PCharacter;
  walker: Types.PCharacter;
  done: Boolean;
  found: Boolean;
  placed: Byte;
  terrainIndex: Byte;
  creatureIndex: Byte;
  wantedTerrain: Byte;
  slot: Byte;
begin
  walker := GDVars.partyHead;
  candidate := GDVars.partyHead;
  done := False;
  dir := C_Dir.NORTH;
  placed := 0;
  if (GDVars.gameState^.location <> 0) and (GDVars.gameState^.overMap = 0) then
    wantedTerrain := 23
  else wantedTerrain := 69;
  while (walker <> nil) and (walker^.status <> 9) do
    walker := walker^.next;
  repeat
    if dir > C_Dir.NORTHWEST then begin
      if (candidate = nil) or (candidate^.next = nil) or (candidate^.status = 9) then begin
        candidate := GDVars.curChar;
        done := True
      end else
        candidate := candidate^.next;
      dir := C_Dir.NORTH
    end;
    if (walker = nil) or (placed = 2) then
      done := True
    else begin
      walker^.side := GDVars.curChar^.side;
      x := CbtMap.CombatCellX(candidate);
      y := CbtMap.CombatCellY(candidate);
      found := False;
      repeat
        newX := x + GDConsts.dirDx[dir];
        newY := y + GDConsts.dirDy[dir];
        if (newX <= 49) and (newX >= 0) and (newY <= 24) and (newY >= 0) then begin
          CbtMap.GetArenaContents(newX, newY, creatureIndex, terrainIndex);
          if (creatureIndex = 0) and (terrainIndex = wantedTerrain) then begin
            slot := CbtMap.CombatSlot(walker);
            GDVars.actor[slot].size := walker^.iconDimensions and 7;
            GDVars.actor[slot].x := newX;
            GDVars.actor[slot].y := newY;
            found := FxEngine.ReviveDeadCreature(walker, walker^.hpMax, 'gates in');
            if found then begin
              Inc(placed);
              walker := walker^.next;
              if (walker = nil) or (walker^.status <> 9) then done := True
            end
          end;
          Inc(dir)
        end
      until found or (dir > 7)
    end
  until done;
  if placed = 0 then
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'summons is not answered', 10, 1)
end;

procedure EffBreathePoison(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  x: ShortInt;
  y: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  targetCell: array[1..2] of Byte;
  accepted: Boolean;
  saved: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  target: Types.PCharacter;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  retained: array[1..30] of Byte;
  dir: Byte;
begin
  GDVars.effectInProgress := 1;
  if GDVars.cbRoundCounter = 0 then
    Types.PEffect(eff)^.strength := 3;
  if Types.PEffect(eff)^.strength > 0 then begin
    x := CbtMap.CombatCellX(cr);
    y := CbtMap.CombatCellY(cr);
    GDVars.spellFns.selectTarget(61, 1, accepted);
    if accepted then begin
      Magic.CollectConeTargets(x, y, GDVars.targetCoordX, GDVars.targetCoordY, $FF, 3);
      if GDVars.castTargetCount > 0 then begin
        GDVars.effectMask := $20;
        CharHlp.PrintCreatureMessage(cr, 'breathes poison', 10, 1);
        dir := CbtMap.DirectionToward(cr, GDVars.spellTargets[1]);
        CharHlp.CombatPrintCreatureInfo(cr);
        CbtMap.SetCreatureFacing(cr, dir, 1, 0);
        Blit.BuildIconFrames(17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                        CbtMap.CombatCellX(GDVars.spellTargets[1]),
                                        CbtMap.CombatCellY(GDVars.spellTargets[1]), 1, 30);
        for i := 1 to GDVars.castTargetCount do
          if GDVars.spellTargets[i] <> nil then begin
            target := GDVars.spellTargets[i];
            saved := Boolean(FxEngine.RollSavingThrow(target, 3, 0));
            FxEngine.InflictNonWeaponDamage(target, Types.PCharacter(cr)^.hpMax, 2, Byte(saved))
          end;
        Dec(Types.PEffect(eff)^.strength);
        actionsEnded := CharHlp.EndActions(cr)
      end
    end
  end;
  GDVars.effectInProgress := 0
end;

procedure EffBreatheLightning(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  x: ShortInt;
  y: ShortInt;
  dir: Byte;
begin
  if (GDVars.cbRoundCounter = 0) or (Types.PEffect(eff)^.strength > 3) then
    Types.PEffect(eff)^.strength := 3;
  if Types.PEffect(eff)^.strength > 0 then begin
    GDVars.effectMask := $24;
    x := CbtMap.CombatCellX(cr);
    y := CbtMap.CombatCellY(cr);
    GDVars.spellFns.selectTarget(51, 1, GDVars.targetSelected);
    if GDVars.targetSelected then begin
      CharHlp.PrintCreatureMessage(cr, 'breathes lightning', 10, 1);
      dir := CbtMap.DirectionToward(cr, GDVars.spellTargets[1]);
      CharHlp.CombatPrintCreatureInfo(cr);
      CbtMap.SetCreatureFacing(cr, dir, 1, 0);
      Blit.BuildIconFrames(18);
      CharHlp.CombatAnimateMovingIcon(x, y, GDVars.targetCoordX, GDVars.targetCoordY, 4, 50);
      Magic.LightningPath(9, Types.PCharacter(cr)^.hpMax, False);
      Dec(Types.PEffect(eff)^.strength);
      actionsEnded := CharHlp.EndActions(cr)
    end
  end
end;

procedure EffDragonBreath(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  actionsEnded: Boolean;
  x: ShortInt;
  y: ShortInt;
  i: Byte;
  target: Types.PCharacter;
  saved: Boolean;
  rays: Byte;
  reach: Byte;
  elementName: String[20];
  breathDamage: Word;
  dir: Byte;
begin
  GDVars.effectInProgress := 1;
  if (GDVars.cbRoundCounter = 0) or (Types.PEffect(eff)^.strength > 3) then
    Types.PEffect(eff)^.strength := 3;
  if Types.PEffect(eff)^.strength > 0 then begin
    breathDamage := Types.PCharacter(cr)^.hpMax;
    case Types.PEffect(eff)^.id of
      C_Effect.RED_DRAGON_BREATH, C_Effect.BIG_RED_DRAGON_BREATH:
        begin
          GDVars.effectMask := $21;
          rays := 3;
          reach := 9;
          elementName := 'Fire';
          if Types.PEffect(eff)^.id = C_Effect.BIG_RED_DRAGON_BREATH then
            breathDamage := FxEngine.RollDamageDice(24, 10) + 12
        end;
      C_Effect.WHITE_DRAGON_BREATH:
        begin
          GDVars.effectMask := $22;
          rays := 3;
          reach := 7;
          elementName := 'cold'
        end;
      C_Effect.BLACK_DRAGON_BREATH:
        begin
          GDVars.effectMask := $20;
          rays := 1;
          reach := 6;
          elementName := 'acid'
        end
    end;
    x := CbtMap.CombatCellX(cr);
    y := CbtMap.CombatCellY(cr);
    GDVars.spellFns.selectTarget(23, 1, GDVars.targetSelected);
    if GDVars.targetSelected then begin
      Magic.CollectConeTargets(x, y, GDVars.targetCoordX, GDVars.targetCoordY, rays, reach);
      for i := 1 to GDVars.castTargetCount do
        if ShortInt(CharHlp.EnemyTeam(cr)) <> GDVars.spellTargets[i]^.side then
          GDVars.targetSelected := False;
      if (GDVars.castTargetCount > 0) and GDVars.targetSelected then begin
        CharHlp.PrintCreatureMessage(cr, 'breathes ' + elementName, 10, 1);
        dir := CbtMap.DirectionToward(cr, GDVars.spellTargets[1]);
        CharHlp.CombatPrintCreatureInfo(cr);
        CbtMap.SetCreatureFacing(cr, dir, 1, 0);
        Blit.BuildIconFrames(17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                        CbtMap.CombatCellX(GDVars.spellTargets[1]),
                                        CbtMap.CombatCellY(GDVars.spellTargets[1]), 1, 30);
        for i := 1 to GDVars.castTargetCount do
          if GDVars.spellTargets[i] <> nil then begin
            target := GDVars.spellTargets[i];
            saved := Boolean(FxEngine.RollSavingThrow(target, 3, 0));
            FxEngine.InflictNonWeaponDamage(target, breathDamage, 2, Byte(saved))
          end;
        Dec(Types.PEffect(eff)^.strength);
        actionsEnded := CharHlp.EndActions(cr)
      end
    end
  end;
  GDVars.effectInProgress := 0
end;

procedure EffGazeCharm(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  accepted: Boolean;
  dir: Byte;
begin
  GDVars.spellFns.selectTarget(10, 1, accepted);
  if not accepted then Exit;
  GDVars.effectInProgress := 1;
  GDVars.effectMask := $10;
  CharHlp.PrintCreatureMessage(cr, 'gazes', 10, 1);
  dir := CbtMap.DirectionToward(cr, GDVars.spellTargets[1]);
  CbtMap.SetCreatureFacing(cr, dir, 1, 0);
  Blit.BuildIconFrames(17);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  GDVars.targetCoordX, GDVars.targetCoordY, 4, 50);
  GDVars.opMode := 10;
  GDVars.spellFns.spells[10];
  GDVars.effectInProgress := 0
end;

function ItemReadable(item: Pointer): Boolean;
begin
  if (item <> nil) and ((Types.PItem(item)^.itemType = 39) or (Types.PItem(item)^.itemType = 40)) then
    ItemReadable := True
  else
    ItemReadable := False
end;

procedure RemoveSpellFromScroll(character, item: Pointer; spell: Byte);
var
  spellId: Byte;
  i: Byte;
  found: Byte;
begin
  spellId := spell;
  found := 0;
  for i := 1 to 3 do
    if (Types.PItem(item)^.spells[i] and C_Spell.ID_MASK) = spellId then
      found := i;
  if found = 0 then Exit;
  Types.PItem(item)^.spells[found] := 0;
  if Types.PItem(item)^.nameIds[1] in [100..102] then
    Dec(Types.PItem(item)^.nameIds[1]);
  if (Types.PItem(item)^.spells[1] = 0) and (Types.PItem(item)^.spells[2] = 0) and
      (Types.PItem(item)^.spells[3] = 0) then
    CharHlp.RemoveItem(character, item)
end;

procedure PrintCastSpellMsg(character: Pointer; message: Types.TStr40; spell: Byte);
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(character, 'Casts a Spell', 10, 1);
    Border.EraseBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, Black, 'Spell:' + GDConsts.spellNames[spell])
  end else begin
    Border.EraseBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(character, 1, 19, False);
    TextRend.DisplayString(Length(Types.PCharacter(character)^.name) + 2, 19, LightGreen, Black, message);
    TextRend.DisplayString(1, 20, LightGreen, Black, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow
  end
end;

procedure InitSpellFns;
begin
  GDVars.spellFns.selectTarget := Magic.NoncombatCastTargetMenu;
  GDVars.effectBusy := 0;
  GDVars.usingItem := 0;
  GDVars.viewCharRedraw := 1;
  GDVars.spellFns.spells[1] := Magic.SpellBless;
  GDVars.spellFns.spells[2] := Magic.SpellCurse;
  GDVars.spellFns.spells[3] := Magic.SpellCureLightWounds;
  GDVars.spellFns.spells[4] := Magic.SpellCauseLightWounds;
  GDVars.spellFns.spells[5] := Magic.SpellDetection;
  GDVars.spellFns.spells[6] := Magic.SpellProtection;
  GDVars.spellFns.spells[7] := Magic.SpellProtection;
  GDVars.spellFns.spells[8] := Magic.SpellResistCold;
  GDVars.spellFns.spells[9] := Magic.SpellBurningHands;
  GDVars.spellFns.spells[10] := Magic.SpellCharmPerson;
  GDVars.spellFns.spells[11] := Magic.SpellDetection;
  GDVars.spellFns.spells[12] := Magic.SpellEnlarge;
  GDVars.spellFns.spells[13] := Magic.SpellReduce;
  GDVars.spellFns.spells[14] := Magic.SpellFriends;
  GDVars.spellFns.spells[15] := Magic.SpellMagicMissile;
  GDVars.spellFns.spells[16] := Magic.SpellProtection;
  GDVars.spellFns.spells[17] := Magic.SpellProtection;
  GDVars.spellFns.spells[18] := Magic.SpellDetection;
  GDVars.spellFns.spells[19] := Magic.SpellShield;
  GDVars.spellFns.spells[20] := Magic.SpellShockingGrasp;
  GDVars.spellFns.spells[21] := Magic.SpellSleep;
  GDVars.spellFns.spells[22] := Magic.SpellDetection;
  GDVars.spellFns.spells[23] := Magic.SpellHold;
  GDVars.spellFns.spells[24] := Magic.SpellResistFire;
  GDVars.spellFns.spells[25] := Magic.SpellSilence;
  GDVars.spellFns.spells[26] := Magic.SpellSlowPoison;
  GDVars.spellFns.spells[27] := Magic.SpellSnakeCharm;
  GDVars.spellFns.spells[28] := Magic.SpellSpiritualHammer;
  GDVars.spellFns.spells[29] := Magic.SpellDetection;
  GDVars.spellFns.spells[30] := Magic.SpellInvisibility;
  GDVars.spellFns.spells[31] := Magic.SpellKnock;
  GDVars.spellFns.spells[32] := Magic.SpellMirrorImage;
  GDVars.spellFns.spells[33] := Magic.SpellRayOfEnfeeblement;
  GDVars.spellFns.spells[34] := Magic.SpellStinkingCloud;
  GDVars.spellFns.spells[35] := Magic.SpellStrength;
  GDVars.spellFns.spells[36] := Magic.SpellHeal;
  GDVars.spellFns.spells[37] := Magic.SpellCureBlindness;
  GDVars.spellFns.spells[38] := Magic.SpellCauseBlindness;
  GDVars.spellFns.spells[39] := Magic.SpellCureDisease;
  GDVars.spellFns.spells[40] := Magic.SpellCauseDisease;
  GDVars.spellFns.spells[41] := Magic.SpellDispelMagic;
  GDVars.spellFns.spells[42] := Magic.SpellPrayer;
  GDVars.spellFns.spells[43] := Magic.SpellRemoveCurse;
  GDVars.spellFns.spells[44] := Magic.SpellBestowCurse;
  GDVars.spellFns.spells[45] := Magic.SpellBlink;
  GDVars.spellFns.spells[46] := Magic.SpellDispelMagic;
  GDVars.spellFns.spells[47] := Magic.SpellFireball;
  GDVars.spellFns.spells[48] := Magic.SpellHaste;
  GDVars.spellFns.spells[49] := Magic.SpellHold;
  GDVars.spellFns.spells[50] := Magic.SpellInvisibility;
  GDVars.spellFns.spells[51] := Magic.SpellLightningBolt;
  GDVars.spellFns.spells[52] := Magic.SpellProtection;
  GDVars.spellFns.spells[53] := Magic.SpellProtection;
  GDVars.spellFns.spells[54] := Magic.SpellProtection;
  GDVars.spellFns.spells[55] := Magic.SpellSlow;
  GDVars.spellFns.spells[56] := Magic.SpellHarm;
  GDVars.spellFns.spells[57] := Magic.SpellPotionOfSpeed;
  GDVars.spellFns.spells[58] := Magic.SpellCureSeriousWounds;
  GDVars.spellFns.spells[59] := Magic.SpellGiantStrength;
  GDVars.spellFns.spells[60] := Magic.SpellJavelinOfLightning;
  GDVars.spellFns.spells[61] := Magic.SpellWandOfParalyzation;
  GDVars.spellFns.spells[62] := Magic.SpellPotionOfHealing;
  GDVars.spellFns.spells[63] := Magic.SpellYouth;
  GDVars.spellFns.spells[64] := Magic.SpellFireball;
  GDVars.spellFns.spells[65] := Magic.SpellWandOfMagicMissiles;
  GDVars.spellFns.spells[66] := Magic.SpellCauseSeriousWounds;
  GDVars.spellFns.spells[67] := Magic.SpellNeutralizePoison;
  GDVars.spellFns.spells[68] := Magic.SpellPoison;
  GDVars.spellFns.spells[69] := Magic.SpellProtection;
  GDVars.spellFns.spells[70] := Magic.SpellSticksToSnakes;
  GDVars.spellFns.spells[71] := Magic.SpellCureCriticalWounds;
  GDVars.spellFns.spells[72] := Magic.SpellCauseCriticalWounds;
  GDVars.spellFns.spells[73] := Magic.SpellDispelEvil;
  GDVars.spellFns.spells[74] := Magic.SpellFlameStrike;
  GDVars.spellFns.spells[75] := Magic.SpellRaiseDead;
  GDVars.spellFns.spells[76] := Magic.SpellSlayLiving;
  GDVars.spellFns.spells[77] := Magic.SpellDetection;
  GDVars.spellFns.spells[78] := Magic.SpellEntangle;
  GDVars.spellFns.spells[79] := Magic.SpellFaerieFire;
  GDVars.spellFns.spells[80] := Magic.SpellInvisibilityToAnimals;
  GDVars.spellFns.spells[81] := Magic.SpellCharmMonsters;
  GDVars.spellFns.spells[82] := Magic.SpellConfusion;
  GDVars.spellFns.spells[83] := Magic.SpellDimensionDoor;
  GDVars.spellFns.spells[84] := Magic.SpellFear;
  GDVars.spellFns.spells[85] := Magic.SpellFireShield;
  GDVars.spellFns.spells[86] := Magic.SpellFumble;
  GDVars.spellFns.spells[87] := Magic.SpellIceStorm;
  GDVars.spellFns.spells[88] := Magic.SpellMinorGlobeOfInvulnerability;
  GDVars.spellFns.spells[89] := Magic.SpellRemoveCurse;
  GDVars.spellFns.spells[90] := Magic.SpellBarkskin;
  GDVars.spellFns.spells[91] := Magic.SpellStinkingCloud;
  GDVars.spellFns.spells[92] := Magic.SpellConeOfCold;
  GDVars.spellFns.spells[93] := Magic.SpellFeeblemind;
  GDVars.spellFns.spells[94] := Magic.SpellHold;
  GDVars.spellFns.spells[95] := Magic.SpellScrollOfProtection;
  GDVars.spellFns.spells[96] := Magic.SpellCharmPersonOrMammal;
  GDVars.spellFns.spells[97] := Magic.SpellPotionOfInvisibility;
  GDVars.spellFns.spells[98] := Magic.SpellDruidCureLightWounds;
  GDVars.spellFns.spells[99] := Magic.SpellPotionOfExtraHealing;
  GDVars.spellFns.spells[100] := Magic.SpellMageBestowCurse;
  GDVars.spellFns.spells[101] := Magic.SpellStinkingCloud;
  GDVars.spellFns.spells[102] := Magic.SpellRestoration;
  GDVars.spellFns.spells[103] := Magic.SpellEnergyDrain;
  GDVars.spellFns.spells[104] := Magic.SpellDestruction;
  GDVars.spellFns.spells[105] := Magic.SpellResurrection;
  GDVars.spellFns.spells[106] := Magic.SpellCureDisease;
  GDVars.spellFns.spells[107] := Magic.SpellNeutralizePoison;
  GDVars.spellFns.spells[108] := Magic.SpellHoldAnimal;
  GDVars.spellFns.spells[109] := Magic.SpellProtectionFromFire;
  GDVars.spellFns.spells[110] := Magic.SpellDeathSpell;
  GDVars.spellFns.spells[111] := Magic.SpellDisintegrate;
  GDVars.spellFns.spells[112] := Magic.SpellGlobeOfInvulnerability;
  GDVars.spellFns.spells[113] := Magic.SpellStoneToFlesh;
  GDVars.spellFns.spells[114] := Magic.SpellFleshToStone;
  GDVars.spellFns.spells[115] := Magic.SpellFireball;
  GDVars.spellFns.spells[116] := Magic.SpellMassInvisibility;
  GDVars.spellFns.spells[117] := Magic.SpellPowerWordStun;
  GDVars.spellFns.spells[118] := Magic.SpellFireTouch;
  GDVars.spellFns.spells[119] := Magic.SpellIronSkin;
  GDVars.spellFns.spells[120] := Magic.SpellMassCharm;
  GDVars.spellFns.spells[121] := Magic.SpellIrresistibleDance;
  GDVars.spellFns.spells[122] := Magic.SpellProtection;
  GDVars.spellFns.spells[123] := Magic.SpellPowerWordBlind;
  GDVars.spellFns.spells[124] := Magic.SpellMeteorSwarm;
  GDVars.spellFns.spells[125] := Magic.SpellPowerWordKill;
  GDVars.spellFns.spells[126] := Magic.SpellMonsterSummoning;
  @GDVars.effectHandlers[C_Effect.BLUE_DRAGON_BREATH] := @Magic.EffBreatheLightning;
  @GDVars.effectHandlers[C_Effect.RED_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[C_Effect.BIG_RED_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[C_Effect.WHITE_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[C_Effect.GREEN_DRAGON_BREATH] := @Magic.EffBreathePoison;
  @GDVars.effectHandlers[C_Effect.BLACK_DRAGON_BREATH] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[Magic.EFF_CHARM_GAZE] := @Magic.EffGazeCharm
end;

begin
end.
