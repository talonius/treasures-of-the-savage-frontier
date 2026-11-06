{ FxEngine -- the effect engine. It adds, removes and cures effects, runs their handlers (EffHndlr) for each combat
  condition, rolls dice, attacks and saving throws, deals non-weapon damage, kills, heals and revives creatures,
  recomputes stats from items and effects, and ages the clouds. The interface is in trap order (23 traps); trap 3 is the
  effect-removal entry EffHndlr calls. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit FxEngine;

interface

uses Types, GDConsts, GDVars, C_Effect, C_Terr, C_Dir, C_Status, C_Cond, C_Stat,
  C_Class, C_Ifc, C_Item, C_Npc, CharHlp, Pathing, CbtMap, Blit, TextRend;

{ Kills cr with the death status given, after announcing message. Its hit points go to zero, it loses the effects that
  end at zero hit points, the death condition (13) fires, condition 25 fires with cr as GDConsts.effectCreature when it
  is out of play, and the body is handed to the combat map unless the status is 10. Outside combat the party display is
  redrawn. A creature already dead (status 6, 7 or 8) is left alone.
  @param(cr The creature, a Types.PCharacter.)
  @param(kind The death status.)
  @param(message The announcement.) }
procedure KillCreature(cr: Pointer; kind: Byte; message: Types.TStr40);

{ Calls the handler for an effect. While the item-effect override flag is set, each call goes to handler 127 instead.
  @param(effectId The effect.)
  @param(cr The creature, passed on to the handler.)
  @param(p The effect record or item that owns the effect, passed on.)
  @param(removed True when the effect is being removed, passed on.) }
procedure CallEffectHandler(effectId: Byte; var cr; p: Pointer; removed: Boolean);

{ Removes an effect from a creature. A record that asks to be told of its removal has its handler called first. Losing
  the friends effect recalculates charisma; losing enlarge, strength or giant strength recalculates strength.
  @param(cr The creature, a Types.PCharacter.)
  @param(effectId The effect.)
  @param(node The record to remove, or nil for the first record with that id.) }
procedure RemoveEffect(cr: Pointer; effectId: Byte; node: Pointer);

{ Raise a condition on a creature: run the handlers of the effects that answer it, in a fixed order for each condition.
  Conditions 6 and 9 also apply magic resistance, and 6 immunity.
  @param(condition The condition, kept in GDConsts.currentCondition while the handlers run.)
  @param(cr The creature; nil does nothing.) }
procedure TriggerEffectsWithCondition(condition: Byte; var cr);

{ Applies the hazard a creature in play stands in; the map scrolls to it first unless it is fully in view. Stinking
  cloud (unless `skipCloud`): undead, the helpless and creatures immune to it are spared; a save means coughing for
  1d4+1, and a creature casting a spell loses it and its turn ends; a failure means nausea (helpless) for 1d4+1.
  Cloudkill (unless immune): up to 4 hit dice dies, 5 saves at -4, 6 saves normally, more takes 1d10. Blade barrier:
  unless magic resistance clears the pending damage, knives for 8d8 (save type 4 when `allowSave`).
  @param(cr The creature.)
  @param(allowSave True grants a saving throw against the blade barrier.)
  @param(skipCloud True ignores a stinking cloud.) }
procedure ConsiderTerrainEffects(cr: Pointer; allowSave, skipCloud: Boolean);

{ Rolls to hit a creature when no creature is attacking, as with traps and hazards. A natural 1 misses; a natural 20
  counts as 100. The beheading flag is left set only for a hit on a natural 17 or better.
  @param(defender The creature attacked.)
  @param(sixtyMinusThac0 Added to the roll.)
  @returns(True when the roll plus the to-hit value exceeds the defender's armor class value.) }
function AttackRollNoAttacker(defender: Pointer; sixtyMinusThac0: Byte): Boolean;

{ Rolls to hit for an attacker against a defender. Attacking breaks invisibility; event 10 fires on the attacker and 16
  on the defender. The party's to-hit modifier is shifted by difficulty (+2 at level 1 down to -2 at level 5); monsters
  use their own fixed modifier. The beheading flag is left set only for a hit on a natural 17 or better.
  @param(attacker The attacker.)
  @param(target The defender.)
  @param(amount The roll needed.)
  @returns(True when the roll plus the attacker's THAC0 adjustment and the modifier reaches the roll needed.) }
function AttackRoll(attacker, target: Pointer; amount: Byte): Boolean;

{ Rolls a saving throw for a creature. A natural 1 fails and a natural 20 saves; effect 118 makes each save fail.
  Otherwise the roll, plus the creature's save bonus and the modifier, must reach its save value; condition 12 lets
  effects adjust the roll first. The modified roll and the result are kept for later checks.
  @param(cr The creature.)
  @param(kind The saving throw.)
  @param(damage The modifier added to the roll.)
  @returns(True, or 1, when the creature saved.) }
function RollSavingThrow(cr: Pointer; kind, damage: ShortInt): Byte;

{ Rolls a number of dice and adds them up.
  @param(n Number of dice; 0 rolls nothing.)
  @param(sides Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(n, sides: Byte): Byte;

{ Rolls damage dice, recording the number of dice for the resistances.
  @param(n Number of dice.)
  @param(sides Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(n, sides: Byte): Word;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(cr The creature.)
  @param(effectId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(permanent True to call the effect's handler when it is removed.) }
procedure AddEffect(cr: Pointer; effectId: Byte; minutes: Word; strength: Byte; permanent: Boolean);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(cr The creature.)
  @param(status Its new status.)
  @param(message The message.) }
procedure PutOutOfPlayWithStatus(cr: Pointer; status: Byte; message: Types.TStr40);

{ Removes each invisibility effect from a creature.
  @param(cr The creature.) }
procedure RemoveInvisibility(cr: Pointer);

{ Removes the effects a creature loses when its hit points reach zero, under trigger condition 28. A creature under
  effect 77 whose npc value is $B3 returns to the party's side.
  @param(cr The creature, a Types.PCharacter.) }
procedure RemoveEffectsHp0(cr: Pointer);

{ Cures a creature of an effect: when it has the effect, prints that it is cured and removes the node.
  @param(cr The creature.)
  @param(effectId The effect.)
  @returns(True when the creature had the effect.) }
function RemoveEffectWithMessage(cr: Pointer; effectId: Byte): Boolean;

{ Tells whether a strength would be higher than a creature's natural strength.
  @param(cr The creature.)
  @param(baseStr The strength score.)
  @param(excStr Its exceptional strength.)
  @param(effectStrength Receives the strength packed as StrengthModifier packs it, when it is higher.)
  @returns(True when it is higher.) }
function AdjustForNewStrength(cr: Pointer; baseStr, excStr: Byte; var effectStrength: Byte): Boolean;

{ Deal non-weapon damage: raise condition 6, and on a save (flag) take none (kind 1) or half (kind 2), else raise
  condition 20. Report the damage and its type, lose a spell being cast, and handle a creature that goes down.
  @param(cr The creature, a Types.PCharacter.)
  @param(damage The damage.)
  @param(kind What a successful save does: 1 cancels the damage, 2 halves it.)
  @param(flag Nonzero when the creature saved.) }
procedure InflictNonWeaponDamage(cr: Pointer; damage: Integer; kind, flag: Byte);

{ Gives a creature an effect, announcing it. Effects that block it react first (condition 9) and may cancel it; the
  effect also fails when the creature saved and a save negates it. Either way the creature is reported unaffected.
  Otherwise the effect is added, replacing an instance that still has time to run, and the message, if any, is shown.
  @param(cr The creature.)
  @param(effectId The effect.)
  @param(minutes Its duration.)
  @param(effectStrength Its strength.)
  @param(onRemove Set to have its handler called when it is removed.)
  @param(saveNegates Set when a successful save stops the effect.)
  @param(outcome Set when the creature saved.)
  @param(message The announcement, or empty.) }
procedure AddEffectWithMessage(cr: Pointer; effectId: Byte; minutes: Word; effectStrength: ShortInt; onRemove,
                               saveNegates, outcome: Byte; message: Types.TStr40);

{ Heals a creature, up to its maximum, if its status allows healing (0, 1, 4 or 5). A dying creature becomes
  unconscious; outside combat an unconscious one gets back on its feet.
  @param(cr The creature.)
  @param(amount The hit points restored.)
  @param(show True leaves a creature already at full hit points alone.)
  @returns(True if healing was applied.) }
function RestoreHitPoints(cr: Pointer; amount: Byte; show: Boolean): Boolean;

{ Brings a creature back to life in its own square, announcing it, if that square can still take it. In combat the map
  is redrawn around it.
  @param(cr The creature.)
  @param(hp Its hit points.)
  @param(message The announcement.)
  @returns(True on success.) }
function ReviveDeadCreature(cr: Pointer; hp: Byte; message: Types.TStr40): Boolean;

{ Recomputes one ability of a creature from its base value and whatever modifies it, and stores the current value.
  Readied special items other than types 39 and 40 adjust strength and dexterity. Strength takes the best of magic items
  and the strength, giant strength and enlarge effects; constitution also recomputes maximum hit points and gives
  regeneration at 20 or more; charisma adds the friends effect; feeblemind sets intelligence and wisdom to 3.
  @param(cr The creature, a Types.PCharacter.)
  @param(stat The ability: 0 strength, 1 intelligence, 2 wisdom, 3 dexterity, 4 constitution, 5 charisma.) }
procedure RecalcAbility(cr: Pointer; stat: ShortInt);

{ Removes expired terrain patches (stinking clouds and the like) from the combat map, putting back the terrain they
  covered, or the occupied marker where a downed creature lies. Remaining patches are then repainted and the change
  announced.
  @param(expiredOnly Set to remove only patches already marked expired, as dispelling does; clear to count each patch
    down and remove it when its time runs out.) }
procedure CountDownAreaEffects(expiredOnly: Byte);

implementation

const
  { effect ids only this unit names }
  { Protected from Good }
  EFF_PROT_GOOD = 9;
  { Resistant to Cold }
  EFF_RESIST_COLD = 10;
  { Barkskin }
  EFF_BARKSKIN = 13;
  { Friendly }
  EFF_FRIENDS = 14;
  { Enfeebled }
  EFF_ENFEEBLE = 29;
  { Blinking }
  EFF_BLINK = 37;
  { Rakshasa Protection }
  EFF_RAKSHASA_PROT = 40;
  { Protected from Evil, 10' Radius }
  EFF_PROT_EVIL_10 = 45;
  { Protected from Good, 10' Radius }
  EFF_PROT_GOOD_10 = 46;
  { Invisible (ring) }
  EFF_INVISIBLE_RING = 56;
  { Petrification Gaze Attack }
  EFF_STONE_GAZE = 58;
  { Fire Resistant }
  EFF_RESIST_FIRE_RING = 61;
  { Regeneration }
  EFF_REGENERATION = 62;
  { Petrification Touch Attack }
  EFF_PETRIFY_TOUCH = 65;
  { Invisible to Animals }
  EFF_INVIS_TO_ANIMALS = 69;
  { confusion gaze }
  EFF_CONFUSION_GAZE = 70;
  { Magically Highlighted }
  EFF_HIGHLIGHTED = 71;
  { Immune to Dragon Breath }
  EFF_IMMUNE_DRAGON_BREATH = 73;
  { giant slaying sword }
  EFF_GIANT_SLAYING_SWORD = 75;
  { Immune to Disease }
  EFF_IMMUNE_DISEASE = 76;
  { iron golem spell immunity }
  EFF_IRON_GOLEM_IMMUNITY = 79;
  { killed by blessed crossbow bolts }
  EFF_BLESSED_BOLT_KILLS = 82;
  { deadly poison -2 }
  EFF_DEADLY_POISON_M2 = 86;
  { paralzing poison }
  EFF_PARALYZING_POISON = 88;
  { Wearing Magical Cloak }
  EFF_MAGIC_CLOAK = 89;
  { dwarven save bonus }
  EFF_DWARF_SAVE_94 = 94;
  { immune to cold }
  EFF_IMMUNE_COLD = 98;
  { bullet rake attack }
  EFF_BULLET_RAKE = 99;
  { dragon fear attack }
  EFF_DRAGON_FEAR_ATTACK = 100;
  { drain 2 levels }
  EFF_DRAIN_2_LEVELS = 102;
  { +4d6 fire damage }
  EFF_FIRE_DMG_4D6 = 104;
  { +2d6 fire damage }
  EFF_FIRE_DMG_2D6 = 108;
  { vorpal weapon }
  EFF_VORPAL = 115;
  { multiple attacks by new weapons }
  EFF_MULTI_ATTACK_NEW_WEAPONS = 116;
  { Effect #117 }
  EFF_BEHOLDER_EYE_RAYS = 117;
  { Fire Touch }
  EFF_FIRE_TOUCH = 121;
  { Iron Skin }
  EFF_IRON_SKIN = 122;
  { Shielded by Mind Blank }
  EFF_MIND_BLANK = 123;
  { Harpy Touch }
  EFF_HARPY_TOUCH = 132;
  { Half Damage Cold/fire/elec }
  EFF_HALF_DMG_COLD_FIRE_ELEC = 133;
  { glacier armor }
  EFF_GLACIER_ARMOR = 135;
  { icewind sword }
  EFF_ICEWIND_SWORD = 136;
  { spit acid }
  EFF_SPIT_ACID = 137;
  { hellhound breath }
  EFF_HELLHOUND_BREATH = 138;
  { stone sword }
  EFF_STONE_SWORD = 139;
  { Shape Changing }
  EFF_SHAPE_CHANGING = 140;
  { 1/4 damage from edged }
  EFF_QUARTER_DMG_EDGED = 141;
  { no pois/hol/chrm/par/fr }
  EFF_MULTI_IMMUNITY = 142;
  { Manticore Spine }
  EFF_MANTICORE_SPINE = 143;
  { Rat disease }
  EFF_RAT_DISEASE = 145;
  { 1st turn double move }
  EFF_FIRST_TURN_DOUBLE_MOVE = 146;
  { Stone Breath }
  EFF_STONE_BREATH = 148;
  { Yetti squeeze 1 }
  EFF_YETI_SQUEEZE_1 = 149;
  { Yetti squeeze 2 }
  EFF_YETI_SQUEEZE_2 = 150;
  { Fear on surprise }
  EFF_FEAR_ON_SURPRISE = 152;
  { +50% damage from fire }
  EFF_FIRE_VULNERABLE = 153;
  { Icehound breath }
  EFF_ICEHOUND_BREATH = 154;
  { Swallow whole }
  EFF_SWALLOW_WHOLE = 155;

const
  { FxEngine.TriggerEffectsWithCondition condition codes only this unit raises }
  { damage about to be taken }
  COND_DAMAGE_TAKEN = 6;
  { rolling a saving throw }
  COND_SAVING_THROW = 12;
  { being attacked }
  COND_ATTACK_ROLL_DEF = 16;
  { damage taken without a save }
  COND_DAMAGE_NOT_SAVED = 20;

{ Tells whether an item is of type 39 or 40, whose special powers RecalcAbility ignores.
  @param(item The item, or nil.)
  @returns(True for those types.) }
function IsSpecialItem(item: Types.PItem): Boolean;
begin
  if (item <> nil) and ((item^.itemType = $27) or (item^.itemType = $28)) then
    IsSpecialItem := True
  else IsSpecialItem := False
end;

procedure KillCreature(cr: Pointer; kind: Byte; message: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(cr, message, 10, 0);
  case Types.PCharacter(cr)^.status of
    C_Status.PETRIFIED, C_Status.DEAD_STATUS, C_Status.GONE: ;
  else begin
    Types.PCharacter(cr)^.status := kind;
    Types.PCharacter(cr)^.inPlay := 0;
    Types.PCharacter(cr)^.hpCur := 0;
    FxEngine.RemoveEffectsHp0(cr);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ZERO_HIT_POINTS, cr);
    GDConsts.effectCreature := cr;
    if Types.PCharacter(cr)^.inPlay = 0 then FxEngine.TriggerEffectsWithCondition(25, GDVars.curChar);
    GDConsts.effectCreature := nil;
    if (Types.PCharacter(cr)^.inPlay = 0) and (Types.PCharacter(cr)^.status <> 10) then
      CbtMap.CreatureDowned(cr);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    if GDVars.locState.current <> C_Ifc.IN_COMBAT then CharHlp.DisplayParty(GDVars.curChar)
  end end
end;

procedure CallEffectHandler(effectId: Byte; var cr; p: Pointer; removed: Boolean);
begin
  if GDVars.overrideFlag <> 0 then GDVars.effectHandlers[127](Pointer(cr), p, removed)
  else GDVars.effectHandlers[effectId](Pointer(cr), p, removed)
end;

procedure RemoveEffect(cr: Pointer; effectId: Byte; node: Pointer);
var
  prev: Types.PEffect;
  p: Types.PEffect;
begin
  p := node;
  if p = nil then begin
    p := Types.PCharacter(cr)^.effects;
    while (p <> nil) and (p^.id <> effectId) do p := p^.next
  end;
  if p = nil then Exit;
  if p^.onRemove <> 0 then FxEngine.CallEffectHandler(effectId, cr, p, True);
  if Types.PCharacter(cr)^.effects = p then Types.PCharacter(cr)^.effects := p^.next
  else begin
    prev := Types.PCharacter(cr)^.effects;
    while (prev <> nil) and (prev^.next <> p) do prev := prev^.next;
    prev^.next := p^.next
  end;
  FreeMem(p, SizeOf(Types.TEffect));
  if effectId = FxEngine.EFF_FRIENDS then FxEngine.RecalcAbility(cr, C_Stat.CHARISMA);
  if (effectId = C_Effect.ENLARGE) or (effectId = C_Effect.STRENGTH) or
      (effectId = C_Effect.GIANT_STRENGTH) then FxEngine.RecalcAbility(cr, C_Stat.STRENGTH)
end;

{ Fires effect effectId on cr, once for each record of it cr carries. The aura effects (silence, the two 10-foot
  protections and prayer) also fire when another creature carries them and cr is within reach of it: 6 squares for
  prayer, otherwise 1. Outside combat any carrier in the roster will do. BuildTargetList overwrites
  GDVars.rankedTargets, so it is saved and restored around the search.
  @param(cr The creature.)
  @param(effectId The effect.) }
procedure TriggerEffect(var cr; effectId: Byte);
var
  savedList: array[1..72] of record entity: Byte; x: Byte; y: Byte end;
  roster: Types.PCharacter;
  effect: Pointer;
  nextEffect: Pointer;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  roster := GDVars.partyHead;
  if CharHlp.HasEffect(Types.PCharacter(cr), effectId, effect) then found := True
  else if effectId in
    [C_Effect.SILENCE, FxEngine.EFF_PROT_EVIL_10, FxEngine.EFF_PROT_GOOD_10, C_Effect.PRAYER] then begin
    Move(GDVars.rankedTargets, savedList, SizeOf(savedList));
    while (roster <> nil) and (not found) do begin
      if CharHlp.HasEffect(roster, effectId, effect) then begin
        if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
          if effectId = C_Effect.PRAYER then range := 6 else range := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(roster), CbtMap.CombatCellY(roster), range, $FF,
                                  CbtMap.GetIconSize(roster));
          for i := 1 to GDVars.targetCount do
            if GDVars.rankedTargets[i].entity = CbtMap.CombatSlot(Types.PCharacter(cr)) then
              found := True
        end else found := True
      end;
      roster := roster^.next
    end;
    Move(savedList, GDVars.rankedTargets, SizeOf(savedList))
  end;
  if found then while effect <> nil do begin
    nextEffect := Types.PEffect(effect)^.next;
    if Types.PEffect(effect)^.id = effectId then FxEngine.CallEffectHandler(effectId, cr, effect, False);
    effect := nextEffect
  end
end;

{ Magic resistance against someone else's spell or magical attack. When an effect is pending or the attack is magical,
  rolls d100 against cr's resistance, raised 5 points for each caster level below 11 and lowered 5 for each level above.
  A resisted spell deals no damage and its effect is cancelled, except for effects 91 and 82.
  @param(cr The creature.) }
procedure CheckSpellResistance(cr: Types.PCharacter);
var level: Byte; resistance: Integer; chance: Integer;
begin
  resistance := cr^.spellResistance;
  if resistance <> 0 then
    if (GDVars.curChar <> cr) and ((GDVars.pendingEffectId <> 0) or ((GDVars.effectMask and 8) <> 0)) then begin
      level := CharHlp.GetCasterLevel(GDVars.opMode, False);
      chance := resistance + (11 - level) * 5;
      if FxEngine.RollDice(1, 100) <= chance then begin
        GDVars.pendingDamage := 0;
        if (GDVars.pendingEffectId <> C_Effect.BLUE_DRAGON_BREATH) and
            (GDVars.pendingEffectId <> FxEngine.EFF_BLESSED_BOLT_KILLS) then
          GDVars.pendingEffectId := 0
      end
    end
end;

{ Cancels the pending damage and effect when cr is immune to the element in flight: element bit $80 against immunity bit
  $10, and $40 against $08.
  @param(cr The creature.) }
procedure CancelIfImmune(cr: Types.PCharacter);
var immune: Boolean;
begin
  immune := False;
  if ((GDVars.effectMask and $80) <> 0) and ((cr^.immunities and $10) <> 0) then
    immune := True;
  if ((GDVars.effectMask and $40) <> 0) and ((cr^.immunities and 8) <> 0) then
    immune := True;
  if immune then begin GDVars.pendingDamage := 0; GDVars.pendingEffectId := 0 end
end;

procedure TriggerEffectsWithCondition(condition: Byte; var cr);
var
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
  savedCondition: Byte;
begin
  if Types.PCharacter(cr) = nil then Exit;
  savedCondition := GDConsts.currentCondition;
  GDConsts.currentCondition := condition;
  case condition of
    C_Cond.ATTACKER_VETO: ;
    C_Cond.TARGET_VETO: begin FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_INVIS_TO_ANIMALS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BLINK) end;
    2: begin FxEngine.TriggerEffect(cr, FxEngine.EFF_DEADLY_POISON_M2);
      FxEngine.TriggerEffect(cr, C_Effect.DRAIN_ONE_LEVEL);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_DRAIN_2_LEVELS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FIRE_TOUCH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PETRIFY_TOUCH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_VORPAL);
      FxEngine.TriggerEffect(cr, C_Effect.DISPEL_EVIL_TOUCH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PARALYZING_POISON);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_HARPY_TOUCH);
      FxEngine.TriggerEffect(cr, C_Effect.KAMPFULT_TENTACLES);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RAT_DISEASE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_1);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_2);
      FxEngine.TriggerEffect(cr, C_Effect.YETI_SQUEEZE_3);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_SWALLOW_WHOLE) end;
    3: begin FxEngine.TriggerEffect(cr, C_Effect.DEADLY_POISON_ATTACK);
      FxEngine.TriggerEffect(cr, C_Effect.DRAIN_ONE_LEVEL);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_DRAIN_2_LEVELS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FIRE_TOUCH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PETRIFY_TOUCH);
      FxEngine.TriggerEffect(cr, C_Effect.DISPEL_EVIL_TOUCH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FIRE_DMG_4D6);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FIRE_DMG_2D6);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_1);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_2);
      FxEngine.TriggerEffect(cr, C_Effect.YETI_SQUEEZE_3);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_SWALLOW_WHOLE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PARALYZING_POISON) end;
    C_Cond.ATTACKER_WEAPON_DAMAGE: begin FxEngine.TriggerEffect(cr, FxEngine.EFF_ENFEEBLE);
      FxEngine.TriggerEffect(cr, C_Effect.RANGER_BONUS_DAMAGE);
      FxEngine.TriggerEffect(cr, C_Effect.DRAGON_FEARED);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_GIANT_SLAYING_SWORD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_MULTI_ATTACK_NEW_WEAPONS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_GLACIER_ARMOR) end;
    C_Cond.DEFENDER_WEAPON_DAMAGE: begin FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
      FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_MISSILES);
      FxEngine.TriggerEffect(cr, C_Effect.HIT_BY_PLUS_3_ONLY);
      FxEngine.TriggerEffect(cr, C_Effect.HALF_DAMAGE_PIERCE_CUT);
      FxEngine.TriggerEffect(cr, C_Effect.HALF_DAMAGE_CRUSH);
      FxEngine.TriggerEffect(cr, C_Effect.LUCK_STONE);
      FxEngine.TriggerEffect(cr, C_Effect.HALF_DAMAGE_WEAPONS_UNDER_PLUS_3);
      FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BLESSED_BOLT_KILLS);
      FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_NONMAGIC);
      FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_WEAPONS_UNDER_PLUS_2);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_ICEWIND_SWORD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_STONE_SWORD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_QUARTER_DMG_EDGED);
      FxEngine.TriggerEffect(cr, C_Effect.STONE_CREATURE) end;
    FxEngine.COND_DAMAGE_TAKEN: begin FxEngine.CheckSpellResistance(Types.PCharacter(cr));
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RESIST_COLD);
      FxEngine.TriggerEffect(cr, C_Effect.SHIELD);
      FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE);
      FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
      FxEngine.TriggerEffect(cr, C_Effect.MINOR_GLOBE);
      FxEngine.TriggerEffect(cr, C_Effect.GLOBE_OF_INVULNERABILITY);
      FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_ELECTRICITY);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RAKSHASA_PROT);
      FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_HOT);
      FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_COLD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RESIST_FIRE_RING);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_IMMUNE_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_IRON_GOLEM_IMMUNITY);
      FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_FIRE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_IMMUNE_COLD);
      FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE_DRUID);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_HALF_DMG_COLD_FIRE_ELEC);
      FxEngine.TriggerEffect(cr, C_Effect.STONE_CREATURE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FIRE_VULNERABLE);
      FxEngine.CancelIfImmune(Types.PCharacter(cr)) end;
    C_Cond.TURN_START: begin FxEngine.TriggerEffect(cr, C_Effect.SNAKE_HARASS);
      FxEngine.TriggerEffect(cr, C_Effect.CONFUSED_LOSE_TURN);
      FxEngine.TriggerEffect(cr, C_Effect.HELPLESS);
      FxEngine.TriggerEffect(cr, C_Effect.HELD);
      FxEngine.TriggerEffect(cr, C_Effect.ASLEEP);
      FxEngine.TriggerEffect(cr, C_Effect.STUNNED);
      FxEngine.TriggerEffect(cr, C_Effect.HELPLESS_51) end;
    C_Cond.COMBAT_START: begin FxEngine.TriggerEffect(cr, FxEngine.EFF_INVISIBLE_RING);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_MAGIC_CLOAK);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_DRAGON_FEAR_ATTACK);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_SHAPE_CHANGING);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FEAR_ON_SURPRISE) end;
    C_Cond.EFFECT_ADDED: begin FxEngine.CheckSpellResistance(Types.PCharacter(cr));
      FxEngine.TriggerEffect(cr, C_Effect.RESIST_CHARM_30);
      FxEngine.TriggerEffect(cr, C_Effect.MIRROR_IMAGE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RAKSHASA_PROT);
      FxEngine.TriggerEffect(cr, C_Effect.GLOBE_OF_INVULNERABILITY);
      FxEngine.TriggerEffect(cr, C_Effect.MINOR_GLOBE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_IMMUNE_DISEASE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_IRON_GOLEM_IMMUNITY);
      FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_FEAR);
      FxEngine.TriggerEffect(cr, C_Effect.RESIST_SLEEP_CHARM_90);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_MIND_BLANK);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_MULTI_IMMUNITY);
      FxEngine.TriggerEffect(cr, C_Effect.STONE_CREATURE) end;
    C_Cond.ATTACKER_ATTACK_ROLL: begin FxEngine.TriggerEffect(cr, C_Effect.BLESS);
      FxEngine.TriggerEffect(cr, C_Effect.CURSE);
      FxEngine.TriggerEffect(cr, C_Effect.DWARF_THAC0_BONUS);
      FxEngine.TriggerEffect(cr, C_Effect.BLIND);
      FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
      FxEngine.TriggerEffect(cr, C_Effect.PRAYER);
      FxEngine.TriggerEffect(cr, C_Effect.DRAGON_FEARED);
      FxEngine.TriggerEffect(cr, C_Effect.IN_LOVE) end;
    C_Cond.DEFENDER_ARMOR_CLASS: begin FxEngine.TriggerEffect(cr, C_Effect.DISPEL_EVIL);
      FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PROT_GOOD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BARKSKIN);
      FxEngine.TriggerEffect(cr, C_Effect.SHIELD);
      FxEngine.TriggerEffect(cr, C_Effect.STINKING_CLOUD_COUGH);
      FxEngine.TriggerEffect(cr, C_Effect.BLIND);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PROT_EVIL_10);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PROT_GOOD_10);
      FxEngine.TriggerEffect(cr, C_Effect.DANCING);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_HIGHLIGHTED);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_IRON_SKIN) end;
    FxEngine.COND_SAVING_THROW: begin FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PROT_GOOD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RESIST_COLD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BARKSKIN);
      FxEngine.TriggerEffect(cr, C_Effect.SHIELD);
      FxEngine.TriggerEffect(cr, C_Effect.RESIST_FIRE);
      FxEngine.TriggerEffect(cr, C_Effect.BLIND);
      FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PROT_EVIL_10);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_PROT_GOOD_10);
      FxEngine.TriggerEffect(cr, C_Effect.PRAYER);
      FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_HOT);
      FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_COLD);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_RESIST_FIRE_RING);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_DWARF_SAVE_94);
      FxEngine.TriggerEffect(cr, C_Effect.CON_SPELL_SAVE_BONUS);
      FxEngine.TriggerEffect(cr, C_Effect.IMMUNE_GAZE) end;
    C_Cond.ZERO_HIT_POINTS: begin FxEngine.TriggerEffect(cr, C_Effect.RED_CRYSTAL);
      FxEngine.TriggerEffect(cr, C_Effect.GREEN_CRYSTAL);
      FxEngine.TriggerEffect(cr, C_Effect.BLUE_CRYSTAL);
      FxEngine.TriggerEffect(cr, C_Effect.IN_LOVE);
      FxEngine.TriggerEffect(cr, C_Effect.KAMPFULT_TENTACLES);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_1);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_2);
      FxEngine.TriggerEffect(cr, C_Effect.YETI_SQUEEZE_3) end;
    C_Cond.MONSTER_SPECIAL: begin FxEngine.TriggerEffect(cr, FxEngine.EFF_CONFUSION_GAZE);
      FxEngine.TriggerEffect(cr, C_Effect.BIG_RED_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, C_Effect.RED_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, C_Effect.WHITE_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, C_Effect.GREEN_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, C_Effect.BLUE_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, C_Effect.BLACK_DRAGON_BREATH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_STONE_GAZE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BEHOLDER_EYE_RAYS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_HELLHOUND_BREATH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_SPIT_ACID);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_MANTICORE_SPINE);
      FxEngine.TriggerEffect(cr, C_Effect.KAMPFULT_TENTACLES);
      FxEngine.TriggerEffect(cr, C_Effect.STONE_CREATURE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_ICEHOUND_BREATH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_STONE_BREATH);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_1);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_2);
      FxEngine.TriggerEffect(cr, C_Effect.YETI_SQUEEZE_3) end;
    C_Cond.ACTION_START: begin FxEngine.TriggerEffect(cr, C_Effect.CHARM);
      FxEngine.TriggerEffect(cr, C_Effect.SILENCE);
      FxEngine.TriggerEffect(cr, C_Effect.STINKING_CLOUD_COUGH);
      FxEngine.TriggerEffect(cr, C_Effect.FEEBLEMIND);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BLESSED_BOLT_KILLS);
      FxEngine.TriggerEffect(cr, C_Effect.CANNOT_MOVE) end;
    FxEngine.COND_ATTACK_ROLL_DEF: begin FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_INVIS_TO_ANIMALS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BLINK);
      FxEngine.TriggerEffect(cr, C_Effect.DWARF_GIANT_BONUS);
      FxEngine.TriggerEffect(cr, C_Effect.GNOME_LARGE_MONSTER_BONUS);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_MAGIC_CLOAK);
      FxEngine.TriggerEffect(cr, C_Effect.IN_LOVE) end;
    C_Cond.MORALE_CHECK: begin FxEngine.TriggerEffect(cr, C_Effect.BLESS);
      FxEngine.TriggerEffect(cr, C_Effect.CHARM) end;
    C_Cond.MOVE_ATTACK_RATE: begin FxEngine.TriggerEffect(cr, C_Effect.MAGIC_BOOTS);
      FxEngine.TriggerEffect(cr, C_Effect.HASTED);
      FxEngine.TriggerEffect(cr, C_Effect.SLOWED);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_BULLET_RAKE);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_FIRST_TURN_DOUBLE_MOVE) end;
    C_Cond.ROUND_END: begin FxEngine.TriggerEffect(cr, C_Effect.CHARM);
      FxEngine.TriggerEffect(cr, C_Effect.SPIRITUAL_HAMMER);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_SHAPE_CHANGING) end;
    FxEngine.COND_DAMAGE_NOT_SAVED: begin FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_HOT);
      FxEngine.TriggerEffect(cr, C_Effect.FIRE_SHIELD_COLD) end;
    21: FxEngine.TriggerEffect(cr, C_Effect.CONFUSED);
    22: ;
    23: ;
    24: FxEngine.TriggerEffect(cr, FxEngine.EFF_DRAGON_FEAR_ATTACK);
    25: FxEngine.TriggerEffect(cr, C_Effect.IN_LOVE);
    26: FxEngine.TriggerEffect(cr, FxEngine.EFF_SHAPE_CHANGING);
    27: begin FxEngine.TriggerEffect(cr, C_Effect.KAMPFULT_TENTACLES);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_1);
      FxEngine.TriggerEffect(cr, FxEngine.EFF_YETI_SQUEEZE_2);
      FxEngine.TriggerEffect(cr, C_Effect.YETI_SQUEEZE_3) end;
    28: ;
  end;
  GDConsts.currentCondition := savedCondition
