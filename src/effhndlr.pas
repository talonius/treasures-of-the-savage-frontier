{ EffHndlr -- the per-effect handlers and the install table (InitEffectHandlers) that puts them in
  GDVars.effectHandlers, by effect id. The handlers adjust the attack being resolved through GDVars: the pending damage
  (pendingDamage), the saving-throw bonus (saveRoll), the damage-type mask (effectMask: 1 fire, 2 cold, 4 electricity, 8
  magic) and the attack roll (attackRoll). }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit EffHndlr;

interface

type
  PPointer = ^Pointer;

{ Install the handlers into GDVars.effectHandlers, by effect id. Effect 117 is CbtActs' AttackEyeRays. GameInit calls
  it. }
procedure InitEffectHandlers;

{ Show a pending crystal smash: every creature in play holding a crystal effect ($80..$82) 'smashes a crystal'. Combat
  calls it too. }
procedure ShowCrystalSmash;

{ Effects 27, 31, 51, 52, 53 (lose turn, helpless, held, asleep): ends the creature's actions.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffClearGuard(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the bless effect: adds 5 to morale and 1 to the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBless(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the curse effect: takes 5 from morale (not below 0) and 1 from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffCurse(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies sticks to snakes: the snakes use up the creature's attacks this round, taking them off the effect's strength
  (the effect ends when it runs out); the creature is shown fighting with snakes and its actions end.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSticksToSnakes(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies Dispel Evil: takes 7 from the attack roll when the current creature has creature-type flag bit 0, except on
  removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDispelEvil(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 6, Immune to Electricity: cancels electrical damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneElectricity(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 7: unless the effect is being removed, +1 attack against a target with immunities bit 2.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffGnomeHitBonus(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies protection from evil: against an evil attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtEvil(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies protection from good: against a good attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtGood(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies resist cold: halves cold damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistCold(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 11 (charm): when applied, move the creature to the side the effect's strength gives (keeping the old side in
  it), put it under computer control and drop its target; on removal restore its side and control, and under condition
  28 an okay creature falls unconscious with no hit points. Both raise condition 27.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effects 12 and 38, Enlarged and Strengthened: does nothing when called.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffExtraStr(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies Barkskin: adds 1 to the saving throw unless the attack carries element bit 3, and takes 1 from the attack
  roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBarkskin(var cr: Pointer; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFriends(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the poison that slow poison holds back: except on removal, every ten minutes, unless the effect lock is set,
  renews itself and costs the creature 1 hit point while it has more than 1, redrawing its roster line outside combat.
  Note: the effect it renews is the dwarf's attack bonus, not itself.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowPoisonHit(var cr: Pointer; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies shield: raises the creature's armor class value to at least 57 (armor class 3), adds 1 to the saving throw,
  and stops Magic Missile, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffShield(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 18, 30% resistant to charm: a 30% chance to shrug off charm and sleep.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHalfElfResistance(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies resist fire: halves fire damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistFire(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 21 (silence): print the message (GDConsts.isText and the effect's name from GDVars.effectNames) when the
  creature could still use items, use up the spell it was casting (CharHlp.RemoveSpell), and clear its casting fields.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSilence(var cr: Pointer; p: Pointer; removed: Boolean);

{ Ends slow poison: except on removal, a creature still poisoned collapses from the poison (falls unconscious), and the
  held-back poison is removed under the effect lock.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowPoisonEnd(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 23 (spiritual hammer): while it lasts the creature 'Gains an item' (kind 6, id $79, readied when its hand is
  empty), taken back on removal.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 25, Invisible (spell): attackers that cannot see invisible suffer -4 to hit.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisible(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the dwarf's attack bonus: adds 1 to the attack roll against a combat target with creature-type flag bit 7,
  except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDwarfHitBonus(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 28 (mirror image): in combat an attack may strike an image instead ('lost an image'); the last image ends the
  effect.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffMirrorImage(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies ray of enfeeblement: takes a quarter off the pending damage, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffEnfeeble(var cr: Pointer; p: Pointer; removed: Boolean);

{ Nauseated effect: in combat the creature's pending action is cleared, with a coughing message if it had one, and it
  suffers -2 on both defense values.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCoughing(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 32: unless the effect is being removed, the creature's target, if it has creatureType bit 0 and fails its save
  (type 4), 'is dispelled' and this creature loses effects 4 and $20; otherwise it 'resists dispel evil'.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffDispelEvilTouch(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies blindness: takes 4 from the attack roll, the saving throw and both armor classes, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBlind(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies disease: runs the strength-loss and hit-point-loss disease handlers, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseased(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies confusion: rolls d100: on 1..10 the creature runs away (forced to flee under AI control with the fear effect,
  the confusion ending), on 11..60 it is confused and its actions end, on 61..80 it goes berserk, and on 81..100 it is
  enraged. A spell save at -2 then ends the confusion. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusion(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies bestow curse: takes 4 from the attack roll and the saving throw, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBestowCurse(var cr: Pointer; p: Pointer; removed: Boolean);

{ Blink effect: when the creature has no initiative left, it cannot be targeted and the attack misses, except on
  removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBlinking(var cr: Pointer; p: Pointer; removed: Boolean);

{ Haste effect: ages the creature a year the first time (strength bit 5 marks it, and the aging flag is set) and doubles
  its movement and attacks, except on removal.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffHasted(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 40, Rakshasa Protection: spells below level 8 do no damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRakshasaProt(var cr: Pointer; p: Pointer; removed: Boolean);

{ Protection from Normal Missiles effect: except on removal, ranged attacks with a nonmagical weapon always miss.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtNormalMissiles(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies Slow: halves the movement and attacks, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowed(var cr: Pointer; p: Pointer; removed: Boolean);

{ Strength disease: except on removal, and unless the effect lock is on, re-arms itself for another 60 and costs a point
  of current Strength ('weakened') while it is above 3; at 3 or less the creature becomes helpless.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed; nothing is done then.) }
procedure EffDiseaseStrength(var cr: Pointer; p: Pointer; removed: Boolean);

{ Hit-point disease: except on removal, and unless the effect lock is on, re-arms itself for another 10 and costs 1 hit
  point while the creature has more than 1, redrawing its party-panel row outside combat; at 1 or less the creature
  becomes helpless.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed; nothing is done then.) }
procedure EffDiseaseHitPoints(var cr: Pointer; p: Pointer; removed: Boolean);

{ Dwarf's defense against giants: takes 4 from the attack roll of an attacker (the current character) with creature-type
  flag bit 2, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDwarfGiantDefense(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the gnome's defensive bonus: takes 4 from the attack roll of an attacker (the current character) with
  creature-type flag bit 5, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGnomeBugDefense(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies prayer: except on removal, a creature on the side named by the top bit (bit 7) of the effect's strength gains
  1 on its attack and save rolls, and a creature on the other side loses 1 on both.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed True when the effect is being removed.) }
procedure EffPrayer(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 50, Fire Shield with hot flames: +2 on saves against cold, and fire damage is doubled when the save fails.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFireShieldHot(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 54, Fire Shield with cold flames: +2 on saves against fire, and cold damage is doubled while the game-saved
  flag is clear. Note: that flag records whether the game was just saved, not whether the target made its saving throw,
  which is what the hot flames handler tests: an SSI bug.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFireShieldCold(var cr: Pointer; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(var cr: Pointer; p: Pointer; removed: Boolean);

{ Ring of Invisibility effect: adding it makes the wearer invisible as the spell does; removing it in combat ends that
  invisibility.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRenewInvisibility(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 57, Enveloped in Globe of Invulnerability: spells of level 4 and below have no effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGlobeInvuln(var cr: Pointer; p: Pointer; removed: Boolean);

{ Petrifying gaze effect: except on removal, the creature picks an enemy and gazes at it. A gazer whose gaze can be
  reflected has it turned back by a target with a mirror ready. The victim is turned to stone unless it saves (saving
  throw 1) or is immune to gaze attacks.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffPetrifyingGaze(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 59: empty.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGazeReflectable(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 60, +3 weapons or better to hit: only +3 or better weapons do damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedPlus3(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 61: against fire, -2 damage per die (not below the dice count) and +4 save; non-magical fire is cancelled.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRingFireRes(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 62 (regeneration): every hour restore a hit point and announce it.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffConRegeneration(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 63: unless the effect is being removed, cancels an incoming spell of level 3 or lower.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffMinorGlobe(var cr: Pointer; p: Pointer; removed: Boolean);

{ Poisons the creature's combat target on a hit, with no save modifier; nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffPoisonAttack(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 65, Petrification Touch Attack: unless the effect is being removed, the creature's target saves (saving throw
  1) or is turned to stone.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffPetrifyTouch(var cr: Pointer; p: Pointer; removed: Boolean);

{ Halves the damage of weapons of class 0 and 1.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDamageFromWeaponClass(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 67: halves damage from a weapon whose weapon class is above $7F.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDmgCrush(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 68 (stupidity): the creature 'loses intellect' (two stats set to 3), loses the spell it was casting in combat,
  and its cast spells (cells with the high bit) are cleared.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFeeblemind(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies Invisible to Animals: takes 4 from the attack roll when the creature has creature-type bits $45 and lacks See
  Invisible. Note: the animal test reads the protected creature's flags, not the attacker's.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisibleToAnimals(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 70, confusion gaze: unless the effect is being removed, the creature picks a target (as spell 68) and, when one
  is picked and adjacent (CalcDistance below 2), gazes at it ('gazes...'); unless the target saves (saving throw 4) or
  is immune to gaze attacks, it 'stares blankly', confused for 1d10+2.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffConfusionGaze(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 71, Magically Highlighted: unless the effect is being removed, -2 on both armor class values.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffHighlighted(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 72: empty.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMirrorReady(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies breath immunity: cancels attacks carrying element bit 5 (breath), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneBreath(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 74, Wearing Magical Boots: no effect. Note: it doubles a local that is never used.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffMagicBoots(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 75, giant slaying sword: unless the effect is being removed, against a target with immunities bit 0 the damage
  becomes 6d6 plus CharHlp.StrDamageAdjust and the attack roll gains 1.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffGiantSlayingSword(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 76, Immune to Disease: cancels disease.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneDisease(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 77 (berserk): the creature 'goes berserk' under computer control; in combat it takes a target from Pathing's
  list (BuildTargetList) and joins the side opposing it. On removal it returns to side 0 and player control.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusedBerserk(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 78: +1 save.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffMagicalStone(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the iron golem's immunity: a fire attack with element bit 3 heals the creature by the damage (to its maximum),
  an electrical attack slows it, and each attack is cancelled, on removal too.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffIronGolem(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 80: halves damage from weapons below +3.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffLuckStone(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 81: halves damage from weapons below +4.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHalfDmgWeaponLt3(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 82, killed by blessed crossbow bolts: a hit from item type 74 slays the creature.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlessedBoltKills(var cr: Pointer; p: Pointer; removed: Boolean);

{ Poisons the creature's combat target on a hit, with a save modifier of -2; nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffStrongPoisonAttack(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 88, paralyzing poison: unless the effect is being removed, paralyzes the creature's target through
  ParalyzeTarget when it is close (CalcDistance below 2).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffParalyzingPoison(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies displacement: except on removal, the first attack on the creature misses (the attack roll becomes -1) and
  strength bit 4 marks it used; the mark is cleared only in round 0 on a zero attack roll.
  @param(cr Unused.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDisplaced(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 92: cancels an incoming fright.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneFear(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 93, immune to fire: cancels fire damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneFire(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the Constitution saving-throw bonus: adds 1 to 5 to a spell, paralyzation or type-2 saving throw, rising with
  Constitution from 4 to 20, except on removal. Note: other Constitution values add whatever the local held.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConPsnSave(var cr: Pointer; p: Pointer; removed: Boolean);

{ Elven resistance: except on removal, a 90 percent chance to shrug off charm and sleep.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffElfResistance(var cr: Pointer; p: Pointer; removed: Boolean);

{ Constitution save bonus: adds 1 to 5, rising with Constitution from 4 to 20, to a saving throw against spells or
  wands, except on removal. Note: other Constitution values add an unset value.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConSpellSave(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 98, immune to cold: unless the effect is being removed, cancels cold attacks (damage-type bit 2).
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffNoCold(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 99, bullet rake attack: sets the second phase's attacks left to 8 one time in four, otherwise to 4.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBulletRake(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies the dragon fear attack: every conscious enemy that fails saving throw 1 at -4 is terrified, unless already
  affected.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonFear(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 101, drain 1 level: in combat the creature's hit drains one level from its target.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDrainOne(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 102, drain 2 levels: in combat the creature's hit drains two levels from its target.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDrainTwo(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 103, immune to nonmagical weapons: only magical weapons do damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedMagic(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 104: in combat, deals 4d6 magical fire damage to the creature's target, which saves (type 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireDmg4d6(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 105: against a close target (CalcDistance at most 1) with creatureType bit 3, add the creature's effective
  class-4 level to the damage.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRangerDamageBonus(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies Stunned: the creature's actions end.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStunned(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 107: as effect 77 (berserk) without the message or the combat check.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffBerserk(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 108: in combat, deals 2d6 magical fire damage to the creature's target, which saves (type 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireDmg2d6(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 110: on removal set poisonCount to the creature's effective class-3 level div 5 + 1.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRecentCure(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies fear: on removal a $B3 creature leaves AI control and the creature is no longer forced to flee.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFear(var cr: Pointer; p: Pointer; removed: Boolean);

{ Zaps an adjacent attacker (the current character), except on removal: it 'gets zapped' for twice the pending damage,
  when that is above 0, as magic damage (element bit 3).
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffZapAttacker(var cr: Pointer; p: Pointer; removed: Boolean);

{ Applies giant strength: announces that the creature gains it, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGiantStrength(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 114, paralyze gaze attack: the creature picks an enemy and gazes at it, with the same reflection rule as the
  petrification gaze. The victim is held for 10 unless it saves (saving throw 1 at +3) or is immune to gaze attacks.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffParalyzeGaze(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 115, vorpal weapon: in combat, unless the effect is being removed, a beheading hit kills a target without
  immunities bit 5 ('is beheaded').
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed True when the effect is being removed; then nothing happens.) }
procedure EffVorpal(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 116, multiple attacks by new weapons: sets the damage for the weapon kind in the first attack count (its dice +
  4 + the strength bonus) and prints the weapon's message.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMultiAttackNewWeapons(var cr: Pointer; p: Pointer; removed: Boolean);

{ Forced to dance: the armor class and rear armor class 4 lower.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDancing(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 119, Resist Fire (Druid): absorbs 12 points of fire damage per point of strength in the effect data, ending
  when the strength is used up.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed Unused.) }
procedure EffResistFireDruid(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 120, affected by dragon fear: -2 damage (never below 0) and -2 to hit.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDragonFeared(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 121, Fire Touch: in combat, deals 2d6 magical fire damage to the creature's target, which saves (type 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFireTouch(var cr: Pointer; p: Pointer; removed: Boolean);

{ Iron Skin: the armor class and rear armor class 4 higher.
  @param(cr The creature with the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffIronSkin(var cr: Pointer; p: Pointer; removed: Boolean);

{ Mind Blank: cancels a charm, confusion, hold, feeblemind or fear.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffMindBlank(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 125, immune to weapons < +2: only +2 or better weapons do damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNeedPlus2(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 126, immune to gaze attacks: a gaze attack's saving throw always succeeds.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneGaze(var cr: Pointer; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNone(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 127 (linked effect): add the effect its item carries, permanently unless it is spiritual hammer, running the
  handler at once for effects 59 and 159, and remove it again on removal.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffGrantItemEffect(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 128 (the first crystal): when crystals are active and no smash is being shown, record this crystal (lastCrystal
  0 and bit 1 in crystals), remove the effect and show the smash.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffRedCrystal(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 129: crystal 2, as effect 128 (lastCrystal 1, bit 2).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGreenCrystal(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 130: crystal 3, as effect 128 (lastCrystal 2, bit 4).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBlueCrystal(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 131: works with gameState's npcLove and partyLove, the creature's own and the other's by whether it is a
  non-player character. When the creature downs another (condition 25), the other's love rises by 2 for an evil victim
  and falls by 20 for a good one. Conditions 10 and 16 adjust the attack roll by the effect's strength and the two
  loves; at condition 13, once the other's love reaches 100, the ally in love 'goes into frenzy' under computer control.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffInLove(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 132: the creature's target, unless already charmed, saves (type 4) or 'is charmed' to this creature's side, and
  its turn ends.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffHarpyTouch(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 133: half damage from magic, cold, fire or electricity.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHalfElemental(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 134: empty.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStoneFleshKills(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 135: half damage when the creature's target wears armor with name part $80.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffGlacierArmor(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 136: double damage from a readied item with name part $7F.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffVulnerableToIcewindDale(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 137: at a chosen target within 6 (CalcDistance), a 30% chance it 'Spits Acid' for 1d13+3, which saves (type 3);
  otherwise 'Spits Acid and Misses'.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSpitAcid(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 138: at a chosen target close by (CalcDistance below 2), 'Breathes Fire' for 7, which saves (type 3).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBreatheFireAdjacent(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 139: double damage from a readied item with name part $81.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffVulnerableToStonecutting(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 140: shape change. Condition 8 loads CPIC icons $26..$2A and condition 26 frees them; condition 19 'changes
  form' to a random one of them, or 'changes back' to the saved icon.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffShapeChange(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 141: from a readied item, a quarter of the damage when its weapon class is at most 1, and none when its
  properties have bit $10. Note: the properties test runs even when the attacker has no weapon.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistItemTypes(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 142: cancel every attack.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffCancelAllAttacks(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 143: when Pathing.WalkLine accepts the path to the chosen target (range 10), throw six spines at it, each hit
  doing 1d6 ('Throws a Spine', or 'and Misses').
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffThrowSpines(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 144: crushing. On a hit (condition 2), while free, the creature's target 'is being crushed' and cannot move,
  and this creature records whom it holds in the effect's strength; condition 13 or 27 lets the victim go ('is
  released'), and condition 14 crushes it for 5 and ends the creature's turn.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffCrush(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 145: a 5% chance the creature's target, unless already diseased, saves (type 0) or is 'diseased' ($22).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffDiseaseTouch(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 146: doubles the movement (GDVars.fxScratchA) in the first round.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFirstTurnDoubleMove(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 147: while the effect's strength is $FF, condition 5 needs a +2 weapon and condition 14 'slows' a chosen target
  for 6; otherwise condition 14 counts the strength down, and at $FF the creature 'returns to stone'. Conditions 6 and 9
  cancel spells other than spell 113.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowAura(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 148: until the effect's strength counts down to $FD, a chosen target close by (CalcDistance below 3) is
  breathed on ('Breathes') and saves (type 1) or, unless immune to gaze attacks, 'is turned to stone'; the turn ends.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffBreatheStone(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 149: a 2d8 grab.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffGrab2d8(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 150: a 4d5 grab.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffGrab4d5(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 151: a 6d4 grab.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed True when the effect is being removed.) }
procedure EffGrab6d4(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 152: when gameState^.field53 is set, each okay creature on the other side saves (type 1) or, unless already
  frightened, 'is frightened.' and flees.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffFrightenAura(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 153: fire does half again as much damage.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFireVulnerable(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 154: at a chosen target close by (CalcDistance below 2), 'Breathes Ice' for 7, which saves (type 3).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffBreatheIce(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 155: when GDVars.attackRoll is at least 20, the creature's target 'is swallowed' and dies.
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffSwallow(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 156: clear the creature's movement (combatAddr^.movement).
  @param(cr The creature the effect is on.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffCannotMove(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 157: electricity does half again as much damage. Note: the effect's name in the game reads 'Resistant to
  electricty', the opposite of what it does.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffShockVulnerable(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 158: empty.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffImmuneToWeather(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 159: the creature 'Is empowered', setting the effect's duration to 50, 60, 70 or 80.
  @param(cr The creature the effect is on.)
  @param(p The effect record or item that owns the effect.)
  @param(removed Unused.) }
procedure EffEmpowered(var cr: Pointer; p: Pointer; removed: Boolean);

{ Effect 160: empty.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffWearingMagicalBoots(var cr: Pointer; p: Pointer; removed: Boolean);

implementation

uses Types, Crt, GDConsts, GDVars, C_Effect, C_Cond, C_Status, C_Class, C_Ifc,
  C_Npc, C_Race, C_Spell, Music, GameIo, TextRend, CbtActs, ViewChar, FxEngine, CharHlp, ClassCal, Pathing, CbtMap,
  MapTiles, C_Stat, C_Equip;

const
  { effect ids only this unit names }
  { Sees Invisible }
  SEE_INVISIBLE = 24;
  { Effect #59 }
  GAZE_REFLECTABLE = 59;
  { mirror ready }
  MIRROR_READY = 72;

type
  PString = ^String;

{ Holds a creature's target, unless it is already held: the target may save against saving throw 0, and a hold that
  takes ends the attacker's actions. The hold always lasts 10.
  @param(cr The attacking creature.)
  @param(ignored Unused.)
  @param(damage The modifier to the target's save.) }
procedure ParalyzeTarget(cr: Pointer; ignored: Word; damage: ShortInt);
var
  outcome: Byte;
  effectNode: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
begin
  GDVars.effectTarget := Types.PCharacter(PPointer(cr)^)^.combatAddr^.other;
  if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.HELD, effectNode) then begin
  end else begin
    outcome := FxEngine.RollSavingThrow(GDVars.effectTarget, 0, damage);
    FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.HELD, 10, 12, 0, 1, outcome,
                                  'paralyzed by poison');
    if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.HELD, effectNode) then begin
      cleared := CharHlp.EndActions(PPointer(cr)^);
      Types.PCharacter(PPointer(cr)^)^.curAttacks[1] := 0;
      Types.PCharacter(PPointer(cr)^)^.curAttacks[2] := 0
    end
  end
end;

{ Cancels the pending effect and the damage when the given effect is 0 or is the effect being applied.
  @param(x The effect to cancel, or 0 for whichever effect is pending.) }
procedure NullifyAttack(x: Byte);
begin
  if (x = 0) or (GDVars.pendingEffectId = x) then begin
    GDVars.pendingDamage := 0;
    GDVars.pendingEffectId := 0
  end
end;

procedure ClearDamageForElement(x: Byte);
forward;

{ Re-arms a timed effect on a creature for another interval, unless the effect-busy flag GDVars.effectBusy is set.
  @param(cr The creature.)
  @param(effectId The effect.)
  @param(strength Its strength.)
  @param(minutes Its duration.)
  @returns(True when it re-armed the effect.) }
function AddEffectIfNoLock(cr: PPointer; effectId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectBusy <> 0 then
    AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(cr^, effectId, minutes, strength, True)
  end
end;

{ Cancels the pending damage when the attack's element mask includes the given bits.
  @param(x The element bits.) }
procedure ClearDamageForElement(x: Byte);
begin
  if (GDVars.effectMask and x) <> 0 then
    EffHndlr.NullifyAttack(0)
end;

procedure EffClearGuard(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
begin
  cleared := CharHlp.EndActions(cr)
end;

{ Gives +1 to the attack roll and the saving throw.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure ImproveRolls(cr, p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Inc(GDVars.saveRoll);
    Inc(GDVars.attackRoll)
  end
end;

procedure EffBless(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Inc(GDVars.effectMagnitude, 5);
    Inc(GDVars.attackRoll)
  end
end;

procedure EffCurse(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if GDVars.effectMagnitude < 5 then
      GDVars.effectMagnitude := 0
    else
      Dec(GDVars.effectMagnitude, 5);
    Dec(GDVars.attackRoll)
  end
end;

procedure EffSticksToSnakes(var cr: Pointer; p: Pointer; removed: Boolean);
var
  t: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
begin
  t := Types.PCharacter(cr)^.curAttacks[1] + Types.PCharacter(cr)^.curAttacks[2];
  if Types.PEffect(p)^.strength > t then
    Dec(Types.PEffect(p)^.strength, t)
  else
    FxEngine.RemoveEffect(cr, C_Effect.SNAKE_HARASS, nil);
  CharHlp.PrintNameStringAnim(cr, True, 'is fighting with snakes');
  CharHlp.ClearMessageWindow;
  cleared := CharHlp.EndActions(cr)
end;

procedure EffDispelEvil(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.curChar^.creatureType and 1) <> 0 then
      Dec(GDVars.attackRoll, 7)
end;

procedure EffImmuneElectricity(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    EffHndlr.ClearDamageForElement(4)
end;

procedure EffGnomeHitBonus(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if (GDVars.effectTarget^.immunities and 4) <> 0 then
      Inc(GDVars.attackRoll)
  end
end;

procedure EffProtEvil(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.curChar^.alignment = 2) or (GDVars.curChar^.alignment = 5) or
        (GDVars.curChar^.alignment = 8) then begin
      Inc(GDVars.saveRoll, 2);
      Dec(GDVars.attackRoll, 2)
    end
end;

procedure EffProtGood(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.curChar^.alignment = 0) or (GDVars.curChar^.alignment = 3) or
        (GDVars.curChar^.alignment = 6) then begin
      Inc(GDVars.saveRoll, 2);
      Dec(GDVars.attackRoll, 2)
    end
end;

procedure EffResistCold(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.effectMask and 2) <> 0 then begin
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
      Inc(GDVars.saveRoll, 3)
    end
end;

procedure EffCharm(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if GDConsts.currentCondition = 28 then
      if Types.PCharacter(cr)^.status = 0 then begin
        Types.PCharacter(cr)^.status := 4;
        Types.PCharacter(cr)^.inPlay := 0;
        Types.PCharacter(cr)^.hpCur := 0
      end;
    Types.PCharacter(cr)^.side := (Types.PEffect(p)^.strength and $40) div 64;
    if Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER then begin
      Types.PCharacter(cr)^.npc := 0;
      Types.PCharacter(cr)^.quickfight := 0
    end;
    FxEngine.TriggerEffectsWithCondition(27, cr)
  end else begin
    if (Types.PEffect(p)^.strength and $20) = 0 then begin
      Types.PEffect(p)^.strength := Types.PEffect(p)^.strength + $20 + (Types.PCharacter(cr)^.side * 64);
      Types.PCharacter(cr)^.side := Types.PEffect(p)^.strength div 128;
      Types.PCharacter(cr)^.quickfight := 1;
      if Types.PCharacter(cr)^.npc <= $7F then
        Types.PCharacter(cr)^.npc := C_Npc.ANIMATED_PLAYER;
      Types.PCharacter(cr)^.combatAddr^.other := nil;
      CharHlp.CountTeams
    end;
    GDVars.effectMagnitude := 100;
    FxEngine.TriggerEffectsWithCondition(27, cr)
  end
end;

procedure EffExtraStr(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffBarkskin(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if (GDVars.effectMask and 8) = 0 then
      Inc(GDVars.saveRoll);
    Dec(GDVars.attackRoll)
  end
end;

procedure EffFriends(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffSlowPoisonHit(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if EffHndlr.AddEffectIfNoLock(@cr, C_Effect.DWARF_THAC0_BONUS, Types.PEffect(p)^.strength, 10) then
      if Types.PCharacter(cr)^.hpCur > 1 then begin
        GDVars.effectMask := 0;
        FxEngine.InflictNonWeaponDamage(cr, 1, 0, 0);
        if GDVars.locState.current <> C_Ifc.IN_COMBAT then
          CharHlp.PrintMiscInfo(cr, Byte(cr = Pointer(GDVars.curChar)))
      end
end;

procedure EffReadMagic(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffShield(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if Types.PCharacter(cr)^.acCur[0] < 57 then
      Types.PCharacter(cr)^.acCur[0] := 57;
    Inc(GDVars.saveRoll);
    if GDVars.opMode = 15 then
      GDVars.pendingDamage := 0
  end
end;

procedure EffHalfElfResistance(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if FxEngine.RollDice(1, 100) <= 30 then begin
      EffHndlr.NullifyAttack(C_Effect.CHARM);
      EffHndlr.NullifyAttack(C_Effect.ASLEEP)
    end
end;

procedure EffResistFire(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.effectMask and 1) <> 0 then begin
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
      Inc(GDVars.saveRoll, 3)
    end
end;

procedure EffSilence(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if Types.PCharacter(cr)^.combatAddr^.itemUseAllowed <> 0 then
      CharHlp.PrintCreatureMessage(cr, GDConsts.isText + GDVars.effectNames^[21], 10, 1);
    if Types.PCharacter(cr)^.combatAddr^.spellCast > 0 then
      CharHlp.RemoveSpell(cr, Types.PCharacter(cr)^.combatAddr^.spellCast);
    Types.PCharacter(cr)^.combatAddr^.spellCast := 0;
    Types.PCharacter(cr)^.combatAddr^.itemUseAllowed := 0;
    Types.PCharacter(cr)^.combatAddr^.castAllowed := 0
  end
end;

procedure EffSlowPoisonEnd(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
begin
  if not removed then begin
    if CharHlp.HasEffect(cr, C_Effect.POISONED, effect) then
      FxEngine.KillCreature(cr, C_Status.UNCONSCIOUS, 'collapses from poison');
    GDVars.effectBusy := 1;
    FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectBusy := 0
  end
end;

procedure EffSpiritualHammer(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
  found: Boolean;
  savedCurrent: Types.PCharacter;
begin
  item := Types.PCharacter(cr)^.items;
  found := False;
  while (item <> nil) and not found do
    if (item^.itemType = 6) and (item^.nameIds[3] = $79) then
      found := True
    else
      item := item^.next;
  if removed and (item <> nil) then
    CharHlp.RemoveItem(cr, item);
  if not removed then begin
    if not found then begin
      if Types.PCharacter(cr)^.numberOfItems < $10 then begin
        GetMem(item, SizeOf(item^));
        GameIo.ZeroFill(item^, SizeOf(item^));
        item^.itemType := 6;
        item^.nameIds[2] := 6;
        item^.nameIds[3] := $79;
        item^.plus := 1;
        item^.effect := $17;
        item^.special := $80;
        CharHlp.AddItemCopy(cr, item);
        FreeMem(item, SizeOf(item^));
        item := Types.PCharacter(cr)^.items;
        found := False;
        while (item <> nil) and not found do begin
          found := (item^.nameIds[3] = $79) and (item^.itemType = 6);
          item := item^.next
        end;
        savedCurrent := GDVars.curChar;
        GDVars.curChar := cr;
        if (item <> nil) and (Types.PCharacter(cr)^.equipped[C_Equip.WEAPON] = nil) then begin
          ViewChar.ToggleReadyItem(item);
          item^.equipped := 1
        end;
        GDVars.curChar := savedCurrent;
        if found then
          CharHlp.PrintCreatureMessage(cr, 'Gains an item', 10, 1)
      end
    end
  end;
  CharHlp.RecalcStats(cr)
end;

procedure EffInvisible(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
begin
  if not removed then
    if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE, effect) then
      Dec(GDVars.attackRoll, 4)
end;

procedure EffDwarfHitBonus(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Word;
begin
  if not removed then begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if (GDVars.effectTarget^.creatureType and $80) <> 0 then
      Inc(GDVars.attackRoll)
  end
end;

procedure EffMirrorImage(var cr: Pointer; p: Pointer; removed: Boolean);
var
  images: Byte;
begin
  if not removed then
    if GDVars.locState.current = C_Ifc.IN_COMBAT then
      if FxEngine.RollDice(1, Types.PEffect(p)^.strength div $20 + 1) > 1 then
        if (GDVars.effectInProgress = 0) or
            ((GDVars.opMode > 0) and (GDConsts.spellTable[GDVars.opMode].offensive = 0)) then begin
          EffHndlr.NullifyAttack(0);
          CharHlp.PrintCreatureMessage(cr, 'lost an image', 10, 1);
          images := Types.PEffect(p)^.strength shr 5;
          Dec(images);
          if images = 0 then
            FxEngine.RemoveEffect(cr, C_Effect.MIRROR_IMAGE, nil)
          else begin
            images := images shl 5;
            Types.PEffect(p)^.strength := (Types.PEffect(p)^.strength and $1F) or images
          end
        end
end;

procedure EffEnfeeble(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4
end;

procedure EffCoughing(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    if Types.PCharacter(cr)^.combatAddr^.itemUseAllowed <> 0 then
      CharHlp.PrintCreatureMessage(cr, 'is coughing', 10, 1);
    Types.PCharacter(cr)^.combatAddr^.itemUseAllowed := 0;
    Types.PCharacter(cr)^.combatAddr^.castAllowed := 0;
    CharHlp.RecalcStats(cr);
    Dec(Types.PCharacter(cr)^.acCur[0], 2);
    Dec(Types.PCharacter(cr)^.acCur[1], 2);
    if cr = Pointer(GDVars.curChar) then
      CharHlp.CombatPrintCreatureInfo(cr)
  end
end;

procedure EffDispelEvilTouch(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if ((GDVars.effectTarget^.creatureType and 1) <> 0) and
        (FxEngine.RollSavingThrow(GDVars.effectTarget, 4, 0) = 0) then begin
        FxEngine.KillCreature(GDVars.effectTarget, C_Status.GONE, 'is dispelled');
        FxEngine.RemoveEffect(cr, C_Effect.DISPEL_EVIL, nil);
        FxEngine.RemoveEffect(cr, C_Effect.DISPEL_EVIL_TOUCH, nil)
      end else
      CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'resists dispel evil', 10, 1)
  end
end;

procedure EffBlind(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Dec(GDVars.attackRoll, 4);
    Dec(Types.PCharacter(cr)^.acCur[0], 4);
    Dec(Types.PCharacter(cr)^.acCur[1], 4);
    Dec(GDVars.saveRoll, 4)
  end
end;

procedure EffDiseased(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    FxEngine.CallEffectHandler(C_Effect.DISEASE_STRENGTH, cr, p, removed);
    FxEngine.CallEffectHandler(C_Effect.DISEASE_HIT_POINTS, cr, p, removed)
  end
end;

procedure EffConfusion(var cr: Pointer; p: Pointer; removed: Boolean);
var
  roll: Byte;
  saved: Byte;
begin
  if not removed then begin
    roll := FxEngine.RollDice(1, 100);
    case roll of
      1..10:
        begin
          FxEngine.RemoveEffect(cr, C_Effect.CONFUSED, nil);
          Types.PCharacter(cr)^.combatAddr^.turned := 1;
          Types.PCharacter(cr)^.quickfight := 1;
          if Types.PCharacter(cr)^.npc <= $7F then
            Types.PCharacter(cr)^.npc := C_Npc.ANIMATED_PLAYER;
          Types.PCharacter(cr)^.combatAddr^.other := nil;
          FxEngine.AddEffectWithMessage(cr, C_Effect.FRIGHTENED, 10, 0, 1, 1, 0, 'runs away')
        end;
      11..60:
        begin
          CharHlp.PrintNameStringAnim(cr, True, 'is confused');
          CharHlp.ClearMessageWindow;
          EffHndlr.EffClearGuard(cr, p, False)
        end;
      61..80:
        begin
          FxEngine.AddEffectWithMessage(cr, C_Effect.CONFUSED_BERSERK, 1, Types.PCharacter(cr)^.side, 1, 1, 0,
                                        'goes berserk');
          FxEngine.CallEffectHandler(C_Effect.CONFUSED_BERSERK, cr, nil, False)
        end;
      81..100:
        begin
          CharHlp.PrintNameStringAnim(cr, True, 'is enraged');
          CharHlp.ClearMessageWindow
        end
    end;
    saved := FxEngine.RollSavingThrow(cr, 4, -2);
    if saved <> 0 then
      FxEngine.RemoveEffect(cr, C_Effect.CONFUSED, nil)
  end
end;

procedure EffBestowCurse(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Dec(GDVars.attackRoll, 4);
    Dec(GDVars.saveRoll, 4)
  end
end;

procedure EffBlinking(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if Types.PCharacter(cr)^.combatAddr^.initiative = 0 then begin
      GDVars.attackVetoed := 1;
      GDVars.attackRoll := -1
    end
end;

procedure EffHasted(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if (Types.PEffect(p)^.strength and $20) = 0 then begin
      Types.PEffect(p)^.strength := Types.PEffect(p)^.strength + $20;
      CharHlp.PrintCreatureMessage(cr, 'ages', 10, 1);
      Inc(Types.PCharacter(cr)^.age);
      GDVars.agingFlag := 1
    end;
    GDVars.fxScratchA := GDVars.fxScratchA shl 1;
    GDVars.fxScratchB := GDVars.fxScratchB shl 1
  end
end;

procedure EffRakshasaProt(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if GDVars.opMode <> 0 then
      if GDConsts.spellTable[GDVars.opMode].spellLevel < 8 then
        EffHndlr.NullifyAttack(0)
end;

{ Lets a creature avoid a missile: when the current character has a readied weapon and stands more than one cell away, a
  d100 roll within the chance cancels the damage, makes the attack miss and takes the hit back, with 'Avoids it'.
  @param(p The creature attacked.)
  @param(chance The chance in percent.) }
procedure AvoidMissile(p: PPointer; chance: Byte);
begin
  if GDVars.curChar^.equipped[C_Equip.WEAPON] <> nil then
    if CharHlp.CalcDistance(GDVars.curChar, p^) > 1 then
      if FxEngine.RollDice(1, 100) <= chance then begin
        CharHlp.PrintCreatureMessage(p^, 'Avoids it', 10, 1);
        GDVars.pendingDamage := 0;
        GDVars.attackRoll := -1;
        Dec(GDVars.attackHits[1])
      end
end;

{ Finds the item a creature attacks with: the missile its readied weapon fires or throws, else the readied weapon.
  @param(w The creature.)
  @returns(The item, or nil with no weapon readied.) }
function FindDamagingWeapon(w: Types.PCharacter): Pointer;
var
  item: Pointer;
  found: Byte;
begin
  item := nil;
  if w^.equipped[C_Equip.WEAPON] <> nil then begin
    found := Byte(CharHlp.FindDamagingRangedWeapon(w, item));
    if (found = 0) or (item = nil) then
      item := w^.equipped[C_Equip.WEAPON]
  end;
  FindDamagingWeapon := item
end;

procedure EffProtNormalMissiles(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil then
    if Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar))^.plus = 0 then
      EffHndlr.AvoidMissile(@cr, 100)
end;

procedure EffSlowed(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else begin
    GDVars.fxScratchA := GDVars.fxScratchA shr 1;
    GDVars.fxScratchB := GDVars.fxScratchB shr 1
  end
end;

procedure EffDiseaseStrength(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
begin
  if not removed then
    if EffHndlr.AddEffectIfNoLock(@cr, C_Effect.DISEASE_STRENGTH, Types.PEffect(p)^.strength, 60) then
      if Types.PCharacter(cr)^.stats[C_Stat.STRENGTH].current > 3 then begin
        CharHlp.PrintCreatureMessage(cr, GDConsts.isText + 'weakened', 10, 1);
        Dec(Types.PCharacter(cr)^.stats[C_Stat.STRENGTH].current)
      end else
        FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, $FF, False)
end;

procedure EffDiseaseHitPoints(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
begin
  if not removed then
    if EffHndlr.AddEffectIfNoLock(@cr, C_Effect.DISEASE_HIT_POINTS, Types.PEffect(p)^.strength, 10) then
      if Types.PCharacter(cr)^.hpCur > 1 then begin
        GDVars.effectMask := 0;
        FxEngine.InflictNonWeaponDamage(cr, 1, 0, 0);
        if GDVars.locState.current <> C_Ifc.IN_COMBAT then
          CharHlp.PrintMiscInfo(cr, Byte(cr = Pointer(GDVars.curChar)))
      end else
        FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, $FF, False)
end;

procedure EffDwarfGiantDefense(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if (GDVars.curChar^.creatureType and 4) <> 0 then
    Dec(GDVars.attackRoll, 4)
end;

procedure EffGnomeBugDefense(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if (GDVars.curChar^.creatureType and $20) <> 0 then
    Dec(GDVars.attackRoll, 4)
end;

procedure EffPrayer(var cr: Pointer; p: Pointer; removed: Boolean);
var
  side: ShortInt;
begin
  if removed then begin
  end else begin
    side := (Types.PEffect(p)^.strength and $80) div 128;
    if Types.PCharacter(cr)^.side = side then
      EffHndlr.ImproveRolls(@cr, p, removed)
    else begin
      Dec(GDVars.attackRoll);
      Dec(GDVars.saveRoll)
    end
  end
end;

procedure EffFireShieldHot(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if (GDVars.effectMask and 2) <> 0 then
    Inc(GDVars.saveRoll, 2)
  else if ((GDVars.effectMask and 1) <> 0) and (GDVars.saveResult = 0) then
    GDVars.pendingDamage := GDVars.pendingDamage shl 1
end;

procedure EffFireShieldCold(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if (GDVars.effectMask and 1) <> 0 then
    Inc(GDVars.saveRoll, 2)
  else if ((GDVars.effectMask and 2) <> 0) and (GDVars.recentlySaved = 0) then
    GDVars.pendingDamage := GDVars.pendingDamage shl 1
end;

procedure EffPoisoned(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffRenewInvisibility(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if GDVars.locState.current = C_Ifc.IN_COMBAT then
      FxEngine.RemoveEffect(cr, C_Effect.INVISIBLE, nil)
  end else
    FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 1, 12, False)
end;

procedure EffGlobeInvuln(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if GDVars.opMode > 0 then
    if GDConsts.spellTable[GDVars.opMode].spellLevel <= 4 then
      EffHndlr.NullifyAttack(0)
end;

procedure EffPetrifyingGaze(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  reflected: Boolean;
  effect: Pointer;
begin
  if not removed then begin
    GDVars.spellFns.selectTarget(61, 1, GDVars.targetSelected);
    if CharHlp.EnemyTeam(cr) <> Byte(GDVars.spellTargets[1]^.side) then
      GDVars.targetSelected := False;
    if GDVars.targetSelected then begin
      GDVars.effectTarget := GDVars.spellTargets[1];
      CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, 0);
      CharHlp.BuildIconFacings(18);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                      CbtMap.CombatCellX(GDVars.effectTarget),
                                      CbtMap.CombatCellY(GDVars.effectTarget), 4,
                  45);
      if CharHlp.HasEffect(cr, EffHndlr.GAZE_REFLECTABLE, effect) then begin
        reflected := False;
        if CharHlp.HasEffect(GDVars.effectTarget, EffHndlr.MIRROR_READY, effect) then begin
          CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'reflects it!', 12, 0);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.effectTarget),
                                          CbtMap.CombatCellY(GDVars.effectTarget),
                                          CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                      4, 45);
          reflected := True;
          GDVars.effectTarget := cr
        end
      end;
      if FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 0) = 0 then
        if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, effect) then
          FxEngine.KillCreature(GDVars.effectTarget, C_Status.PETRIFIED, 'is turned to stone')
    end
  end
end;

procedure EffGazeReflectable(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

{ Lets only a weapon of at least plus limit hurt the defender. An unarmed monster (race 6) gets through only when its
  hitDice is at least (limit - 1) * 2 + 5; anyone else unarmed does no damage.
  @param(limit The weapon bonus needed.) }
procedure LimitDamageByResistance(limit: Byte);
var
  fallbackLimit: Byte;
  itemLimit: Types.PItem;
begin
  itemLimit := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if itemLimit <> nil then begin
    if itemLimit^.plus < limit then
      GDVars.pendingDamage := 0
  end else if GDVars.curChar^.race = C_Race.MONSTER then begin
    fallbackLimit := (limit - 1) * 2 + 5;
    if fallbackLimit > GDVars.curChar^.hitDice then
      GDVars.pendingDamage := 0
  end else
    GDVars.pendingDamage := 0
end;

procedure EffNeedPlus3(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.LimitDamageByResistance(3)
end;

procedure EffRingFireRes(var cr: Pointer; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if removed then begin
  end else if (GDVars.effectMask and 1) <> 0 then begin
    for i := 1 to GDVars.diceCount do begin
      if GDVars.pendingDamage >= 2 then
        Dec(GDVars.pendingDamage, 2)
      else
        GDVars.pendingDamage := 0;
      if GDVars.pendingDamage <> 0 then
        if GDVars.diceCount > GDVars.pendingDamage then
          GDVars.pendingDamage := GDVars.diceCount
    end;
    Inc(GDVars.saveRoll, 4);
    if (GDVars.effectMask and 8) = 0 then
      EffHndlr.NullifyAttack(0)
  end
end;

procedure EffConRegeneration(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    if EffHndlr.AddEffectIfNoLock(@cr, $3E, Types.PEffect(p)^.strength, $3C) then
      if FxEngine.RestoreHitPoints(cr, 1, True) then
        CharHlp.AnnounceHealStatus(cr)
end;

procedure EffMinorGlobe(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if GDVars.opMode > 0 then
    if GDConsts.spellTable[GDVars.opMode].spellLevel <= 3 then
      EffHndlr.NullifyAttack(0)
end;

{ Poisons a creature's target, which may save against saving throw 0; poison that takes hold kills it and ends the
  attacker's actions.
  @param(cr The attacking creature.)
  @param(damage The modifier to the target's save.) }
procedure PoisonTarget(cr: Pointer; damage: ShortInt);
var
  effectNode: Pointer;
  outcome: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
begin
  GDVars.effectTarget := Types.PCharacter(PPointer(cr)^)^.combatAddr^.other;
  outcome := FxEngine.RollSavingThrow(GDVars.effectTarget, 0, damage);
  FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.POISONED, 0, -1, 0, 1, outcome,
                       GDConsts.isText + GDVars.effectNames^[55]);
  TextRend.PauseOnly;
  if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.POISONED, effectNode) then begin
    FxEngine.KillCreature(GDVars.effectTarget, C_Status.DEAD_STATUS, 'is killed');
    cleared := CharHlp.EndActions(PPointer(cr)^)
  end
end;

procedure EffPoisonAttack(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    EffHndlr.PoisonTarget(@cr, 0)
end;

procedure EffPetrifyTouch(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 0) = 0 then
      FxEngine.KillCreature(GDVars.effectTarget, C_Status.PETRIFIED, 'is turned to stone')
  end
end;

procedure EffHalfDamageFromWeaponClass(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if Byte(GDVars.baseItems[item^.itemType].wpnClass <= 1) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
end;

procedure EffHalfDmgCrush(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if Byte(GDVars.baseItems[item^.itemType].wpnClass > $7F) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
end;

procedure EffFeeblemind(var cr: Pointer; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if not removed then begin
    Types.PCharacter(cr)^.stats[C_Stat.INTELLIGENCE].current := 3;
    Types.PCharacter(cr)^.stats[C_Stat.WISDOM].current := 3;
    CharHlp.PrintCreatureMessage(cr, 'loses intellect', 10, 1);
    if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
      Types.PCharacter(cr)^.combatAddr^.castAllowed := 0;
      if Types.PCharacter(cr)^.combatAddr^.spellCast > 0 then begin
        CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, 1);
        CharHlp.RemoveSpell(cr, Types.PCharacter(cr)^.combatAddr^.spellCast);
        Types.PCharacter(cr)^.combatAddr^.spellCast := 0
      end
    end;
    for i := 1 to $8C do
      if Types.PCharacter(cr)^.memorized[i] > $7F then
        Types.PCharacter(cr)^.memorized[i] := 0
  end
end;

procedure EffInvisibleToAnimals(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
begin
  if not removed then
    if (Types.PCharacter(cr)^.creatureType and $45) <> 0 then
      if not CharHlp.HasEffect(cr, EffHndlr.SEE_INVISIBLE, effect) then
        Dec(GDVars.attackRoll, 4)
end;

procedure EffConfusionGaze(var cr: Pointer; p: Pointer; removed: Boolean);
var
  selected: Boolean;
  effect: Pointer;
begin
  if not removed then begin
    GDVars.spellFns.selectTarget(68, 1, selected);
    GDVars.effectTarget := GDVars.spellTargets[1];
    if selected then
      if CharHlp.CalcDistance(cr, GDVars.effectTarget) < 2 then begin
        GDVars.effectMask := $10;
        CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, 0);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                        CbtMap.CombatCellX(GDVars.effectTarget),
                                        CbtMap.CombatCellY(GDVars.effectTarget), 4,
                    45);
        if FxEngine.RollSavingThrow(GDVars.effectTarget, 4, 0) = 0 then
          if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, effect) then
            FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.CONFUSED, FxEngine.RollDice(1, 10) + 2,
                                          Types.PCharacter(cr)^.side,
                                 1, 1, 0, 'stares blankly')
      end
  end
end;

procedure EffHighlighted(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  oldArmorClass: Word;
begin
  if removed then begin
  end else begin
    Dec(Types.PCharacter(cr)^.acCur[0], 2);
    Dec(Types.PCharacter(cr)^.acCur[1], 2)
  end
end;

procedure EffMirrorReady(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffImmuneBreath(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if (GDVars.effectMask and $20) > 0 then
    EffHndlr.NullifyAttack(0)
end;

procedure EffMagicBoots(var cr: Pointer; p: Pointer; removed: Boolean);
var
  value: Integer;
  { Unused in this version; see the other implementations of this routine. }
  oldMovement: Integer;
  { Unused in this version; see the other implementations of this routine. }
  newMovement: Integer;
begin
  if not removed then
    value := value * 2
end;

procedure EffGiantSlayingSword(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if (GDVars.effectTarget^.immunities and 1) <> 0 then begin
      GDVars.pendingDamage := FxEngine.RollDamageDice(6, 6) + CharHlp.StrDamageAdjust(cr);
      Inc(GDVars.attackRoll)
    end
  end
end;

procedure EffImmuneDisease(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    EffHndlr.NullifyAttack(C_Effect.DISEASED)
end;

procedure EffConfusedBerserk(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Types.PCharacter(cr)^.quickfight := 1;
    if (Types.PCharacter(cr)^.npc <= $7F) or (Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER) then
      Types.PCharacter(cr)^.npc := C_Npc.ANIMATED_PLAYER
    else
      Types.PCharacter(cr)^.npc := C_Npc.ANIMATED_NON_PLAYER;
    if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
      Types.PCharacter(cr)^.combatAddr^.other := nil;
      Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), $FF, $FF, CbtMap.GetIconSize(cr));
      Types.PCharacter(cr)^.combatAddr^.other := GDVars.creatureArr[GDVars.rankedTargets[2].entity];
      Types.PCharacter(cr)^.combatAddr^.castAllowed := 0;
      Types.PCharacter(cr)^.side := Types.PCharacter(cr)^.combatAddr^.other^.
          side xor 1;
      CharHlp.PrintCreatureMessage(cr, 'goes berserk', 10, 1)
    end
  end else begin
    if Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER then begin
      Types.PCharacter(cr)^.npc := 0;
      Types.PCharacter(cr)^.quickfight := 0
    end;
    Types.PCharacter(cr)^.side := 0
  end
end;

procedure EffMagicalStone(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    Inc(GDVars.saveRoll)
end;

procedure EffIronGolem(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: LongInt;
  restored: Word;
begin
  if ((GDVars.effectMask and 1) <> 0) and ((GDVars.effectMask and 8) <> 0) then begin
    CharHlp.PrintCreatureMessage(cr, GDConsts.isText + GDConsts.healedWord, 10, 1);
    restored := Types.PCharacter(cr)^.hpCur + GDVars.pendingDamage;
    if Types.PCharacter(cr)^.hpMax < restored then
      Types.PCharacter(cr)^.hpCur := Types.PCharacter(cr)^.hpMax
    else
      Types.PCharacter(cr)^.hpCur := restored;
    EffHndlr.NullifyAttack(0)
  end else if (GDVars.effectMask and 4) <> 0 then begin
    FxEngine.AddEffect(cr, C_Effect.SLOWED, 3, $FF, False);
    CharHlp.PrintCreatureMessage(cr, GDConsts.isText + GDVars.effectNames^[42], 10, 1);
    EffHndlr.NullifyAttack(0)
  end else
    EffHndlr.NullifyAttack(0)
end;

procedure EffLuckStone(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if Byte(item^.plus < 3) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
end;

procedure EffHalfDmgWeaponLt3(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if Byte(item^.plus < 4) <> 0 then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
end;

procedure EffBlessedBoltKills(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if item^.itemType = 74 then
      FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is slain')
end;

procedure EffStrongPoisonAttack(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    EffHndlr.PoisonTarget(@cr, -2)
end;

procedure EffParalyzingPoison(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if CharHlp.CalcDistance(cr, Types.PCharacter(cr)^.combatAddr^.other) < 2 then
    EffHndlr.ParalyzeTarget(@cr, 100, 0)
end;

procedure EffDisplaced(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else begin
    if (GDVars.cbRoundCounter = 0) and (GDVars.attackRoll = 0) then
      Types.PEffect(p)^.strength := Types.PEffect(p)^.strength and $0F
    else if (Types.PEffect(p)^.strength and $10) = 0 then begin
      GDVars.attackRoll := -1;
      Types.PEffect(p)^.strength := Types.PEffect(p)^.strength or $10
    end
  end
end;

procedure EffImmuneFear(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    EffHndlr.NullifyAttack($6F)
end;

procedure EffImmuneFire(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.ClearDamageForElement(1)
end;

procedure EffConPsnSave(var cr: Pointer; p: Pointer; removed: Boolean);
var
  adjustment: Byte;
begin
  if removed then begin
  end else if (GDVars.saveType = 4) or (GDVars.saveType = 2) or (GDVars.saveType = 0) then begin
    case Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current of
      4..6: adjustment := 1;
      7..10: adjustment := 2;
      11..13: adjustment := 3;
      14..17: adjustment := 4;
      18..20: adjustment := 5
    end;
    GDVars.saveRoll := GDVars.saveRoll + adjustment
  end
end;

procedure EffElfResistance(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(C_Effect.CHARM);
    EffHndlr.NullifyAttack(C_Effect.ASLEEP)
  end
end;

procedure EffConSpellSave(var cr: Pointer; p: Pointer; removed: Boolean);
var
  adjustment: Byte;
begin
  if removed then begin
  end else if (GDVars.saveType = 4) or (GDVars.saveType = 2) then begin
    case Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current of
      4..6: adjustment := 1;
      7..10: adjustment := 2;
      11..13: adjustment := 3;
      14..17: adjustment := 4;
      18..20: adjustment := 5
    end;
    GDVars.saveRoll := GDVars.saveRoll + adjustment
  end
end;

procedure EffNoCold(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else if (GDVars.effectMask and 2) <> 0 then
    EffHndlr.NullifyAttack(0)
end;

procedure EffBulletRake(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 4) = 1 then
    Types.PCharacter(cr)^.curAttacks[2] := 8
  else
    Types.PCharacter(cr)^.curAttacks[2] := 4
end;

procedure EffDragonFear(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
  walker: Types.PCharacter;
begin
  GDVars.effectInProgress := 1;
  effect := nil;
  walker := GDVars.partyHead;
  while walker <> nil do begin
    if walker^.side <> Types.PCharacter(cr)^.side then
      if walker^.status = C_Status.OKAY then
        if FxEngine.RollSavingThrow(walker, 1, -4) = 0 then
          if not CharHlp.HasEffect(walker, C_Effect.DRAGON_FEARED, effect) then
            FxEngine.AddEffectWithMessage(walker, C_Effect.DRAGON_FEARED, 0, 0, 1, 1, 0, 'is terrified');
    walker := walker^.next
  end;
  GDVars.effectInProgress := 0
end;

{ Drains levels from a creature, which 'gets drained': each pass lowers its highest class level by one, setting
  experience halfway into the new level and recalculating, after keeping the old peaks for later restoration. With no
  levels or maximum hit points left it dies; at 0 hit points it collapses. Memorized spells beyond the new spell slots
  are dropped, uncast ones first; a row-2 spell over the limit may use up a bonus-slot allowance instead.
  @param(cr The creature.)
  @param(levels The levels drained.) }
procedure DrainLevels(cr: Types.PCharacter; levels: Byte);
var
  currentValue: Byte;
  bestValue: Byte;
  drainClass: ShortInt;
  bestClass: ShortInt;
  upper: LongInt;
  lower: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  classIndex: Byte;
  drainPass: Byte;
  zeroClasses: Byte;
  anyLevels: Boolean;

  { Drop the memorized spells beyond the creature's new spell slots, uncast ones first. }
  procedure PruneSpells;
  type
    TSpellCounts = record
      value: array[0..2, 1..9] of Byte;
      { unused }
      valueTail: Byte
    end;
  var
    counts: TSpellCounts;
    spellId: Byte;
    idx: Byte;
    band: ShortInt;
    spellLevel: Byte;
  begin
    GameIo.ZeroFill(counts.value, SizeOf(counts.value));
    for idx := 0 to 140 do begin
      with cr^ do
        if (memorized[idx] > 0) and (memorized[idx] < C_Spell.PENDING_FLAG) then begin
          spellId := memorized[idx] and C_Spell.ID_MASK;
          band := GDConsts.spellTable[spellId].spellBand;
          spellLevel := GDConsts.spellTable[spellId].spellLevel;
          if counts.value[band, spellLevel] >= spellSlots[band, spellLevel] then begin
            if (spellSlots[band, spellLevel] = 0) or (GDVars.magicBonusSlots = 0) or (band <> 2) then
              memorized[idx] := 0
            else
              Dec(GDVars.magicBonusSlots)
          end else
            Inc(counts.value[band, spellLevel])
        end
    end;
    for idx := 0 to 140 do
      with cr^ do
        if memorized[idx] > C_Spell.ID_MASK then begin
          spellId := memorized[idx] and C_Spell.ID_MASK;
          band := GDConsts.spellTable[spellId].spellBand;
          spellLevel := GDConsts.spellTable[spellId].spellLevel;
          if counts.value[band, spellLevel] >= spellSlots[band, spellLevel] then
            memorized[idx] := 0
          else
            Inc(counts.value[band, spellLevel])
        end
  end;

begin
  if cr <> nil then begin
    CharHlp.PrintCreatureMessage(cr, 'gets drained', 10, 0);
    TextRend.PauseOnly;
    for drainPass := 1 to levels do begin
      zeroClasses := 0;
      bestValue := 0;
      for drainClass := 0 to 6 do begin
        currentValue := cr^.classLevels[drainClass];
        if (currentValue > 0) or (cr^.classLevelCap[drainClass] > 0) then
          Inc(zeroClasses);
        if currentValue > bestValue then begin
          bestValue := currentValue;
          bestClass := drainClass
        end else if (currentValue = bestValue) and (bestValue <> 0) then
          if ClassCal.XpForLevel(Types.PCharacter(cr), currentValue,
                                 bestClass) > ClassCal.XpForLevel(Types.PCharacter(cr), bestValue,
                                                                  drainClass) then begin
            bestValue := currentValue;
            bestClass := drainClass
          end
      end;
      if cr^.classLevelCap[bestClass] <= cr^.classLevels[bestClass] then
        cr^.classLevelCap[bestClass] := cr^.classLevels[bestClass];
      if cr^.savedExperience <= cr^.experience then
        cr^.savedExperience := cr^.experience;
      if cr^.savedHpMax <= cr^.hpMax then
        cr^.savedHpMax := cr^.hpMax;
      case bestValue of
        1:
          begin
            lower := 0;
            upper := 0
          end;
        2:
          begin
            lower := 0;
            upper := GDConsts.classLevelTable[bestClass].xp[bestValue]
          end else begin
            lower := ClassCal.XpForLevel(Types.PCharacter(cr), Pred(bestValue), bestClass);
            upper := ClassCal.XpForLevel(Types.PCharacter(cr), bestValue, bestClass)
          end
      end;
      cr^.experience := lower + (upper - lower) div 2;
      if cr^.classLevels[bestClass] > 0 then
        Dec(cr^.classLevels[bestClass]);
      if cr^.classLevels[bestClass] >= cr^.dualLevel then
        ViewChar.AdjustLevelHitPoints(cr, GDConsts.classBits[bestClass], zeroClasses, 0);
      ClassCal.RecalcClassStats(Types.PCharacter(cr));
      PruneSpells
    end;
    anyLevels := False;
    for drainClass := 0 to 6 do
      if cr^.classLevels[drainClass] > 0 then
        anyLevels := True;
    if (not anyLevels) or (cr^.hpMax <= 0) then
      FxEngine.KillCreature(cr, C_Status.GONE, 'dies from drainning')
    else if cr^.hpCur <= 0 then
      FxEngine.KillCreature(cr, C_Status.UNCONSCIOUS, 'collapses from drainning')
  end
end;

procedure EffDrainOne(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then
    EffHndlr.DrainLevels(Types.PCharacter(cr)^.combatAddr^.other, 1)
end;

procedure EffDrainTwo(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then
    EffHndlr.DrainLevels(Types.PCharacter(cr)^.combatAddr^.other, 2)
end;

procedure EffNeedMagic(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.LimitDamageByResistance(1)
end;

procedure EffFireDmg4d6(var cr: Pointer; p: Pointer; removed: Boolean);
var
  foe: Types.PCharacter;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    foe := Types.PCharacter(cr)^.combatAddr^.other;
    if foe <> nil then begin
      GDVars.effectMask := 9;
      FxEngine.InflictNonWeaponDamage(foe, FxEngine.RollDamageDice(4, 6), 2,
                                      Byte(FxEngine.RollSavingThrow(foe, 4, 0)))
    end
  end
end;

procedure EffRangerDamageBonus(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foe: Types.PCharacter;
begin
  if removed then begin
  end else begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if CharHlp.CalcDistance(cr, GDVars.effectTarget) > 1 then begin
    end else if (GDVars.effectTarget^.creatureType and 8) <> 0 then
        Inc(GDVars.pendingDamage, ClassCal.EffectiveClassLevel(cr, C_Class.RANGER))
  end
end;

procedure EffStunned(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
begin
  cleared := CharHlp.EndActions(cr)
end;

procedure EffBerserk(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Types.PCharacter(cr)^.quickfight := 1;
    if (Types.PCharacter(cr)^.npc <= $7F) or (Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER) then
      Types.PCharacter(cr)^.npc := C_Npc.ANIMATED_PLAYER
    else
      Types.PCharacter(cr)^.npc := C_Npc.ANIMATED_NON_PLAYER;
    Types.PCharacter(cr)^.combatAddr^.other := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), $FF, $FF, CbtMap.GetIconSize(cr));
    Types.PCharacter(cr)^.combatAddr^.other := GDVars.creatureArr[GDVars.rankedTargets[2].entity];
    Types.PCharacter(cr)^.side := Types.PCharacter(cr)^.combatAddr^.other^.
        side xor 1
  end else begin
    if Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER then
      Types.PCharacter(cr)^.npc := 0;
    Types.PCharacter(cr)^.side := Types.PEffect(p)^.strength
  end
end;

procedure EffFireDmg2d6(var cr: Pointer; p: Pointer; removed: Boolean);
var
  foe: Types.PCharacter;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    foe := Types.PCharacter(cr)^.combatAddr^.other;
    if foe <> nil then begin
      GDVars.effectMask := 9;
      FxEngine.InflictNonWeaponDamage(foe, FxEngine.RollDamageDice(2, 6), 2,
                                      Byte(FxEngine.RollSavingThrow(foe, 4, 0)))
    end
  end
end;

procedure EffRecentCure(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then
    Types.PCharacter(cr)^.poisonCount := ClassCal.EffectiveClassLevel(cr, C_Class.PALADIN) div 5 + 1
end;

procedure EffFear(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER then begin
      Types.PCharacter(cr)^.npc := 0;
      Types.PCharacter(cr)^.quickfight := 0
    end;
    Types.PCharacter(cr)^.combatAddr^.turned := 0
  end
end;

procedure EffZapAttacker(var cr: Pointer; p: Pointer; removed: Boolean);
var
  savedValue: Integer;
  savedFlags: Word;
begin
  if removed then begin
  end else if CharHlp.CalcDistance(GDVars.curChar, cr) < 2 then begin
    savedValue := GDVars.pendingDamage;
    GDVars.pendingDamage := GDVars.pendingDamage shl 1;
    if GDVars.pendingDamage > 0 then begin
      savedFlags := GDVars.effectMask;
      GDVars.effectMask := 8;
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'gets zapped', 10, 1);
      FxEngine.InflictNonWeaponDamage(GDVars.curChar, GDVars.pendingDamage, 0, 0);
      GDVars.pendingDamage := savedValue;
      GDVars.effectMask := savedFlags
    end
  end
end;

procedure EffGiantStrength(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    CharHlp.PrintCreatureMessage(cr, GDConsts.gainsText + GDVars.effectNames^[113], 10, 1)
end;

procedure EffParalyzeGaze(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
  saved: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  reflected: Boolean;
  effect: Pointer;
begin
  if not removed then begin
    GDVars.spellFns.selectTarget(10, 1, GDVars.targetSelected);
    if CharHlp.EnemyTeam(cr) <> Byte(GDVars.spellTargets[1]^.side) then
      GDVars.targetSelected := False;
    if GDVars.targetSelected then begin
      GDVars.effectMask := $10;
      GDVars.effectTarget := GDVars.spellTargets[1];
      CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, 0);
      CharHlp.BuildIconFacings(18);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                      CbtMap.CombatCellX(GDVars.effectTarget),
                                      CbtMap.CombatCellY(GDVars.effectTarget), 4,
                  45);
      if CharHlp.HasEffect(cr, EffHndlr.GAZE_REFLECTABLE, effect) then begin
        reflected := False;
        if CharHlp.HasEffect(GDVars.effectTarget, EffHndlr.MIRROR_READY, effect) then begin
          CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'reflects it!', 12, 0);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.effectTarget),
                                          CbtMap.CombatCellY(GDVars.effectTarget),
                                          CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                      4, 45);
          reflected := True;
          GDVars.effectTarget := cr
        end
      end;
      saved := (FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 3) <> 0) or
        CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, effect);
      FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.HELD, 10, 12, 0, 1, Byte(saved),
                                    'paralyzed')
    end
  end
end;

procedure EffVorpal(var cr: Pointer; p: Pointer; removed: Boolean);
var
  foe: Types.PCharacter;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then
    if not removed then
      if GDVars.beheadOk then begin
        foe := Types.PCharacter(cr)^.combatAddr^.other;
        if (foe^.immunities and $20) = 0 then
          FxEngine.KillCreature(foe, C_Status.DEAD_STATUS, 'is beheaded')
      end
end;

procedure EffMultiAttackNewWeapons(var cr: Pointer; p: Pointer; removed: Boolean);
var
  message: String[40];
  strengthBonus: ShortInt;
begin
  message := '';
  strengthBonus := CharHlp.StrDamageAdjust(cr);
  case GDVars.attacksMade[1] of
    1:
      begin
        GDVars.pendingDamage := FxEngine.RollDice(1, 10) + 4 + strengthBonus;
        message := GDConsts.itemNameParts[20] + GDConsts.itemNameParts[114]
      end;
    2:
      begin
        GDVars.pendingDamage := FxEngine.RollDice(2, 4) + 4 + strengthBonus;
        message := GDConsts.itemNameParts[16] + GDConsts.itemNameParts[114]
      end;
    3:
      begin
        GDVars.pendingDamage := FxEngine.RollDice(1, 8) + 4 + strengthBonus;
        message := GDConsts.itemNameParts[18] + GDConsts.itemNameParts[114]
      end;
    4:
      begin
        GDVars.pendingDamage := FxEngine.RollDice(1, 8) + 4 + strengthBonus;
        message := GDConsts.itemNameParts[13] + GDConsts.itemNameParts[114]
      end;
    5:
      begin
        GDVars.pendingDamage := FxEngine.RollDice(1, 4) + 4 + strengthBonus;
        message := GDConsts.itemNameParts[4] + GDConsts.itemNameParts[114]
      end;
    6:
      begin
        GDVars.pendingDamage := FxEngine.RollDice(1, 6) + 4 + strengthBonus;
        message := GDConsts.itemNameParts[14] + GDConsts.itemNameParts[114]
      end
  end;
  TextRend.DisplayMessageWindow(23, 7, 38, 9, LightGreen, Black, True, message)
end;

procedure EffDancing(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  Dec(Types.PCharacter(cr)^.acCur[0], 4);
  Dec(Types.PCharacter(cr)^.acCur[1], 4)
end;

procedure EffResistFireDruid(var cr: Pointer; p: Pointer; removed: Boolean);
var
  remaining: Word;
begin
  if (GDVars.effectMask and 1) = 0 then begin
  end else begin
    remaining := Types.PEffect(p)^.strength * 12;
    if LongInt(remaining) > GDVars.pendingDamage then begin
      Dec(remaining, GDVars.pendingDamage);
      GDVars.pendingDamage := 0;
      Types.PEffect(p)^.strength := remaining div 12;
      if Types.PEffect(p)^.strength = 0 then
        FxEngine.RemoveEffect(cr, C_Effect.RESIST_FIRE_DRUID, nil)
    end else begin
      Dec(GDVars.pendingDamage, remaining);
      FxEngine.RemoveEffect(cr, C_Effect.RESIST_FIRE_DRUID, nil)
    end
  end
end;

procedure EffDragonFeared(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.pendingDamage > 2 then
    Dec(GDVars.pendingDamage, 2)
  else
    GDVars.pendingDamage := 0;
  Dec(GDVars.attackRoll, 2)
end;

procedure EffFireTouch(var cr: Pointer; p: Pointer; removed: Boolean);
var
  work: Types.PCharacter;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    work := Types.PCharacter(cr)^.combatAddr^.other;
    if work <> nil then begin
      GDVars.effectMask := 9;
      FxEngine.InflictNonWeaponDamage(work, FxEngine.RollDamageDice(2, 6), 2,
                                      Byte(FxEngine.RollSavingThrow(work, 4, 0)))
    end
  end
end;

procedure EffIronSkin(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  Inc(Types.PCharacter(cr)^.acCur[0], 4);
  Inc(Types.PCharacter(cr)^.acCur[1], 4)
end;

procedure EffMindBlank(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.CHARM);
  EffHndlr.NullifyAttack(C_Effect.CONFUSED);
  EffHndlr.NullifyAttack(C_Effect.HELD);
  EffHndlr.NullifyAttack(C_Effect.FEEBLEMIND);
  EffHndlr.NullifyAttack(C_Effect.FRIGHTENED)
end;

procedure EffNeedPlus2(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.LimitDamageByResistance(2)
end;

procedure EffImmuneGaze(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if (GDVars.effectMask and $10) <> 0 then
    GDVars.saveRoll := 20
end;

procedure EffNone(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffGrantItemEffect(var cr: Pointer; p: Pointer; removed: Boolean);
var
  itemEffect: Types.PItem;
begin
  GDVars.overrideFlag := 0;
  itemEffect := Types.PItem(p);
  if removed then
    FxEngine.RemoveEffect(cr, itemEffect^.effect, nil)
  else begin
    if itemEffect^.effect <> $17 then
      FxEngine.AddEffect(cr, itemEffect^.effect, 0, $FF, True);
    if itemEffect^.effect in [$3B, $9F] then
      FxEngine.CallEffectHandler(itemEffect^.effect, cr, nil, False)
  end
end;

procedure EffRedCrystal(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.gameState^.crystalsActive = 0 then begin
  end else if GDVars.cbTailFlag2 <> 0 then begin
  end else begin
      GDVars.gameState^.lastCrystal := 0;
      GDVars.gameState^.crystals := GDVars.gameState^.crystals or 1;
      GDVars.cbTailFlag3 := 1;
      FxEngine.RemoveEffect(cr, C_Effect.RED_CRYSTAL, nil);
      EffHndlr.ShowCrystalSmash
    end
end;

procedure EffGreenCrystal(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.gameState^.crystalsActive = 0 then begin
  end else if GDVars.cbTailFlag2 <> 0 then begin
  end else begin
      GDVars.gameState^.lastCrystal := 1;
      GDVars.gameState^.crystals := GDVars.gameState^.crystals or 2;
      GDVars.cbTailFlag3 := 1;
      FxEngine.RemoveEffect(cr, C_Effect.GREEN_CRYSTAL, nil);
      EffHndlr.ShowCrystalSmash
    end
end;

procedure EffBlueCrystal(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.gameState^.crystalsActive = 0 then begin
  end else if GDVars.cbTailFlag2 <> 0 then begin
  end else begin
      GDVars.gameState^.lastCrystal := 2;
      GDVars.gameState^.crystals := GDVars.gameState^.crystals or 4;
      GDVars.cbTailFlag3 := 1;
      FxEngine.RemoveEffect(cr, C_Effect.BLUE_CRYSTAL, nil);
      EffHndlr.ShowCrystalSmash
    end
end;

procedure ShowCrystalSmash;
var
  work2: Types.PCharacter;
  effect2: Pointer;
begin
  if GDVars.cbTailFlag3 <> 0 then begin
    GDVars.cbTailFlag3 := 0;
    GDVars.cbTailFlag2 := 1;
    work2 := GDVars.partyHead;
    while work2 <> nil do begin
      if work2^.inPlay <> 0 then
        if CharHlp.HasEffect(work2, C_Effect.RED_CRYSTAL, effect2) or CharHlp.HasEffect(work2, C_Effect.GREEN_CRYSTAL,
            effect2) or
            CharHlp.HasEffect(work2, C_Effect.BLUE_CRYSTAL, effect2) then begin
          GDVars.combatPanelDirty := 1;
          CbtMap.DisplayMapViewCentered(work2, 3, 1);
          CharHlp.CombatPrintCreatureInfo(work2);
          CharHlp.PrintCreatureMessage(work2, 'smashes a crystal', 10, 1);
          CbtMap.DisplayMapViewCentered(work2, 3, 0)
        end;
      work2 := work2^.next
    end
  end
end;

procedure EffInLove(var cr: Pointer; p: Pointer; removed: Boolean);
var
  loveIndex: Word;
  otherLoveIndex: Word;
  ally: Types.PCharacter;
  effect: Pointer;
begin
  if Types.PCharacter(cr)^.npc in [$80..$B2] then begin
    loveIndex := $106;
    otherLoveIndex := $105;
    ally := GDVars.relationA
  end else begin
    loveIndex := $105;
    otherLoveIndex := $106;
    ally := GDVars.relationB
  end;
  if GDConsts.currentCondition = 25 then begin
        if (GDConsts.effectCreature = nil) or (GDConsts.effectCreature = cr) then
          Exit;
        if GDConsts.effectCreature^.alignment in [2, 5, 8] then
          if GDVars.gameState^.gbvm[otherLoveIndex + 1] < $FE then
            Inc(GDVars.gameState^.gbvm[otherLoveIndex + 1], 2);
        if GDConsts.effectCreature^.alignment in [0, 3, 6] then
          if GDVars.gameState^.gbvm[otherLoveIndex + 1] >= $14 then
            Dec(GDVars.gameState^.gbvm[otherLoveIndex + 1], $14)
          else
            GDVars.gameState^.gbvm[otherLoveIndex + 1] := 0
  end else if GDConsts.currentCondition = C_Cond.ATTACKER_ATTACK_ROLL then begin
        if Types.PEffect(p)^.strength = 2 then
          Inc(GDVars.attackRoll, 2)
        else if Types.PEffect(p)^.strength = 1 then
          if GDVars.attackRoll > 2 then
            Dec(GDVars.attackRoll, 2)
          else
            GDVars.attackRoll := 0
        else if (GDVars.gameState^.gbvm[loveIndex + 1] >= 100) and
          (GDVars.gameState^.gbvm[otherLoveIndex + 1] >= 100) then
          Inc(GDVars.attackRoll)
        else if not ((((GDVars.gameState^.gbvm[loveIndex + 1] < 100) or
                       (GDVars.gameState^.gbvm[otherLoveIndex + 1] >= 50)) and (ally <> nil)) and
          (ally^.inPlay <> 0)) then
          if GDVars.attackRoll <> 0 then
            Dec(GDVars.attackRoll)
  end else if GDConsts.currentCondition = $10 then begin
    if Types.PEffect(p)^.strength = 1 then
      Inc(GDVars.attackRoll, 2)
    else if Types.PEffect(p)^.strength = 2 then
      Inc(GDVars.attackRoll, 2)
  end else if GDConsts.currentCondition = $0D then begin
    if ally <> nil then
        if ally^.inPlay <> 0 then
          if GDVars.gameState^.gbvm[otherLoveIndex + 1] >= 100 then
            if CharHlp.HasEffect(ally, C_Effect.IN_LOVE, effect) then
              if Types.PEffect(effect)^.strength <> 2 then begin
                GDVars.combatPanelDirty := 1;
                CbtMap.DisplayMapViewCentered(ally, 3, 1);
                CharHlp.CombatPrintCreatureInfo(ally);
                CharHlp.PrintCreatureMessage(ally, 'goes into frenzy', 10, 1);
                TextRend.PauseOnly;
                Types.PEffect(effect)^.strength := 2;
                if ally^.npc < C_Npc.NON_PLAYER then
                  ally^.npc := C_Npc.ANIMATED_PLAYER;
                ally^.quickfight := 1
              end
  end
end;

procedure EffHarpyTouch(var cr: Pointer; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
  saved: Boolean;
begin
  GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
  if GDVars.effectTarget = nil then begin
  end else if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.CHARM, p) then begin
  end else begin
    saved := Boolean(FxEngine.RollSavingThrow(GDVars.effectTarget, 4, 0));
    if not saved then begin
      FxEngine.AddEffect(GDVars.effectTarget, C_Effect.CHARM, 0, Types.PCharacter(cr)^.side * $80 + 3,
                         True);
      CharHlp.PrintCreatureMessage(GDVars.effectTarget, 'is charmed', 10, 1);
      if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.CHARM, p) then
        FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.effectTarget, p, False);
      cleared := CharHlp.EndActions(GDVars.effectTarget)
    end
  end
end;

procedure EffHalfElemental(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if ((GDVars.effectMask and 8) <> 0) or ((GDVars.effectMask and 2) <> 0) or ((GDVars.effectMask and 1) <> 0) or
        ((GDVars.effectMask and 4) <> 0) then
      GDVars.pendingDamage := GDVars.pendingDamage div 2
end;

procedure EffStoneFleshKills(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffGlacierArmor(var cr: Pointer; p: Pointer; removed: Boolean);
var
  linked: Types.PItem;
begin
  GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
  if GDVars.effectTarget = nil then begin
  end else begin
    linked := GDVars.effectTarget^.equipped[C_Equip.ARMOR];
    if linked <> nil then
      if (linked^.nameIds[1] = $80) or (linked^.nameIds[2] = $80) or (linked^.nameIds[3] = $80) then
        GDVars.pendingDamage := GDVars.pendingDamage div 2
  end
end;

procedure EffVulnerableToIcewindDale(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
  if item <> nil then
    if (item^.nameIds[1] = $7F) or (item^.nameIds[2] = $7F) or (item^.nameIds[3] = $7F) then
      GDVars.pendingDamage := GDVars.pendingDamage shl 1
end;

procedure EffSpitAcid(var cr: Pointer; p: Pointer; removed: Boolean);
var
  roll: Byte;
  selected: Boolean;
begin
  GDVars.spellFns.selectTarget($41, 1, selected);
  GDVars.effectTarget := GDVars.spellTargets[1];
  roll := FxEngine.RollDice(1, 100);
  if CharHlp.CalcDistance(cr, GDVars.effectTarget) < 7 then
    if GDVars.effectTarget <> nil then
      if roll <= 30 then begin
        CharHlp.PrintCreatureMessage(cr, 'Spits Acid', 10, 1);
        CharHlp.BuildIconFacings($17);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                        CbtMap.CombatCellX(GDVars.effectTarget),
                                        CbtMap.CombatCellY(GDVars.effectTarget), 1,
                    $1E);
        GDVars.effectMask := 0;
        FxEngine.InflictNonWeaponDamage(GDVars.effectTarget, FxEngine.RollDamageDice(1, 13) + 3, 2,
                               FxEngine.RollSavingThrow(GDVars.effectTarget, 3, 0))
      end else
        CharHlp.PrintCreatureMessage(cr, 'Spits Acid and Misses', 10, 1)
end;

procedure EffBreatheFireAdjacent(var cr: Pointer; p: Pointer; removed: Boolean);
var
  target: Pointer;
  selected: Boolean;
begin
  GDVars.spellFns.selectTarget(9, 1, selected);
  target := GDVars.spellTargets[1];
  if target <> nil then
    if CharHlp.CalcDistance(cr, target) < 2 then begin
      CharHlp.PrintCreatureMessage(cr, 'Breathes Fire', 10, 1);
      CharHlp.BuildIconFacings($17);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), CbtMap.CombatCellX(target),
                                      CbtMap.CombatCellY(target), 1, $1E);
      GDVars.effectMask := 1;
      FxEngine.InflictNonWeaponDamage(target, 7, 2, FxEngine.RollSavingThrow(target, 3, 0))
    end
end;

procedure EffVulnerableToStonecutting(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  if removed then begin
  end else begin
    item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
    if item <> nil then
      if (item^.nameIds[1] = $81) or (item^.nameIds[2] = $81) or (item^.nameIds[3] = $81) then
        GDVars.pendingDamage := GDVars.pendingDamage shl 1
  end
end;

procedure EffShapeChange(var cr: Pointer; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if not removed then
    case GDConsts.currentCondition of
      8:
      begin
        if GDConsts.shapeIconsLoaded then
          Exit;
        GDConsts.shapeIconsLoaded := True;
        for i := $26 to $2A do
          MapTiles.LoadIconAnim('CPIC', GDConsts.shapeIconBlocks[i], i)
      end;
      $1A:
      begin
        if not GDConsts.shapeIconsLoaded then
          Exit;
        GDConsts.shapeIconsLoaded := False;
        for i := $26 to $2A do
          MapTiles.FreeIconAnim(i)
      end;
      $13:
      begin
        if Types.PCharacter(cr)^.inPlay = 0 then
          Exit;
        if Types.PEffect(p)^.strength = $FF then begin
          CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, 8);
          GDVars.combatPanelDirty := 1;
          CbtMap.DisplayMapViewCentered(cr, 3, 1);
          CharHlp.CombatPrintCreatureInfo(cr);
          CharHlp.PrintNameStringAnim(cr, True, 'changes form');
          Types.PEffect(p)^.strength := Types.PCharacter(cr)^.icon;
          Types.PCharacter(cr)^.icon := Random(5) + $26;
          CbtMap.DisplayMapViewCentered(cr, 3, 1);
          TextRend.PauseOnly
        end else begin
          CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, 8);
          GDVars.combatPanelDirty := 1;
          CbtMap.DisplayMapViewCentered(cr, 3, 1);
          CharHlp.CombatPrintCreatureInfo(cr);
          CharHlp.PrintCreatureMessage(cr, 'changes back', 10, 1);
          Types.PCharacter(cr)^.icon := Types.PEffect(p)^.strength;
          CbtMap.DisplayMapViewCentered(cr, 3, 1);
          Types.PEffect(p)^.strength := $FF
        end
      end
    end
end;

procedure EffResistItemTypes(var cr: Pointer; p: Pointer; removed: Boolean);
var
  item: Types.PItem;
begin
  if removed then begin
  end else begin
    item := Types.PItem(EffHndlr.FindDamagingWeapon(GDVars.curChar));
    if item <> nil then
      if Byte(GDVars.baseItems[item^.itemType].wpnClass <= 1) <> 0 then
        GDVars.pendingDamage := GDVars.pendingDamage div 4;
    if (GDVars.baseItems[item^.itemType].props and $10) <> 0 then
      GDVars.pendingDamage := 0
  end
end;

procedure EffCancelAllAttacks(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if removed then begin
  end else
    EffHndlr.NullifyAttack(0)
end;

procedure EffThrowSpines(var cr: Pointer; p: Pointer; removed: Boolean);
type
  TLoopCounter = record
    value: Byte;
    { unused }
    valueTail: Byte
  end;
  TRangeValue = record
    value: Word;
    { unused }
    valueTail: Word
  end;
var
  i: TLoopCounter;
  range: TRangeValue;
  targetX: ShortInt;
  targetY: ShortInt;
begin
  GDVars.spellFns.selectTarget($41, 1, GDVars.targetSelected);
  GDVars.effectTarget := GDVars.spellTargets[1];
  targetX := CbtMap.CombatCellX(GDVars.effectTarget);
  targetY := CbtMap.CombatCellY(GDVars.effectTarget);
  range.value := 10;
  if GDVars.effectTarget <> nil then
    if GDVars.effectTarget^.inPlay <> 0 then
      if Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), targetX, targetY, range.value) then begin
        GDVars.combatPanelDirty := 1;
        CbtMap.DisplayMapViewCentered(cr, 3, 0);
        CharHlp.CombatPrintCreatureInfo(cr);
        CharHlp.BuildIconFacings($14);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                        CbtMap.CombatCellX(GDVars.effectTarget),
                                        CbtMap.CombatCellY(GDVars.effectTarget), 1,
                    $1E);
        CbtMap.DisplayMapViewCentered(GDVars.effectTarget, 3, 0);
        for i.value := 1 to 6 do
          if FxEngine.AttackRoll(cr, GDVars.effectTarget,
                                 GDVars.effectTarget^.acCur[0]) then begin
            CharHlp.PrintCreatureMessage(cr, 'Throws a Spine', 10, 1);
            GDVars.effectMask := 0;
            FxEngine.InflictNonWeaponDamage(GDVars.effectTarget, FxEngine.RollDamageDice(1, 6), 0, 0)
          end else begin
            CharHlp.PrintCreatureMessage(cr, 'Throws a Spine and Misses', 10, 1);
            Music.SendSoundCommand(GDConsts.soundIds[7])
          end
      end
end;

procedure EffCrush(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
  work: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  cleared: Boolean;
begin
  if GDConsts.currentCondition = 2 then begin
    if Types.PEffect(p)^.strength <> $FF then
      Exit;
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if GDVars.effectTarget <> nil then
      if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.CANNOT_MOVE, effect) then
        if GDVars.effectTarget^.inPlay <> 0 then begin
          FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.CANNOT_MOVE, 0, -1, 0, 1, 0,
                                        'is being crushed');
          if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.CANNOT_MOVE, effect) then begin
            FxEngine.CallEffectHandler(C_Effect.CANNOT_MOVE, GDVars.effectTarget, effect, False);
            FxEngine.AddEffect(cr, C_Effect.KAMPFULT_TENTACLES, 0, CbtMap.CombatSlot(GDVars.effectTarget),
                               False)
          end
        end
  end else if (GDConsts.currentCondition = $0D) or (GDConsts.currentCondition = $1B) then begin
    if (Types.PEffect(p)^.strength = $FF) or
        not CharHlp.HasEffect(GDVars.creatureArr[Types.PEffect(p)^.strength], C_Effect.CANNOT_MOVE, effect) then
      Exit;
    FxEngine.RemoveEffect(GDVars.creatureArr[Types.PEffect(p)^.strength], C_Effect.CANNOT_MOVE, nil);
    TextRend.PauseOnly;
    CharHlp.PrintCreatureMessage(GDVars.creatureArr[Types.PEffect(p)^.strength], 'is released', 10, 1)
  end else if GDConsts.currentCondition = $0E then begin
    if Types.PEffect(p)^.strength <> $FF then begin
      work := GDVars.creatureArr[Types.PEffect(p)^.strength];
      if CharHlp.HasEffect(work, C_Effect.CANNOT_MOVE, effect) then
        if work^.inPlay <> 0 then begin
          CharHlp.PrintCreatureMessage(cr, 'is crushing ' + PString(work)^, 10, 1);
          GDVars.effectMask := 0;
          FxEngine.InflictNonWeaponDamage(work, 5, 0, 0);
          cleared := CharHlp.EndActions(cr)
        end
    end
  end
end;

procedure EffDiseaseTouch(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effectNode: Pointer;
begin
  if FxEngine.RollDice(1, 100) <= 5 then begin
    GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
    if (GDVars.effectTarget = nil) or CharHlp.HasEffect(GDVars.effectTarget, C_Effect.DISEASED,
                                                          effectNode) then begin
    end else begin
        FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.DISEASED, 0, -1, 0, 1,
                             FxEngine.RollSavingThrow(GDVars.effectTarget, 0, 0), 'diseased');
        if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.DISEASED, effectNode) then
          FxEngine.CallEffectHandler(C_Effect.DISEASED, GDVars.effectTarget, effectNode, False)
      end
  end
end;

procedure EffFirstTurnDoubleMove(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if GDVars.cbRoundCounter = 0 then
    GDVars.fxScratchA := GDVars.fxScratchA shl 1
end;

procedure EffSlowAura(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
begin
  if not removed then begin
    if GDConsts.currentCondition = 5 then begin
      if Types.PEffect(p)^.strength = $FF then
        EffHndlr.LimitDamageByResistance(2)
    end else if GDConsts.currentCondition = $0E then begin
      if Types.PEffect(p)^.strength = $FF then begin
        GDVars.spellFns.selectTarget($41, 1, GDVars.targetSelected);
        GDVars.effectTarget := GDVars.spellTargets[1];
        if GDVars.effectTarget <> nil then
          if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.SLOWED, effect) then begin
            CharHlp.PrintCreatureMessage(cr, 'slows ' + PString(GDVars.effectTarget)^, 10, 1);
            CharHlp.BuildIconFacings($11);
            CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                            CbtMap.CombatCellX(GDVars.effectTarget),
                        CbtMap.CombatCellY(GDVars.effectTarget), 1, $1E);
            FxEngine.AddEffect(GDVars.effectTarget, C_Effect.SLOWED, 6, $FF, False)
          end
      end else begin
        Dec(Types.PEffect(p)^.strength);
        if Types.PEffect(p)^.strength = $FF then
          CharHlp.PrintCreatureMessage(cr, 'returns to stone', 10, 1)
      end
    end else if (GDConsts.currentCondition = 6) or (GDConsts.currentCondition = 9) then begin
      if not (GDVars.opMode in [0, $71]) then begin
        EffHndlr.NullifyAttack(0);
        GDVars.pendingDamage := 0
      end
    end
  end
end;

procedure EffBreatheStone(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
begin
  if not removed then
    if Types.PEffect(p)^.strength <> $FD then begin
      Dec(Types.PEffect(p)^.strength);
      GDVars.spellFns.selectTarget($41, 1, GDVars.targetSelected);
      GDVars.effectTarget := GDVars.spellTargets[1];
      if GDVars.effectTarget <> nil then
        if CharHlp.CalcDistance(cr, GDVars.effectTarget) < 3 then begin
          GDVars.targetSelected := CharHlp.EndActions(cr);
          CharHlp.PrintCreatureMessage(cr, 'Breathes', 10, 1);
          CharHlp.BuildIconFacings($17);
          CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                          CbtMap.CombatCellX(GDVars.effectTarget),
                                          CbtMap.CombatCellY(GDVars.effectTarget),
                      1, $1E);
          if FxEngine.RollSavingThrow(GDVars.effectTarget, 1, 0) = 0 then
            if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.IMMUNE_GAZE, effect) then
              FxEngine.KillCreature(GDVars.effectTarget, C_Status.PETRIFIED, 'is turned to stone')
        end
    end
end;

{ A grab attack: on a hit (conditions 2 and 3) with GDVars.attackRoll at least 20, the target 'has been grabbed' and
  cannot move, and the holder records it; each round (condition 14) the holder is 'squeezing' it for damageKind d
  damageSides and its turn ends; conditions 13 and 27 release it.
  @param(cr The creature the effect is on.)
  @param(p The effect record.)
  @param(removed Unused.)
  @param(damageKind The number of damage dice.)
  @param(damageSides Their sides.) }
procedure T20GrabHelper(cr, p: Pointer; removed: Boolean; damageKind, damageSides: Byte);
var
  effectGrab: Pointer;
  grabbedWork: Types.PCharacter;
begin
  if (GDConsts.currentCondition = $0D) or (GDConsts.currentCondition = $1B) then begin
    if (Types.PEffect(p)^.strength = $FF) or
        not CharHlp.HasEffect(GDVars.creatureArr[Types.PEffect(p)^.strength], C_Effect.CANNOT_MOVE, effectGrab) then
      Exit;
    FxEngine.RemoveEffect(GDVars.creatureArr[Types.PEffect(p)^.strength], C_Effect.CANNOT_MOVE, nil);
    if (GDVars.creatureArr[Types.PEffect(p)^.strength] <> nil) and
        (Types.PCharacter(GDVars.creatureArr[Types.PEffect(p)^.strength])^.inPlay <> 0) then begin
      TextRend.PauseOnly;
      CharHlp.PrintCreatureMessage(GDVars.creatureArr[Types.PEffect(p)^.strength], 'is released', 10, 1)
    end
  end else if (GDConsts.currentCondition = 2) or (GDConsts.currentCondition = 3) then begin
    if Types.PEffect(p)^.strength <> $FF then
      Exit;
    GDVars.effectTarget := Types.PCharacter(PPointer(cr)^)^.combatAddr^.other;
    if GDVars.effectTarget <> nil then
      if GDVars.attackRoll >= 20 then
        if not CharHlp.HasEffect(GDVars.effectTarget, C_Effect.CANNOT_MOVE, effectGrab) then
          if GDVars.effectTarget^.inPlay <> 0 then begin
            FxEngine.AddEffectWithMessage(GDVars.effectTarget, C_Effect.CANNOT_MOVE, 0, -1, 0, 1, 0,
                                          'has been grabbed');
            if CharHlp.HasEffect(GDVars.effectTarget, C_Effect.CANNOT_MOVE, effectGrab) then begin
              FxEngine.CallEffectHandler(C_Effect.CANNOT_MOVE, GDVars.effectTarget, effectGrab, False);
              FxEngine.AddEffect(PPointer(cr)^, Types.PEffect(p)^.id, 0,
                                 CbtMap.CombatSlot(GDVars.effectTarget), False)
            end
          end
  end else if GDConsts.currentCondition = $0E then begin
    if Types.PEffect(p)^.strength <> $FF then begin
      grabbedWork := GDVars.creatureArr[Types.PEffect(p)^.strength];
      if CharHlp.HasEffect(grabbedWork, C_Effect.CANNOT_MOVE, effectGrab) then
        if grabbedWork^.inPlay <> 0 then begin
          CharHlp.PrintCreatureMessage(PPointer(cr)^, 'is squeezing ' + PString(grabbedWork)^, 10, 1);
          GDVars.effectMask := 0;
          FxEngine.InflictNonWeaponDamage(grabbedWork, FxEngine.RollDice(damageKind, damageSides), 0, 0);
          GDVars.targetSelected := CharHlp.EndActions(PPointer(cr)^)
        end
    end
  end
end;

procedure EffGrab2d8(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.T20GrabHelper(@cr, p, removed, 2, 8)
end;

procedure EffGrab4d5(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.T20GrabHelper(@cr, p, removed, 4, 5)
end;

procedure EffGrab6d4(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  EffHndlr.T20GrabHelper(@cr, p, removed, 6, 4)
end;

procedure EffFrightenAura(var cr: Pointer; p: Pointer; removed: Boolean);
var
  effect: Pointer;
  walker: Types.PCharacter;
begin
  GDVars.effectInProgress := 1;
  effect := nil;
  walker := GDVars.partyHead;
  while walker <> nil do begin
    if walker^.side <> Types.PCharacter(cr)^.side then
      if walker^.status = 0 then
        if Byte(GDVars.gameState^.field53 <> 0) <> 0 then
          if FxEngine.RollSavingThrow(walker, 1, 0) = 0 then
            if not CharHlp.HasEffect(walker, C_Effect.FRIGHTENED, effect) then begin
              FxEngine.AddEffectWithMessage(walker, C_Effect.FRIGHTENED, 2, -1, 1, 1, 0, 'is frightened.');
              if CharHlp.HasEffect(walker, C_Effect.FRIGHTENED, p) then begin
                walker^.combatAddr^.turned := 1;
                walker^.quickfight := 1;
                if walker^.npc <= $7F then
                  walker^.npc := $B3;
                walker^.combatAddr^.other := nil
              end
            end;
    walker := walker^.next
  end;
  GDVars.effectInProgress := 0
end;

procedure EffFireVulnerable(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.effectMask and 1) <> 0 then
      Inc(GDVars.pendingDamage, GDVars.pendingDamage div 2)
end;

procedure EffBreatheIce(var cr: Pointer; p: Pointer; removed: Boolean);
var
  target: Pointer;
  selected: Boolean;
begin
  GDVars.spellFns.selectTarget(9, 1, selected);
  target := GDVars.spellTargets[1];
  if target <> nil then
    if CharHlp.CalcDistance(cr, target) < 2 then begin
      CharHlp.PrintCreatureMessage(cr, 'Breathes Ice', 10, 1);
      CharHlp.BuildIconFacings($12);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), CbtMap.CombatCellX(target),
                                      CbtMap.CombatCellY(target), 1, $1E);
      GDVars.effectMask := 2;
      FxEngine.InflictNonWeaponDamage(target, 7, 2, FxEngine.RollSavingThrow(target, 3, 0))
    end
end;

procedure EffSwallow(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  GDVars.effectTarget := Types.PCharacter(cr)^.combatAddr^.other;
  if GDVars.effectTarget <> nil then
    if GDVars.attackRoll >= $14 then
      if GDVars.effectTarget^.inPlay <> 0 then
        FxEngine.KillCreature(GDVars.effectTarget, C_Status.DEAD_STATUS, 'is swallowed')
end;

procedure EffCannotMove(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  Types.PCharacter(cr)^.combatAddr^.movement := 0
end;

procedure EffShockVulnerable(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.effectMask and 4) <> 0 then
      Inc(GDVars.pendingDamage, GDVars.pendingDamage div 2)
end;

procedure EffImmuneToWeather(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure EffEmpowered(var cr: Pointer; p: Pointer; removed: Boolean);
begin
  CharHlp.PrintCreatureMessage(cr, 'Is empowered', 10, 1);
  Types.PEffect(p)^.duration := FxEngine.RollDice(1, 4) * 10 + 40
end;

procedure EffWearingMagicalBoots(var cr: Pointer; p: Pointer; removed: Boolean);
begin
end;

procedure InitEffectHandlers;
begin
  GDVars.effectHandlers[1] := EffHndlr.EffBless;
  GDVars.effectHandlers[2] := EffHndlr.EffCurse;
  GDVars.effectHandlers[3] := EffHndlr.EffSticksToSnakes;
  GDVars.effectHandlers[4] := EffHndlr.EffDispelEvil;
  GDVars.effectHandlers[5] := EffHndlr.EffNone;
  GDVars.effectHandlers[6] := EffHndlr.EffImmuneElectricity;
  GDVars.effectHandlers[7] := EffHndlr.EffGnomeHitBonus;
  GDVars.effectHandlers[8] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[9] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[10] := EffHndlr.EffResistCold;
  GDVars.effectHandlers[11] := EffHndlr.EffCharm;
  GDVars.effectHandlers[12] := EffHndlr.EffExtraStr;
  GDVars.effectHandlers[13] := EffHndlr.EffBarkskin;
  GDVars.effectHandlers[14] := EffHndlr.EffFriends;
  GDVars.effectHandlers[15] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectHandlers[16] := EffHndlr.EffReadMagic;
  GDVars.effectHandlers[17] := EffHndlr.EffShield;
  GDVars.effectHandlers[18] := EffHndlr.EffHalfElfResistance;
  GDVars.effectHandlers[19] := EffHndlr.EffNone;
  GDVars.effectHandlers[20] := EffHndlr.EffResistFire;
  GDVars.effectHandlers[21] := EffHndlr.EffSilence;
  GDVars.effectHandlers[22] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectHandlers[23] := EffHndlr.EffSpiritualHammer;
  GDVars.effectHandlers[24] := EffHndlr.EffNone;
  GDVars.effectHandlers[25] := EffHndlr.EffInvisible;
  GDVars.effectHandlers[26] := EffHndlr.EffDwarfHitBonus;
  GDVars.effectHandlers[27] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[28] := EffHndlr.EffMirrorImage;
  GDVars.effectHandlers[29] := EffHndlr.EffEnfeeble;
  GDVars.effectHandlers[30] := EffHndlr.EffCoughing;
  GDVars.effectHandlers[31] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[32] := EffHndlr.EffDispelEvilTouch;
  GDVars.effectHandlers[33] := EffHndlr.EffBlind;
  GDVars.effectHandlers[34] := EffHndlr.EffDiseased;
  GDVars.effectHandlers[35] := EffHndlr.EffConfusion;
  GDVars.effectHandlers[36] := EffHndlr.EffBestowCurse;
  GDVars.effectHandlers[37] := EffHndlr.EffBlinking;
  GDVars.effectHandlers[38] := EffHndlr.EffExtraStr;
  GDVars.effectHandlers[39] := EffHndlr.EffHasted;
  GDVars.effectHandlers[40] := EffHndlr.EffRakshasaProt;
  GDVars.effectHandlers[41] := EffHndlr.EffProtNormalMissiles;
  GDVars.effectHandlers[42] := EffHndlr.EffSlowed;
  GDVars.effectHandlers[43] := EffHndlr.EffDiseaseStrength;
  GDVars.effectHandlers[44] := EffHndlr.EffDiseaseHitPoints;
  GDVars.effectHandlers[45] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[46] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[47] := EffHndlr.EffDwarfGiantDefense;
  GDVars.effectHandlers[48] := EffHndlr.EffGnomeBugDefense;
  GDVars.effectHandlers[49] := EffHndlr.EffPrayer;
  GDVars.effectHandlers[50] := EffHndlr.EffFireShieldHot;
  GDVars.effectHandlers[51] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[52] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[53] := EffHndlr.EffClearGuard;
  GDVars.effectHandlers[54] := EffHndlr.EffFireShieldCold;
  GDVars.effectHandlers[55] := EffHndlr.EffPoisoned;
  GDVars.effectHandlers[56] := EffHndlr.EffRenewInvisibility;
  GDVars.effectHandlers[57] := EffHndlr.EffGlobeInvuln;
  GDVars.effectHandlers[58] := EffHndlr.EffPetrifyingGaze;
  GDVars.effectHandlers[59] := EffHndlr.EffGazeReflectable;
  GDVars.effectHandlers[60] := EffHndlr.EffNeedPlus3;
  GDVars.effectHandlers[61] := EffHndlr.EffRingFireRes;
  GDVars.effectHandlers[62] := EffHndlr.EffConRegeneration;
  GDVars.effectHandlers[63] := EffHndlr.EffMinorGlobe;
  GDVars.effectHandlers[64] := EffHndlr.EffPoisonAttack;
  GDVars.effectHandlers[65] := EffHndlr.EffPetrifyTouch;
  GDVars.effectHandlers[66] := EffHndlr.EffHalfDamageFromWeaponClass;
  GDVars.effectHandlers[67] := EffHndlr.EffHalfDmgCrush;
  GDVars.effectHandlers[68] := EffHndlr.EffFeeblemind;
  GDVars.effectHandlers[69] := EffHndlr.EffInvisibleToAnimals;
  GDVars.effectHandlers[70] := EffHndlr.EffConfusionGaze;
  GDVars.effectHandlers[71] := EffHndlr.EffHighlighted;
  GDVars.effectHandlers[72] := EffHndlr.EffMirrorReady;
  GDVars.effectHandlers[73] := EffHndlr.EffImmuneBreath;
  GDVars.effectHandlers[74] := EffHndlr.EffMagicBoots;
  GDVars.effectHandlers[75] := EffHndlr.EffGiantSlayingSword;
  GDVars.effectHandlers[76] := EffHndlr.EffImmuneDisease;
  GDVars.effectHandlers[77] := EffHndlr.EffConfusedBerserk;
  GDVars.effectHandlers[78] := EffHndlr.EffMagicalStone;
  GDVars.effectHandlers[79] := EffHndlr.EffIronGolem;
  GDVars.effectHandlers[80] := EffHndlr.EffLuckStone;
  GDVars.effectHandlers[81] := EffHndlr.EffHalfDmgWeaponLt3;
  GDVars.effectHandlers[82] := EffHndlr.EffBlessedBoltKills;
  GDVars.effectHandlers[86] := EffHndlr.EffStrongPoisonAttack;
  GDVars.effectHandlers[87] := EffHndlr.EffNone;
  GDVars.effectHandlers[88] := EffHndlr.EffParalyzingPoison;
  GDVars.effectHandlers[89] := EffHndlr.EffDisplaced;
  GDVars.effectHandlers[92] := EffHndlr.EffImmuneFear;
  GDVars.effectHandlers[93] := EffHndlr.EffImmuneFire;
  GDVars.effectHandlers[94] := EffHndlr.EffConPsnSave;
  GDVars.effectHandlers[95] := EffHndlr.EffElfResistance;
  GDVars.effectHandlers[97] := EffHndlr.EffConSpellSave;
  GDVars.effectHandlers[98] := EffHndlr.EffNoCold;
  GDVars.effectHandlers[99] := EffHndlr.EffBulletRake;
  GDVars.effectHandlers[100] := EffHndlr.EffDragonFear;
  GDVars.effectHandlers[101] := EffHndlr.EffDrainOne;
  GDVars.effectHandlers[102] := EffHndlr.EffDrainTwo;
  GDVars.effectHandlers[103] := EffHndlr.EffNeedMagic;
  GDVars.effectHandlers[104] := EffHndlr.EffFireDmg4d6;
  GDVars.effectHandlers[105] := EffHndlr.EffRangerDamageBonus;
  GDVars.effectHandlers[106] := EffHndlr.EffStunned;
  GDVars.effectHandlers[107] := EffHndlr.EffBerserk;
  GDVars.effectHandlers[108] := EffHndlr.EffFireDmg2d6;
  GDVars.effectHandlers[109] := EffHndlr.EffNone;
  GDVars.effectHandlers[110] := EffHndlr.EffRecentCure;
  GDVars.effectHandlers[111] := EffHndlr.EffFear;
  GDVars.effectHandlers[112] := EffHndlr.EffZapAttacker;
  GDVars.effectHandlers[113] := EffHndlr.EffGiantStrength;
  GDVars.effectHandlers[114] := EffHndlr.EffParalyzeGaze;
  GDVars.effectHandlers[115] := EffHndlr.EffVorpal;
  GDVars.effectHandlers[116] := EffHndlr.EffMultiAttackNewWeapons;
  GDVars.effectHandlers[117] := CbtActs.AttackEyeRays;
  GDVars.effectHandlers[118] := EffHndlr.EffDancing;
  GDVars.effectHandlers[119] := EffHndlr.EffResistFireDruid;
  GDVars.effectHandlers[120] := EffHndlr.EffDragonFeared;
  GDVars.effectHandlers[121] := EffHndlr.EffFireTouch;
  GDVars.effectHandlers[122] := EffHndlr.EffIronSkin;
  GDVars.effectHandlers[123] := EffHndlr.EffMindBlank;
  GDVars.effectHandlers[125] := EffHndlr.EffNeedPlus2;
  GDVars.effectHandlers[126] := EffHndlr.EffImmuneGaze;
  GDVars.effectHandlers[127] := EffHndlr.EffGrantItemEffect;
  GDVars.effectHandlers[128] := EffHndlr.EffRedCrystal;
  GDVars.effectHandlers[129] := EffHndlr.EffGreenCrystal;
  GDVars.effectHandlers[130] := EffHndlr.EffBlueCrystal;
  GDVars.effectHandlers[131] := EffHndlr.EffInLove;
  GDVars.effectHandlers[132] := EffHndlr.EffHarpyTouch;
  GDVars.effectHandlers[133] := EffHndlr.EffHalfElemental;
  GDVars.effectHandlers[134] := EffHndlr.EffStoneFleshKills;
  GDVars.effectHandlers[135] := EffHndlr.EffGlacierArmor;
  GDVars.effectHandlers[136] := EffHndlr.EffVulnerableToIcewindDale;
  GDVars.effectHandlers[137] := EffHndlr.EffSpitAcid;
  GDVars.effectHandlers[138] := EffHndlr.EffBreatheFireAdjacent;
  GDVars.effectHandlers[139] := EffHndlr.EffVulnerableToStonecutting;
  GDVars.effectHandlers[140] := EffHndlr.EffShapeChange;
  GDVars.effectHandlers[141] := EffHndlr.EffResistItemTypes;
  GDVars.effectHandlers[142] := EffHndlr.EffCancelAllAttacks;
  GDVars.effectHandlers[143] := EffHndlr.EffThrowSpines;
  GDVars.effectHandlers[144] := EffHndlr.EffCrush;
  GDVars.effectHandlers[145] := EffHndlr.EffDiseaseTouch;
  GDVars.effectHandlers[146] := EffHndlr.EffFirstTurnDoubleMove;
  GDVars.effectHandlers[147] := EffHndlr.EffSlowAura;
  GDVars.effectHandlers[148] := EffHndlr.EffBreatheStone;
  GDVars.effectHandlers[149] := EffHndlr.EffGrab2d8;
  GDVars.effectHandlers[150] := EffHndlr.EffGrab4d5;
  GDVars.effectHandlers[151] := EffHndlr.EffGrab6d4;
  GDVars.effectHandlers[152] := EffHndlr.EffFrightenAura;
  GDVars.effectHandlers[153] := EffHndlr.EffFireVulnerable;
  GDVars.effectHandlers[154] := EffHndlr.EffBreatheIce;
  GDVars.effectHandlers[155] := EffHndlr.EffSwallow;
  GDVars.effectHandlers[156] := EffHndlr.EffCannotMove;
  GDVars.effectHandlers[157] := EffHndlr.EffShockVulnerable;
  GDVars.effectHandlers[158] := EffHndlr.EffImmuneToWeather;
  GDVars.effectHandlers[159] := EffHndlr.EffEmpowered;
  GDVars.effectHandlers[160] := EffHndlr.EffWearingMagicalBoots;
end;

begin
end.