end;

procedure ConsiderTerrainEffects(cr: Pointer; allowSave, skipCloud: Boolean);
var
  terrainIndex: Byte;
  characterIndex: Byte;
  effect: Pointer;
  effect2: Pointer;
  saved: Boolean;
  savedCharacter: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  discarded: Boolean;
  special: Byte;
begin
  if Types.PCharacter(cr)^.inPlay <> 0 then begin
    GDVars.effectInProgress := 1;
    CbtMap.ProbeDirection(cr, C_Dir.CENTER, characterIndex, terrainIndex, special);
    if (special <> 0) and ((special <> C_Terr.TERRAIN_STINK_CLOUD) or (not skipCloud)) then begin
      if (not CbtMap.CombatIconVisible(cr, 1)) or (GDVars.combatGfxOn = 0) then
        CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), $FF, C_Dir.CENTER);
      case special of
        C_Terr.TERRAIN_STINK_CLOUD: begin
          GDVars.opMode := 34;
          if (Types.PCharacter(cr)^.levelUndead = 0) and (not CharHlp.HasEffect(cr, C_Effect.HELPLESS, effect)) and
              ((Types.PCharacter(cr)^.immunities and $18) = 0) then begin
            saved := Boolean(FxEngine.RollSavingThrow(cr, 0, 0));
            if saved then begin
              savedCharacter := GDVars.curChar;
              FxEngine.AddEffectWithMessage(cr, C_Effect.STINKING_CLOUD_COUGH, FxEngine.RollDice(1, 4) + 1, -1, 0, 0,
                                            Ord(saved), 'starts to cough');
              effect2 := nil;
              if CharHlp.HasEffect(cr, C_Effect.STINKING_CLOUD_COUGH, effect2) then begin
                FxEngine.CallEffectHandler(C_Effect.STINKING_CLOUD_COUGH, cr, effect, False);
                if Types.PCharacter(cr)^.combatAddr^.spellCast > 0 then begin
                  CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, 1);
                  CharHlp.RemoveSpell(cr, Types.PCharacter(cr)^.combatAddr^.spellCast);
                  discarded := CharHlp.EndActions(cr)
                end
              end;
              GDVars.curChar := savedCharacter
            end else begin
              savedCharacter := GDVars.curChar;
              FxEngine.AddEffectWithMessage(cr, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, -1, 0, 0,
                                            Ord(saved), 'chokes and gags from nausea');
              if CharHlp.HasEffect(cr, C_Effect.HELPLESS, effect) then
                FxEngine.CallEffectHandler(C_Effect.HELPLESS, cr, effect, False);
              GDVars.curChar := savedCharacter
            end
          end
        end;
        C_Terr.TERRAIN_CLOUDKILL: begin
          GDVars.opMode := 91;
          if (Types.PCharacter(cr)^.inPlay <> 0) and ((Types.PCharacter(cr)^.immunities and $10) = 0) then
            case Types.PCharacter(cr)^.hitDice of
              0..4: begin
                CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, 0);
                TextRend.PauseOnly;
                FxEngine.AddEffect(cr, C_Effect.POISONED, 0, $FF, False);
                FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed')
              end;
              5: if not Boolean(FxEngine.RollSavingThrow(cr, 0, -4)) then begin
                CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, 0);
                TextRend.PauseOnly;
                FxEngine.AddEffect(cr, C_Effect.POISONED, 0, $FF, False);
                FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed')
              end;
              6: if not Boolean(FxEngine.RollSavingThrow(cr, 0, 0)) then begin
                CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, 0);
                TextRend.PauseOnly;
                FxEngine.AddEffect(cr, C_Effect.POISONED, 0, $FF, False);
                FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed')
              end;
            else begin
              GDVars.effectMask := $88;
              FxEngine.InflictNonWeaponDamage(cr, FxEngine.RollDamageDice(1, 10), 0, 0)
            end
          end
        end;
        C_Terr.TERRAIN_BLADE_BARRIER: begin
          GDVars.opMode := 101; GDVars.effectMask := 8; GDVars.pendingDamage := $FF;
          FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, cr);
          if (Types.PCharacter(cr)^.inPlay <> 0) and (GDVars.pendingDamage <> 0) then
            if (not allowSave) or (not Boolean(FxEngine.RollSavingThrow(cr, 4, 0))) then begin
              CharHlp.PrintCreatureMessage(cr, 'is cut by knives', 10, 0);
              TextRend.PauseOnly;
              FxEngine.InflictNonWeaponDamage(cr, FxEngine.RollDamageDice(8, 8), 0, 0)
            end
        end
      end
    end;
    GDVars.effectInProgress := 0
  end
end;

function AttackRollNoAttacker(defender: Pointer; sixtyMinusThac0: Byte): Boolean;
var hit: Boolean;
begin
  hit := False;
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll > 16 then GDVars.beheadOk := True
    else GDVars.beheadOk := False;
    if GDVars.attackRoll = 20 then GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, defender);
    if GDVars.attackRoll >= 0 then
      if GDVars.attackRoll + sixtyMinusThac0 > Types.PCharacter(defender)^.acCur[0] then
        hit := True;
    GDVars.beheadOk := GDVars.beheadOk and hit
  end;
  AttackRollNoAttacker := hit
end;

function AttackRoll(attacker, target: Pointer; amount: Byte): Boolean;
var toHitAdj: ShortInt; hit: Boolean;
begin
  hit := False;
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll > 16 then GDVars.beheadOk := True
    else GDVars.beheadOk := False;
    if GDVars.attackRoll = 20 then GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACKER_ATTACK_ROLL, attacker);
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_ATTACK_ROLL_DEF, target);
    if Types.PCharacter(attacker)^.side = 0 then begin
      toHitAdj := GDVars.gameState^.partyToHitAdj;
      case GDVars.gameState^.gameLevel of
        1: Inc(toHitAdj, 2);
        2: Inc(toHitAdj);
        4: Dec(toHitAdj);
        5: Dec(toHitAdj, 2)
      end
    end else toHitAdj := GDVars.gameState^.enemyToHitAdj;
    if GDVars.attackRoll >= 0 then
      if GDVars.attackRoll + Types.PCharacter(attacker)^.thac0Cur + toHitAdj >= amount then begin
        hit := True;
        AttackRoll := True
      end;
    GDVars.beheadOk := GDVars.beheadOk and hit
  end
end;

function RollSavingThrow(cr: Pointer; kind, damage: ShortInt): Byte;
var
  { Unused in this version; see the other implementations of this routine. }
  tableIndex: Word;
  effect: Pointer;
begin
  GDVars.saveResult := 1;
  GDVars.saveRoll := FxEngine.RollDice(1, 20);
  if CharHlp.HasEffect(cr, C_Effect.DANCING, effect) then GDVars.saveRoll := 1;
  case GDVars.saveRoll of
    1: GDVars.saveResult := 0;
    20: GDVars.saveResult := 1;
  else begin
    GDVars.saveRoll := GDVars.saveRoll + Types.PCharacter(cr)^.saveBonus + damage;
    GDVars.saveType := kind;
    FxEngine.TriggerEffectsWithCondition(FxEngine.COND_SAVING_THROW, cr);
    if Types.PCharacter(cr)^.saves[kind] <= GDVars.saveRoll then
      GDVars.saveResult := 1
    else GDVars.saveResult := 0
  end end;
  RollSavingThrow := GDVars.saveResult
end;

function RollDice(n, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do Inc(total, Random(sides) + 1);
  RollDice := total
end;

function RollDamageDice(n, sides: Byte): Word;
begin
  GDVars.diceCount := n;
  RollDamageDice := FxEngine.RollDice(n, sides)
end;

procedure AddEffect(cr: Pointer; effectId: Byte; minutes: Word; strength: Byte; permanent: Boolean);
var
  node: Types.PEffect;
  p: Types.PEffect;
begin
  GetMem(node, SizeOf(Types.TEffect));
  if Types.PCharacter(cr)^.effects = nil then Types.PCharacter(cr)^.effects := node
  else begin
    p := Types.PCharacter(cr)^.effects;
    while p^.next <> nil do p := p^.next;
    p^.next := node
  end;
  node^.next := nil;
  node^.id := effectId;
  node^.duration := minutes;
  node^.onRemove := Ord(permanent);
  node^.strength := strength
end;

procedure PutOutOfPlayWithStatus(cr: Pointer; status: Byte; message: Types.TStr40);
var slot: Byte;
begin
  if Types.PCharacter(cr)^.inPlay <> 0 then begin
    slot := CbtMap.CombatSlot(cr);
    CbtMap.DisplayMapViewCentered(cr, 3, Byte(False));
    CharHlp.PrintCreatureMessage(cr, message, 10, 1);
    Types.PCharacter(cr)^.inPlay := 0;
    Types.PCharacter(cr)^.status := status;
    if Types.PCharacter(cr)^.status <> C_Status.RUNNING then Types.PCharacter(cr)^.hpCur := 0;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Blit.FlushView;
    GDVars.actor[slot].size := 0;
    CbtMap.BuildArenaArrays;
    if CharHlp.EndActions(cr) then FxEngine.RemoveEffectsHp0(cr)
  end
end;

procedure RemoveInvisibility(cr: Pointer);
var effect: Pointer;
begin
  while CharHlp.HasEffect(cr, C_Effect.INVISIBLE, effect) do
    FxEngine.RemoveEffect(cr, C_Effect.INVISIBLE, effect)
end;

procedure RemoveEffectsHp0(cr: Pointer);
var i: Byte; effect: Pointer; savedCondition: Byte;
begin
  savedCondition := GDConsts.currentCondition;
  GDConsts.currentCondition := 28;
  for i := 1 to 16 do FxEngine.RemoveEffect(cr, GDConsts.hpZeroBlock[i], nil);
  if CharHlp.HasEffect(cr, C_Effect.CONFUSED_BERSERK, effect) and
      (Types.PCharacter(cr)^.npc = C_Npc.ANIMATED_PLAYER) then Types.PCharacter(cr)^.side := 0;
  GDConsts.currentCondition := savedCondition
end;

function RemoveEffectWithMessage(cr: Pointer; effectId: Byte): Boolean;
var effect: Pointer;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(cr, effectId, effect) then begin
    CharHlp.PrintCreatureMessage(cr, 'is Cured', 10, 1);
    FxEngine.RemoveEffect(cr, effectId, effect);
    RemoveEffectWithMessage := True
  end
end;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength becomes the exceptional value + 1 (1..101), any
  other base Strength becomes the base + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when the base Strength is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then StrengthModifier := excStr + 1
end;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(effect The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(effect: Pointer; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := Types.PEffect(effect)^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18
  end else baseStr := baseStr - 100
end;

function AdjustForNewStrength(cr: Pointer; baseStr, excStr: Byte; var effectStrength: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  found: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  oldBase: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldExc: Byte;
  { Unused in this version; see the other implementations of this routine. }
  encoded: Byte;
begin
  if (baseStr > Types.PCharacter(cr)^.stats[C_Stat.STRENGTH].base) or
      ((baseStr = 18) and (excStr > Types.PCharacter(cr)^.strExcBase)) then begin
    AdjustForNewStrength := True;
    effectStrength := FxEngine.StrengthModifier(baseStr, excStr)
  end else AdjustForNewStrength := False
end;

procedure RecalcAbility(cr: Pointer; stat: ShortInt);
var
  statOverride: Byte;
  statVal: Byte;
  baseStr: Byte;
  strExc: Byte;
  excStr: Byte;
  effect: Pointer;
  hpSave: Byte;
  accum: Byte;
  tmp: Byte;
  i: ShortInt;
  item: Types.PItem;
  encoded: Byte;
  count: Byte;

  { Raises the strength being built to the candidate when higher, comparing exceptional strength only at 18. }
  procedure StrClamp;
  begin
    if (baseStr > statVal) or ((baseStr = 18) and (excStr > strExc)) then begin
      statVal := baseStr;
      strExc := excStr
    end
  end;

  { Adds the constitution hit-point bonus for some levels of one class to accum. }
  procedure StatBonus(classId: ShortInt; levels: Byte);
  begin
    if GDConsts.hitDiceLevelCap[classId] <= levels then
      levels := GDConsts.hitDiceLevelCap[classId] - 1;
    if classId = C_Class.RANGER then Inc(levels);
    if (classId = C_Class.FIGHTER) or (classId = C_Class.RANGER) or (classId = C_Class.PALADIN) then
      case statVal of
        15..19: Inc(accum, (statVal - 14) * levels);
        20: Inc(accum, levels * 5);
        21..23: Inc(accum, levels * 6);
        24..25: Inc(accum, levels * 7)
      end else if statVal > 15 then Inc(accum, levels * 2)
    else if statVal = 15 then Inc(accum, levels)
  end;
begin
  statOverride := $FF;
  accum := 0;
  baseStr := 0;
  excStr := 0;
  item := Types.PItem(Types.PCharacter(cr)^.items);
  statVal := Types.PCharacter(cr)^.stats[stat].base;
  strExc := Types.PCharacter(cr)^.strExcBase;
  while item <> nil do begin
    if (not FxEngine.IsSpecialItem(Types.PItem(item))) and (item^.special > C_Item.SPECIAL_POWER_BASE) and
        (item^.equipped <> 0) then begin
      encoded := item^.special and C_Item.SPECIAL_POWER_MASK;
      case stat of
        C_Stat.STRENGTH: begin
            case encoded of
              3: begin baseStr := 18; excStr := 100 end;
              5: begin
                  baseStr := item^.effect + 18;
                  if baseStr = 18 then excStr := 100
                end
            end;
            StrClamp
          end;
        C_Stat.DEXTERITY: case encoded of
            2: case Types.PCharacter(cr)^.stats[C_Stat.DEXTERITY].base of
                0..6: Inc(statVal, 4);
                7..13: Inc(statVal, 2)
              else Inc(statVal)
              end;
            8: if (Types.PCharacter(cr)^.stats[C_Stat.DEXTERITY].base < 18) and (item^.effect = 3) then Inc(statVal);
            10: Dec(statVal, 2)
          end
      end
    end;
    item := item^.next
  end;
  case stat of
    C_Stat.STRENGTH: begin
        if CharHlp.HasEffect(cr, C_Effect.STRENGTH, effect) then begin
          FxEngine.StrengthEffectToStrength(effect, baseStr, excStr);
          if (statVal <= 18) and (strExc < 100) then begin
            baseStr := statVal + baseStr;
            if baseStr > 18 then
              if (Types.PCharacter(cr)^.classLevels[C_Class.FIGHTER] > 0) or
                  (Types.PCharacter(cr)^.classLevels[C_Class.PALADIN] > 0) or
                  (Types.PCharacter(cr)^.classLevels[C_Class.RANGER] > 0) then begin
                excStr := Types.PCharacter(cr)^.strExc + (baseStr - 18) * 10;
                if excStr > 100 then excStr := 100;
                baseStr := 18
              end else baseStr := 18
          end;
          StrClamp
        end;
        if CharHlp.HasEffect(cr, C_Effect.GIANT_STRENGTH, effect) then begin
          FxEngine.StrengthEffectToStrength(effect, baseStr, excStr);
          StrClamp
        end;
        if CharHlp.HasEffect(cr, C_Effect.ENLARGE, effect) then begin
          FxEngine.StrengthEffectToStrength(effect, baseStr, excStr);
          StrClamp
        end;
        Types.PCharacter(cr)^.stats[C_Stat.STRENGTH].current := statVal;
        Types.PCharacter(cr)^.strExc := strExc
      end;
    C_Stat.CONSTITUTION: begin
        count := 0;
        hpSave := Types.PCharacter(cr)^.hpMax;
        Types.PCharacter(cr)^.hpMax := Types.PCharacter(cr)^.hpRolled;
        for i := C_Class.CLERIC to C_Class.THIEF do begin
          tmp := Types.PCharacter(cr)^.oldLevels[i];
          if tmp > 0 then StatBonus(i, tmp);
          tmp := Types.PCharacter(cr)^.classLevels[i];
          if tmp > 0 then Inc(count);
            if GDConsts.hitDiceLevelCap[i] < tmp then tmp := GDConsts.hitDiceLevelCap[i];
          if tmp > Types.PCharacter(cr)^.dualLevel then begin
            Dec(tmp, Types.PCharacter(cr)^.dualLevel);
            StatBonus(i, tmp)
          end
        end;
        accum := accum div count;
        Inc(Types.PCharacter(cr)^.hpMax, accum);
        if Types.PCharacter(cr)^.hpMax > hpSave then
          Inc(Types.PCharacter(cr)^.hpCur, Types.PCharacter(cr)^.hpMax - hpSave);
        if Types.PCharacter(cr)^.hpMax < hpSave then
          if Types.PCharacter(cr)^.hpCur > hpSave - Types.PCharacter(cr)^.hpMax then
            Dec(Types.PCharacter(cr)^.hpCur, hpSave - Types.PCharacter(cr)^.hpMax)
          else Types.PCharacter(cr)^.hpCur := 0;
        Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current := statVal;
        if Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current >= 20 then
          FxEngine.AddEffect(cr, FxEngine.EFF_REGENERATION, 60, $FF, True)
        else FxEngine.RemoveEffect(cr, FxEngine.EFF_REGENERATION, nil)
      end;
    C_Stat.DEXTERITY: if statOverride <> $FF then
        Types.PCharacter(cr)^.stats[C_Stat.DEXTERITY].current := statOverride
      else Types.PCharacter(cr)^.stats[C_Stat.DEXTERITY].current := statVal;
    C_Stat.CHARISMA: begin
        if CharHlp.HasEffect(cr, FxEngine.EFF_FRIENDS, effect) then
          Inc(statVal, Types.PEffect(effect)^.strength);
        Types.PCharacter(cr)^.stats[C_Stat.CHARISMA].current := statVal
      end;
    C_Stat.INTELLIGENCE, C_Stat.WISDOM: begin
        if CharHlp.HasEffect(cr, C_Effect.FEEBLEMIND, effect) then statVal := 3;
        Types.PCharacter(cr)^.stats[stat].current := statVal
      end
  end
end;

procedure InflictNonWeaponDamage(cr: Pointer; damage: Integer; kind, flag: Byte);
var
  message: String[80];
  { Unused in this version; see the other implementations of this routine. }
  discarded: Boolean;
begin
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(FxEngine.COND_DAMAGE_TAKEN, cr);
  if flag <> 0 then
    case kind of
      1: GDVars.pendingDamage := 0;
      2: GDVars.pendingDamage := GDVars.pendingDamage div 2
    end else FxEngine.TriggerEffectsWithCondition(FxEngine.COND_DAMAGE_NOT_SAVED, cr);
  if GDVars.pendingDamage > 0 then
    if Types.PCharacter(cr)^.inPlay <> 0 then begin
      if GDVars.pendingDamage <> 1 then
        message := 'takes ' + TextRend.ByteToString(GDVars.pendingDamage) + ' points of damage '
      else message := 'takes 1 point of damage ';
      if (GDVars.effectMask and 1) <> 0 then message := message + 'from Fire'
      else if (GDVars.effectMask and 2) <> 0 then message := message + 'from Cold'
      else if (GDVars.effectMask and 4) <> 0 then message := message + 'from Electricity'
      else if (GDVars.effectMask and 8) <> 0 then message := message + 'from Magic';
      GDVars.combatPanelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(cr);
      CharHlp.PrintNameStringAnim(cr, False, message);
      CharHlp.InflictDamage(cr, GDVars.pendingDamage);
      if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
        Types.PCharacter(cr)^.combatAddr^.castAllowed := 0;
        if Types.PCharacter(cr)^.combatAddr^.spellCast > 0 then begin
          CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, 1);
          CharHlp.RemoveSpell(cr, Types.PCharacter(cr)^.combatAddr^.spellCast);
          discarded := CharHlp.EndActions(cr)
        end
      end;
      if Types.PCharacter(cr)^.inPlay = 0 then begin
        message := 'Goes Down';
        if (Types.PCharacter(cr)^.immunities and 8) = 0 then begin
          if Types.PCharacter(cr)^.status = C_Status.DYING then
            message := message + ', and is Dying';
          if Types.PCharacter(cr)^.status in
              [C_Status.DEAD_STATUS, C_Status.PETRIFIED, C_Status.GONE] then message := 'is killed'
        end;
        CharHlp.PrintCreatureMessage(cr, message, GDVars.curRow + 1, 0);
        if GDVars.locState.current <> C_Ifc.IN_COMBAT then TextRend.PauseOnly
        else begin
          FxEngine.RemoveEffectsHp0(cr);
          FxEngine.TriggerEffectsWithCondition(C_Cond.ZERO_HIT_POINTS, cr);
          GDConsts.effectCreature := cr;
          if Types.PCharacter(cr)^.inPlay = 0 then FxEngine.TriggerEffectsWithCondition(25, GDVars.curChar);
          GDConsts.effectCreature := nil;
          if (Types.PCharacter(cr)^.inPlay = 0) and (Types.PCharacter(cr)^.status <> 10) then
            CbtMap.CreatureDowned(cr)
          else TextRend.PauseOnly
        end
      end;
      CharHlp.ClearMessageWindow
    end
end;

procedure AddEffectWithMessage(cr: Pointer; effectId: Byte; minutes: Word; effectStrength: ShortInt; onRemove,
                               saveNegates, outcome: Byte; message: Types.TStr40);
var
  effect: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  oldEffect: Byte;
begin
  GDVars.pendingEffectId := effectId;
  FxEngine.TriggerEffectsWithCondition(C_Cond.EFFECT_ADDED, cr);
  if (GDVars.pendingEffectId = 0) or ((outcome <> 0) and (saveNegates = 1)) then
    CharHlp.PrintCreatureMessage(cr, 'is Unaffected', 10, 1)
  else begin
    if CharHlp.HasEffect(cr, effectId, effect) then
      if Types.PEffect(effect)^.duration > 0 then
        FxEngine.RemoveEffect(cr, effectId, effect);
    FxEngine.AddEffect(cr, effectId, minutes, Byte(effectStrength), Boolean(onRemove));
    if Length(message) <> 0 then begin
      CharHlp.PrintNameStringAnim(cr, True, message);
      CharHlp.ClearMessageWindow
    end
  end
end;

function RestoreHitPoints(cr: Pointer; amount: Byte; show: Boolean): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffect;
begin
  RestoreHitPoints := False;
  if Types.PCharacter(cr)^.status in
      [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS, C_Status.DYING] then begin
    if ((Types.PCharacter(cr)^.hpCur < Types.PCharacter(cr)^.hpMax) and show) or (not show) then begin
      Types.PCharacter(cr)^.hpCur := Types.PCharacter(cr)^.hpCur + amount;
      if Types.PCharacter(cr)^.hpCur > Types.PCharacter(cr)^.hpMax then
        Types.PCharacter(cr)^.hpCur := Types.PCharacter(cr)^.hpMax;
      if Types.PCharacter(cr)^.inPlay = 0 then begin
        if Types.PCharacter(cr)^.status = C_Status.DYING then Types.PCharacter(cr)^.status := C_Status.UNCONSCIOUS;
        if Types.PCharacter(cr)^.status = C_Status.UNCONSCIOUS then
          if GDVars.locState.current <> C_Ifc.IN_COMBAT then begin
            Types.PCharacter(cr)^.status := C_Status.OKAY;
            Types.PCharacter(cr)^.inPlay := 1
          end
      end;
      RestoreHitPoints := True
    end
  end
end;

function ReviveDeadCreature(cr: Pointer; hp: Byte; message: Types.TStr40): Boolean;
var savedGraphics: Byte;
begin
  if CbtMap.IsValidCreatureLoc(cr, CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), True) then begin
    Types.PCharacter(cr)^.status := C_Status.OKAY;
    Types.PCharacter(cr)^.inPlay := 1;
    Types.PCharacter(cr)^.hpCur := hp;
    if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
      savedGraphics := GDVars.combatGfxOn;
      GDVars.combatGfxOn := 1;
      CbtMap.DisplayMapViewCentered(cr, 3, Byte(False));
      GDVars.combatGfxOn := savedGraphics
    end;
    CharHlp.PrintNameStringAnim(cr, True, message);
    CharHlp.CountTeams;
    ReviveDeadCreature := True
  end else ReviveDeadCreature := False
end;

{ Redraws each spell cloud's covered cells on the arena. }
procedure RefreshExplosionMap;
var patch: Types.PCloudNode; i: Byte;
begin
  patch := GDVars.cloudHead;
  while patch <> nil do begin
    for i := 1 to 9 do
      if patch^.live[i] <> 0 then
        GDVars.combatMap^.cells[patch^.y + GDConsts.dirDy[GDConsts.patchDirections[i]],
                           patch^.x + GDConsts.dirDx[GDConsts.patchDirections[i]]] := patch^.terrain;
    patch := patch^.next
  end
end;

procedure CountDownAreaEffects(expiredOnly: Byte);
var
  previous: Types.PCloudNode;
  patch: Types.PCloudNode;
  nextPatch: Types.PCloudNode;
  cleared: Boolean;
  i: Byte;
  cellX: ShortInt;
  cellY: ShortInt;
  k: Byte;
  found: Boolean;
  expired: Boolean;
begin
  previous := nil;
  patch := GDVars.cloudHead;
  cleared := False;
  while patch <> nil do begin
    nextPatch := patch^.next;
    if Boolean(expiredOnly) then expired := patch^.ttl = -1
    else expired := patch^.ttl <= 1;
    if expired then begin
      with patch^ do
        for i := 1 to 9 do
          if live[i] <> 0 then begin
            cellX := x + GDConsts.dirDx[GDConsts.patchDirections[i]];
            cellY := y + GDConsts.dirDy[GDConsts.patchDirections[i]];
            found := False;
            for k := 1 to GDVars.downedCount do
              if (GDVars.downed[k].cr <> nil) and (GDVars.downed[k].x = cellX) and
                  (GDVars.downed[k].y = cellY) then found := True;
            if found then GDVars.combatMap^.cells[cellY, cellX] := C_Terr.TERRAIN_CORPSE
            else GDVars.combatMap^.cells[cellY, cellX] := savedTerrain[i]
          end;
      cleared := True;
      if previous = nil then GDVars.cloudHead := nextPatch
      else previous^.next := nextPatch;
      FreeMem(patch, SizeOf(Types.TCloudNode))
    end else begin
      previous := patch;
      if not Boolean(expiredOnly) then Dec(patch^.ttl)
    end;
    patch := nextPatch
  end;
  if cleared then begin
    FxEngine.RefreshExplosionMap;
    CharHlp.PrintBottomLine('The air clears a little...')
  end
end;

begin
end.
