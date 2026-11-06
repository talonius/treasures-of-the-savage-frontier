{ CombatAi -- the combat AI: a computer-controlled combatant's turn (CombatAiControl, the unit's only export), with its
  morale check, undead turning, spell choice, weapon choice and the move-and-attack loop. }
{$O+,F+,S+,R-,V-,B-,I-,A+}
unit CombatAi;

interface

uses Types, TextRend, GameIo, CbtActs, ViewChar, Magic, FxEngine, CharHlp, ClassCal, MenuCore, Pathing, CbtMap, Crt,
  GDConsts, GDVars, C_Effect, C_Terr, C_Status, C_Class, C_Cond, C_Equip, C_Item, C_Npc, C_Spell,
  C_Keys, C_Stat;

{ Runs one AI turn. A fresh tactical stance is rolled on a 1 in 4 chance, or when the current one is out of range:
  stances 1..4 usually, 5 or 6 one time in eight. Then morale is checked and the first action that applies is taken: an
  item, a spell already being cast, turning undead, a new spell, and otherwise readying the best weapon and moving and
  attacking until the turn is over.
  @param(cr The creature whose turn it is.) }
procedure CombatAiControl(cr: Types.PCharacter);

implementation

const
  { item values only this unit names }
  { a Strength-adjusted weapon that can also be thrown; tested as a pair }
  ITEM_PROPS_THROWABLE = C_Item.THROWN or C_Item.STRENGTH_BONUS;

function SelectSpellToCast(cr: Types.PCharacter): Boolean; forward;

function PickCastableSpell(cr: Types.PCharacter; var spellCount: Byte): Byte; forward;

function AiMoveAttack(cr: Types.PCharacter): Boolean; forward;

function FinishRound(cr: Types.PCharacter): Boolean; forward;

function CheckKeystroke(cr: Types.PCharacter): Boolean; forward;

function CheckMorale(cr: Types.PCharacter): Boolean; forward;

procedure EquipWeaponAndArmor(cr: Types.PCharacter; lock: Pointer); forward;

function TurnUndeadAi(cr: Types.PCharacter): Boolean; forward;

function SelectItemToUse(cr: Types.PCharacter): Boolean; forward;

procedure CombatAiControl(cr: Types.PCharacter);
var
  stance: Byte;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  dir: Boolean;
begin
  if cr^.combatAddr^.other = nil then
    dir := CbtActs.AcquireTarget(cr, 255, 1, 0, 0);
  done := CombatAi.CheckKeystroke(cr);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if cr^.inPlay = 0 then
    done := CharHlp.EndActions(cr);
  stance := cr^.combatAddr^.aiStance;
  if (stance = 0) or (stance > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    stance := FxEngine.RollDice(1, 8);
    if stance = 8 then
      stance := FxEngine.RollDice(1, 2) + 4
    else
      stance := FxEngine.RollDice(1, 4);
  end;
  cr^.combatAddr^.aiStance := stance;
  if not done then
    done := CombatAi.CheckMorale(cr);
  if (cr^.combatAddr^.fleeing <> 0) and (cr^.combatAddr^.turned = 0) then
    CharHlp.PrintCreatureMessage(cr, 'flees in panic', 10, Byte(True));
  if done then
    Exit;
  if CombatAi.SelectItemToUse(cr) then
    done := CharHlp.EndActions(cr)
  else if cr^.combatAddr^.spellCast > 0 then begin
    Magic.CastSpell(cr^.combatAddr^.spellCast, 1, 1, done);
    done := CharHlp.EndActions(cr);
  end else if CombatAi.TurnUndeadAi(cr) then
    done := CharHlp.EndActions(cr)
  else if CombatAi.SelectSpellToCast(cr) then
    done := True
  else begin
    CombatAi.EquipWeaponAndArmor(cr, cr^.combatAddr^.other);
    done := CombatAi.CheckKeystroke(cr);
    while not done do
      if (cr^.combatAddr^.initiative > 0) and (cr^.inPlay <> 0)
         and CbtActs.AcquireTarget(cr, 255, 1, 0, 0) then
        done := CombatAi.AiMoveAttack(cr)
      else
        done := CombatAi.FinishRound(cr);
  end;
end;

{ Turns undead if cr is not fleeing, has turn attempts left, is a cleric or a paladin above level 2, and has undead in
  range.
  @param(cr The creature.)
  @returns(True if it turned.) }
function TurnUndeadAi(cr: Types.PCharacter): Boolean;
var
  tgt: Pointer;
  best: ShortInt;
begin
  TurnUndeadAi := False;
  if cr^.combatAddr^.fleeing <> 0 then Exit;
  best := 13;
  if (cr^.combatAddr^.turnAttempts < GDVars.undeadCount) and
      ((ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.CLERIC) > 0) or
       (ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.PALADIN) > 2)) and
      CbtActs.FindTurnUndeadTarget(cr, tgt, best) then begin
    TurnUndeadAi := True;
    CbtActs.CombatTurnUndead(cr);
  end;
end;

{ Would choose a magic item for a creature to use. The AI never uses items.
  @param(cr Unused.)
  @returns(False.) }
function SelectItemToUse(cr: Types.PCharacter): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  itemName: array[0..20] of Byte;
begin
  SelectItemToUse := False;
end;

{ Sorts the creature's memorized combat spells by AI priority, highest first, and returns the first one, repeats
  skipped, that RateSpell rates above 0. Note: the sort skips the first memorized slot.
  @param(cr The creature acting.)
  @param(spellCount Unused.)
  @returns(The spell, or 0 if none.) }
function PickCastableSpell(cr: Types.PCharacter; var spellCount: Byte): Byte;
var
  buf: array[0..140] of Byte;
  position: Byte;
  lastSpell: Byte;
  valid: Byte;

  { Insertion-sorts the castable memorized spells into a buffer, highest AI priority first. }
  procedure SortCastableSpells;
  var
    value: Byte;
    temp: Byte;
    outer: Byte;
    inner: Byte;
    inserted: Boolean;
  begin
    for outer := 1 to 140 do begin
      value := cr^.memorized[outer];
      if (value > 0) and (value < C_Spell.PENDING_FLAG) and (GDConsts.spellTable[value].whenCast <> 0) then begin
        inserted := False;
        inner := 0;
        repeat
          if buf[inner] = 0 then begin
            buf[inner] := value;
            inserted := True;
          end else if GDConsts.spellTable[buf[inner]].aiPriority > GDConsts.spellTable[value].aiPriority then
            Inc(inner)
          else begin
            repeat
              temp := buf[inner];
              buf[inner] := value;
              value := temp;
              Inc(inner);
            until (value = 0) or (inner > 140);
            inserted := True;
          end;
        until inserted;
      end;
    end;
  end;

  { Advances to the next spell in the buffer that differs from lastSpell, or sets lastSpell to 0 at the end. }
  procedure NextDistinctSpell;
  var
    done: Boolean;
  begin
    done := False;
    repeat
      if buf[position] = 0 then begin
        done := True;
        lastSpell := 0;
      end else if buf[position] <> lastSpell then begin
        lastSpell := buf[position];
        done := True;
      end else
        Inc(position);
    until done;
  end;

begin
  PickCastableSpell := 0;
  GameIo.ZeroFill(buf, SizeOf(buf));
  SortCastableSpells;
  valid := 0;
  lastSpell := 0;
  position := 0;
  repeat
    NextDistinctSpell;
    if lastSpell <> 0 then
      valid := Byte(CbtActs.RateSpell(cr, lastSpell) > 0);
  until (valid <> 0) or (lastSpell = 0);
  PickCastableSpell := lastSpell;
end;

{ Has cr cast a memorized spell, if it may. A fleeing creature does not cast, nor does anyone in an anti-magic area, nor
  one barred from casting this round, nor a party member while quick magic is off. The chance falls with the creature's
  combined fighter, paladin and ranger levels, and the spell's AI priority must beat 1d5. Note: a higher class-level
  score makes casting less likely.
  @param(cr The creature.)
  @returns(True if a spell was cast.) }
function SelectSpellToCast(cr: Types.PCharacter): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  spellList: array[0..2] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellListTail: Byte;
  { PickCastableSpell's spell count, never read }
  spellCount: Byte;
  outcome: Boolean;
  spell: Byte;
  score: Byte;
begin
  SelectSpellToCast := False;
  if cr^.combatAddr^.fleeing = 0 then begin
    if (GDVars.gameState^.antiMagic <> 0) or (cr^.combatAddr^.castAllowed = 0)
       or ((cr^.npc < $7F) and (GDVars.quickMagic = 0)) then Exit;
    outcome := False;
    spell := CombatAi.PickCastableSpell(cr, spellCount);
    score := ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.FIGHTER) +
      ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.PALADIN) +
      ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.RANGER);
    score := score * 4;
    if spell <> 0 then
      if FxEngine.RollDice(1, 100) > score then
        if GDConsts.spellTable[spell].aiPriority >= FxEngine.RollDice(1, 5) then
          CbtActs.CastSpellCombat(spell, 1, outcome);
    SelectSpellToCast := outcome;
  end;
end;

{ Tells whether a creature can take one step in direction (baseDir + aiDirOffsets[stance, attempt]) mod 8. A diagonal
  step costs half again as much as a straight one. Impassable terrain fails at once. A creature will not step into a
  stinking cloud (29), cloudkill (28) or blade barrier (27) unless it is already affected or immune, or is under a turn.
  @param(cr The creature.)
  @param(attempt The fallback attempt, which picks the offset for the creature's stance.)
  @param(baseDir The direction the offset is added to.)
  @param(edge Receives True if the step would leave the map.)
  @returns(True when the step can be taken.) }
function AiCanStep(cr: Types.PCharacter; attempt, baseDir: Byte; var edge: Boolean): Boolean;
var
  eff: Pointer;
  dirOffset: Byte;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  stepCost: Byte;
  adjSpecial: Byte;
  { the result, copied out at the end }
  ok: Boolean;
begin
  edge := False;
  ok := False;
  dirOffset := GDConsts.aiDirOffsets[cr^.combatAddr^.aiStance, attempt];
  dir := (baseDir + dirOffset) mod 8;
  CbtMap.ProbeDirection(Pointer(cr), dir, Types.PShortInt(@crIdx)^, Types.PShortInt(@terrIdx)^,
                        Types.PShortInt(@adjSpecial)^);
  if terrIdx = 0 then
    edge := True
  else begin
    if GDConsts.terrain[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE then begin
      AiCanStep := False;
      Exit;
    end;
    if Odd(dir) then
      stepCost := GDConsts.terrain[terrIdx].cost * 3
    else
      stepCost := GDConsts.terrain[terrIdx].cost * 2;
    if crIdx = 0 then
      if stepCost < cr^.combatAddr^.movement then begin
        case adjSpecial of
          C_Terr.TERRAIN_STINK_CLOUD: if (not CharHlp.HasEffect(cr, C_Effect.STINKING_CLOUD_COUGH, eff)) and
            (not CharHlp.HasEffect(cr, C_Effect.MINOR_GLOBE, eff)) and (cr^.combatAddr^.turned = 0) and
            ((cr^.immunities and $18) = 0) then
                stepCost := cr^.combatAddr^.movement + 1;
          C_Terr.TERRAIN_CLOUDKILL: if (not CharHlp.HasEffect(cr, C_Effect.GLOBE_OF_INVULNERABILITY, eff))
                 and ((cr^.immunities and $10) = 0)
                 and (cr^.combatAddr^.turned = 0) then
                stepCost := cr^.combatAddr^.movement + 1;
          C_Terr.TERRAIN_BLADE_BARRIER: if cr^.combatAddr^.turned = 0 then
                stepCost := cr^.combatAddr^.movement + 1;
        end;
        if cr^.combatAddr^.movement >= stepCost then
          ok := True;
      end;
  end;
  AiCanStep := ok;
end;

{ Takes one AI movement step: toward the target, or away from the party when fleeing, trying up to five fallback
  directions from aiDirOffsets. A fleeing creature at the map edge tries to escape. A creature that cannot move or keeps
  reversing changes stance, then drops its target, then gives up moving.
  @param(cr The creature.) }
procedure AiMoveStep(cr: Types.PCharacter);
var
  dir: Byte;
  adjDir: Byte;
  attempt: Byte;
  edge: Boolean;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  combat: array[0..4] of Byte;
begin
  TextRend.DisplayStringClear(0, 24, LightGreen, Black,
                        'Move/Attack, Move Left = ' + CharHlp.Uint8Str(cr^.combatAddr^.movement shr 1) + ' ');
  if CombatAi.CheckKeystroke(cr) then Exit;
  if (cr^.combatAddr^.movement shr 1 > 0)
     and (cr^.combatAddr^.initiative > 0)
     and
       ((cr^.npc < C_Npc.NON_PLAYER) or
        ((cr^.npc > $7F) and (GDVars.hostileHpPct <= GDVars.effectMagnitude + FxEngine.RollDice(1, 100))) or
        (cr^.side = 1))
     and ((cr^.combatAddr^.fleeing <> 0) or (cr^.charClass <> C_Class.MAGE)) then begin
    if cr^.combatAddr^.fleeing = 0 then
      dir := CharHlp.DirTowardTarget(cr, cr^.combatAddr^.other)
    else begin
      cr^.combatAddr^.aiStance := FxEngine.RollDice(1, 2);
      dir := GDVars.partyPos.facing - ((GDVars.partyPos.facing + 2) mod 4) div 2 + 1;
      if cr^.side = 0 then
        dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    done := False;
    attempt := 1;
    while (attempt < 6) and (not done) and (not CombatAi.AiCanStep(cr, attempt, dir, edge)) do
      if (cr^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.AttemptFlee(cr)
      else
        Inc(attempt);
    if done then begin
      cr^.combatAddr^.movement := 0;
      cr^.combatAddr^.fleeing := 0;
      done := CharHlp.EndActions(cr);
    end else begin
      if (attempt < 6) and (cr^.combatAddr^.aiStance < 7) then
        adjDir := (dir + GDConsts.aiDirOffsets[cr^.combatAddr^.aiStance, attempt]) mod 8;
      if (attempt = 6) or (GDVars.lastMoveDir = (adjDir + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        cr^.combatAddr^.aiStance := cr^.combatAddr^.aiStance mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          cr^.combatAddr^.other := nil;
          if GDVars.stuckCount > 2 then begin
            cr^.combatAddr^.movement := 0;
            done := True;
          end else if not CbtActs.AcquireTarget(cr, 255, 1, 0, 0) then
            done := CombatAi.FinishRound(cr);
        end;
      end;
      if attempt < 6 then
        GDVars.lastMoveDir := adjDir
      else
        done := True;
    end;
    if not done then begin
      GDVars.combatGfxOn := Byte((GDVars.targetInReach <> 0) or CbtMap.CombatIconVisible(Pointer(cr), 0) or
                                (cr^.side = 0));
      CbtMap.SetCreatureFacing(Pointer(cr), adjDir, 0, 0);
      CbtActs.AttacksOfOpportunity(cr, cr^.combatAddr^.direction);
      if cr^.inPlay = 0 then
        done := CharHlp.EndActions(cr)
      else begin
        if cr^.combatAddr^.movement > 0 then
          CbtActs.CombatMoveCreature(cr, cr^.combatAddr^.direction);
        if (cr^.inPlay = 0) or CharHlp.IsHelpless(cr) then
          done := CharHlp.EndActions(cr);
        FxEngine.ConsiderTerrainEffects(cr, False, False);
      end;
    end;
  end else begin
    if (cr^.combatAddr^.movement shr 1 = 0) and (cr^.combatAddr^.fleeing = 0) then
      done := CombatAi.SelectSpellToCast(cr);
    if not done then
      done := CombatAi.FinishRound(cr);
  end;
end;

{ The move-and-attack loop for one turn. It fires the creature's condition-14 effects, and a party member that bandages
  a dying teammate loses its turn. A fleeing creature spends its movement first. Otherwise each pass works out the
  readied weapon's range, attacks the current target if it is in range and in sight, and if not picks a random enemy in
  reach or steps toward one, stopping when that step leaves it casting a spell. A missile user with an enemy adjacent
  re-equips instead. The in-range flag is shared with AiMoveStep. After 20 passes the turn is ended.
  @param(cr The creature.)
  @returns(True when the creature can act no more this turn.) }
function AiMoveAttack(cr: Types.PCharacter): Boolean;
var
  done: Boolean;
  canAct: Boolean;
  weaponRange: Byte;
  range: Word;
  cnt: Byte;
  pick: Byte;
  weapon: Pointer;
  target: Types.PCharacter;
  tx: ShortInt;
  ty: ShortInt;
  loopCount: Byte;
begin
  GDVars.lastMoveDir := 8;
  GDVars.stuckCount := 0;
  GDVars.stuckCountTail := 0;
  loopCount := 0;
  canAct := True;
  done := False;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MONSTER_SPECIAL, cr);
  if (cr^.side = 0) and CharHlp.BandageDying(True) then
    cr^.combatAddr^.initiative := 0;
  if cr^.combatAddr^.initiative = 0 then
    canAct := False;
  while (not done) and canAct do begin
    if cr^.combatAddr^.fleeing <> 0 then
      while (cr^.combatAddr^.movement > 0)
            and (cr^.combatAddr^.initiative > 0)
            and (cr^.combatAddr^.initiative < 20) do
        CombatAi.AiMoveStep(cr);
    if (cr^.combatAddr^.initiative = 0)
       or (cr^.combatAddr^.initiative = 20) then
      canAct := False
    else
      done := False;
    if (not done) and canAct then begin
      Inc(loopCount);
      { runaway-turn guard }
      if loopCount > 20 then begin
        done := True;
        canAct := (CombatAi.FinishRound(cr) = False);
      end;
      { in range }
      GDVars.targetInReach := 0;
      weaponRange := 1;
      if cr^.equipped[C_Equip.WEAPON] <> nil then
        weaponRange := GDVars.baseItems[cr^.equipped[C_Equip.WEAPON]^.itemType].range;
      if (weaponRange = 0) or (weaponRange = 255) then
        weaponRange := 1;
      target := cr^.combatAddr^.other;
      if (target^.inPlay = 0) or (target^.side = 0) then
        { reads target^ before any nil test }
        target := nil;
      if target <> nil then
        if CbtActs.CanTarget(cr, target, 0) then begin
          tx := CbtMap.CombatCellX(Pointer(target));
          ty := CbtMap.CombatCellY(Pointer(target));
          range := weaponRange;
          GDVars.combatMap^.noHeight := 0;
          if Pathing.WalkLine(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)), tx, ty, range) then
            if range div 2 <= weaponRange then
              GDVars.targetInReach := 1;
        end;
      if GDVars.targetInReach = 0 then begin
        cnt := CharHlp.CountTargets(cr, weaponRange, False);
        if cnt = 0 then begin
          if CbtActs.AcquireTarget(cr, 255, 0, 0, 0) then begin
            { approach }
            CombatAi.AiMoveStep(cr);
            if cr^.combatAddr^.spellCast > 0 then
              canAct := False;
          end else
            done := CombatAi.FinishRound(cr);
        end else begin
          pick := FxEngine.RollDice(1, cnt);
          target := GDVars.creatureArr[GDVars.targetOrder[pick]];
          if CharHlp.HasRangedWeapon(cr)
             and (not CharHlp.HasThrowableWeapon(cr))
             and (CharHlp.CountTargets(cr, 1, False) > 0) then begin
            { pure missile weapon with an enemy adjacent: re-equip }
            CombatAi.EquipWeaponAndArmor(cr, cr^.combatAddr^.other);
            done := True;
          end else if (CharHlp.CalcDistance(cr, target) = 1)
                  or CbtActs.CanTarget(cr, target, 0) then
            GDVars.targetInReach := 1;
        end;
      end;
      if GDVars.targetInReach <> 0 then
        CbtMap.ScrollView(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)), 2,
                          CharHlp.DirTowardTarget(cr, target));
      if GDVars.targetInReach <> 0 then begin
        CbtActs.NoteAttackDirection(cr, target);
        weapon := nil;
        if CharHlp.HasRangedWeapon(cr) then begin
          GDVars.targetInReach := Byte(CharHlp.FindDamagingRangedWeapon(cr, weapon));
          if CharHlp.HasThrowableWeapon(cr) then
            if CharHlp.CalcDistance(cr, target) = 1 then
              { adjacent: melee the throwable }
              weapon := nil;
        end;
        CbtActs.MakeAttack(cr, target, False, weapon, done);
        if done then
          canAct := False
        else if target^.inPlay = 0 then
          done := True;
      end;
    end;
  end;
  AiMoveAttack := canAct = False;
end;

{ Ends the creature's round: a helpless, ranged-armed or out-of-initiative creature just ends its actions; others guard.
  @param(cr The creature.)
  @returns(What ending the actions or guarding returns.) }
function FinishRound(cr: Types.PCharacter): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(cr) or CharHlp.HasRangedWeapon(cr) or (cr^.combatAddr^.initiative = 0)
  then
    FinishRound := CharHlp.EndActions(cr)
  else
    FinishRound := CharHlp.Guard(cr);
end;

{ Handles a key pressed during an AI turn; nothing is read while GDVars.inputAbort is set. Alt-M toggles quick magic.
  Space takes every party member off quick fight and, if cr is now under player control, ends its AI turn. Alt-X tries
  the victory command. Pending keys are flushed afterwards.
  @param(cr The creature whose turn it is.)
  @returns(True when Space put cr under player control.) }
function CheckKeystroke(cr: Types.PCharacter): Boolean;
var
  p: Types.PCharacter;
  ch: Char;
begin
  CheckKeystroke := False;
  if GDVars.inputAbort then Exit;
  if GameIo.InputPending then begin
    ch := GameIo.ReadGameKey;
    if ch = #0 then ch := GameIo.ReadGameKey;
    case ch of
      C_Keys.ALT_M:
        begin
          GDVars.quickMagic := Byte(GDVars.quickMagic = 0);
          if GDVars.quickMagic <> 0 then
            CharHlp.PrintBottomLine('Magic On')
          else
            CharHlp.PrintBottomLine('Magic Off');
        end;
      ' ':
        begin
          p := GDVars.partyHead;
          while p <> nil do begin
            if (p^.npc < C_Npc.NON_PLAYER) and (p^.status <> C_Status.ANIMATED) then
              p^.quickfight := 0;
            p := p^.next;
          end;
          if cr^.quickfight = 0 then begin
            cr^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      C_Keys.ALT_X:
        if CbtActs.VictoryCheat then begin end;
    end;
  end;
  GameIo.DrainKeys;
end;

{ Decides whether cr breaks and flees. A turned creature always flees. A party member never checks. A monster first
  tests its own morale against its lost hit points and stands if it holds. If not, and its side's morale also fails
  against the side's remaining hit points, or it fights on the party's side, it flees when the enemy is no faster than
  half its own speed, and otherwise surrenders if it is smart enough to. A creature that starts to flee fires its
  fleeing effects (trigger condition 27).
  @param(cr The creature.)
  @returns(True if its turn is over.) }
function CheckMorale(cr: Types.PCharacter): Boolean;
var
  enemyMove: Byte;
  { Unused in this version; see the other implementations of this routine. }
  moraleSave: Byte;
begin
  CheckMorale := False;
  cr^.combatAddr^.fleeing := 0;
  if cr^.combatAddr^.turned <> 0 then begin
    cr^.combatAddr^.fleeing := 1;
    CharHlp.PrintCreatureMessage(cr, 'is forced to flee', 10, Byte(True));
    FxEngine.TriggerEffectsWithCondition(27, cr);
    Exit;
  end;
  if cr^.npc <= $7F then
    Exit;
  { The morale check keeps its working value in the effect-magnitude byte. }
  GDVars.effectMagnitude := (cr^.npc and C_Npc.MORALE_MASK) * 2;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, cr);
  if (GDVars.effectMagnitude >= 100 - cr^.hpCur * 100 div cr^.hpMax) and (GDVars.effectMagnitude <> 0) then
    Exit;
  moraleSave := GDVars.effectMagnitude;
  GDVars.effectMagnitude := GDVars.hostileHpPct;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MORALE_CHECK, cr);
  if (GDVars.effectMagnitude < 100 - GDVars.gameState^.moraleAdj) or (GDVars.effectMagnitude = 0) or
      (cr^.side = 0) then begin
    enemyMove := CbtActs.HighestEnemyMovement(cr);
    if enemyMove <= CharHlp.RecalcMovement(cr) div 2 then begin
      cr^.combatAddr^.fleeing := 1;
      FxEngine.TriggerEffectsWithCondition(27, cr);
    end else if cr^.stats[C_Stat.INTELLIGENCE].current > 5 then begin
      FxEngine.PutOutOfPlayWithStatus(cr, C_Status.UNCONSCIOUS, 'Surrenders');
      CheckMorale := CharHlp.EndActions(cr);
    end;
  end;
end;

{ Readies a creature's best weapon and shield for the fight against `lock`, the creature it is targeting. Effects on
  that creature can demand a minimum magical bonus for melee and missile weapons, or halve the value of certain weapon
  classes. The best missile weapon is chosen over the best melee weapon when it scores better than half as well, has
  ammunition, and is either a true missile weapon or no enemy is adjacent. Cursed items stay where they are, and a
  shield is shed when the hands run out. The combatant's display is refreshed if anything changed.
  @param(cr The creature.)
  @param(lock The creature it is targeting.) }
procedure EquipWeaponAndArmor(cr: Types.PCharacter; lock: Pointer);
var
  { HasEffect's out-parameter, never read }
  scratch: Pointer;
  bestRanged: Types.PItem;
  bestMelee: Types.PItem;
  bestShield: Types.PItem;
  { the walk pointer, then the chosen weapon }
  it: Types.PItem;
  ammo: Types.PItem;
  bestRangedPri: Byte;
  bestMeleePri: Byte;
  bestShieldPri: Byte;
  minPlusMelee: Byte;
  minPlusRanged: Byte;
  { a weapon's score, then a shield's }
  pri: Byte;
  itType: Byte;
  props: Byte;
  { Unused in this version; see the other implementations of this routine. }
  baseItem: Byte;
  needSwap: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  wpnClassHiFlag: Byte;
  wpnClassLoFlag: Byte;
  hasAmmo: Boolean;

  { Scores a weapon for cr by damage, bonuses, shots and hands; an unusable one scores 0. }
  function CalcWeaponPriority(it: Types.PItem): Byte;
  var
    pri: Byte;
    base: Types.TBaseItem;
  begin
    base := GDVars.baseItems[it^.itemType];
    pri := base.dmgSmDice * base.dmgSmRolls;
    if it^.plus > 0 then
      pri := pri + it^.plus * 8;
    if base.dmgSmMod > 0 then
      pri := pri + base.dmgSmMod * 2;
    if (base.props and C_Item.FIRES_AMMO) > 0 then
      pri := pri + (base.rateOfFire - 1) * 2;
    if base.hands <= 1 then
      pri := pri + 3;
    if base.hands + cr^.handsEquipped > 3 then
      pri := 0;
    if it^.special = $84 then
      if (it^.effect and $0F) <> cr^.alignment then
        pri := 0;
    if it^.effect = 83 then
      pri := 0;
    if it^.cursed <> 0 then
      pri := 0;
    if ((base.wpnClass <= 1) and (wpnClassLoFlag <> 0)) or ((base.wpnClass > $7F) and (wpnClassHiFlag <> 0)) then
      pri := pri div 2;
    if ((base.props and C_Item.FIRES_AMMO) <> 0) or ((base.props and C_Item.THROWN) <> 0) then begin
      if it^.plus < minPlusRanged then
        pri := 0;
    end else if it^.plus < minPlusMelee then
      pri := 0;
    CalcWeaponPriority := pri;
  end;

begin
  minPlusMelee := 0;
  if lock <> nil then begin
    if CharHlp.HasEffect(lock, C_Effect.IMMUNE_WEAPONS_UNDER_PLUS_2, scratch) then
      minPlusMelee := 2;
    if CharHlp.HasEffect(lock, C_Effect.HIT_BY_PLUS_3_ONLY, scratch) then
      minPlusMelee := 3;
    if CharHlp.HasEffect(lock, C_Effect.LUCK_STONE, scratch)
       or CharHlp.HasEffect(lock, C_Effect.HALF_DAMAGE_WEAPONS_UNDER_PLUS_3, scratch)
       or CharHlp.HasEffect(lock, C_Effect.IMMUNE_NONMAGIC, scratch) then
      minPlusMelee := 1;
    minPlusRanged := minPlusMelee;
    if (minPlusRanged = 0) and CharHlp.HasEffect(lock, C_Effect.PROTECTION_FROM_MISSILES, scratch) then
      minPlusRanged := 1;
    wpnClassLoFlag := Byte(CharHlp.HasEffect(lock, C_Effect.HALF_DAMAGE_PIERCE_CUT, scratch));
    wpnClassHiFlag := Byte(CharHlp.HasEffect(lock, C_Effect.HALF_DAMAGE_CRUSH, scratch));
  end else begin
    minPlusRanged := 0;
    wpnClassHiFlag := 0;
    wpnClassLoFlag := 0;
  end;

  if cr^.equipped[C_Equip.WEAPON] <> nil then
    cr^.handsEquipped := cr^.handsEquipped
        - GDVars.baseItems[cr^.equipped[C_Equip.WEAPON]^.itemType].hands;
  if cr^.equipped[C_Equip.SHIELD] <> nil then
    cr^.handsEquipped := cr^.handsEquipped
        - GDVars.baseItems[cr^.equipped[C_Equip.SHIELD]^.itemType].hands;

  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  bestRangedPri := 1;
  bestMeleePri := cr^.unarmedDice[1] * cr^.unarmedRolls[1];
  if cr^.unarmedMod[1] > 0 then
    bestMeleePri := bestMeleePri + cr^.unarmedMod[1] * 2;
  bestShieldPri := 0;
  it := cr^.items;
  while it <> nil do begin
    itType := it^.itemType;
    if GDVars.baseItems[itType].slot = C_Equip.WEAPON then
      if (GDVars.baseItems[itType].classMask and cr^.classMask) <> 0 then begin
        pri := CalcWeaponPriority(it);
        if ((GDVars.baseItems[itType].props and C_Item.FIRES_AMMO) <> 0)
           or ((GDVars.baseItems[itType].props and C_Item.THROWN) <> 0) then
          if pri > bestRangedPri then begin
            bestRanged := it;
            bestRangedPri := pri;
          end;
        if (GDVars.baseItems[itType].props and C_Item.FIRES_AMMO) = 0 then
          if pri > bestMeleePri then begin
            bestMelee := it;
            bestMeleePri := pri;
          end;
      end;
    if GDVars.baseItems[itType].slot = C_Equip.SHIELD then
      if (GDVars.baseItems[itType].classMask and cr^.classMask) > 0 then begin
        if it^.plus >= 0 then
          pri := it^.plus + 1
        else
          pri := 0;
        if pri > bestShieldPri then begin
          bestShield := it;
          bestShieldPri := pri;
        end;
      end;
    it := it^.next;
  end;

  if (bestRanged <> nil) and (GDVars.baseItems[bestRanged^.itemType].range > 1) and
      ((GDVars.baseItems[bestRanged^.itemType].props and CombatAi.ITEM_PROPS_THROWABLE) =
       CombatAi.ITEM_PROPS_THROWABLE) then
    trueRanged := True
  else
    trueRanged := False;

  hasAmmo := False;
  ammo := nil;
  props := 0;
  if bestRanged <> nil then begin
    props := GDVars.baseItems[bestRanged^.itemType].props;
    if (props and C_Item.THROWN) <> 0 then
      ammo := bestRanged;
    if (props and C_Item.FIRES_AMMO) <> 0 then begin
      if (props and C_Item.USES_ARROWS) <> 0 then
        ammo := cr^.equipped[C_Equip.ARROW];
      if (props and C_Item.USES_QUARRELS) <> 0 then
        ammo := cr^.equipped[C_Equip.BOLT];
    end;
  end;
  if (ammo <> nil) or (props = $A) then
    hasAmmo := True;

  if (bestRanged <> nil)
     and (bestRangedPri > bestMeleePri div 2)
     and hasAmmo
     and (trueRanged or (CharHlp.CountTargets(cr, 1, False) = 0)) then
    it := bestRanged
  else
    it := bestMelee;

  changed := False;
  needSwap := True;
  if cr^.equipped[C_Equip.WEAPON] <> nil then
    if (cr^.equipped[C_Equip.WEAPON] = it) or (cr^.equipped[C_Equip.WEAPON]^.cursed <> 0) then
      needSwap := False;
  if needSwap then begin
    if cr^.equipped[C_Equip.WEAPON] <> nil then
      ViewChar.ToggleReadyItem(cr^.equipped[C_Equip.WEAPON]);
    CharHlp.RecalcStats(cr);
    if cr^.equipped[C_Equip.SHIELD] <> nil then
      if cr^.equipped[C_Equip.SHIELD]^.cursed = 0 then
        cr^.handsEquipped := cr^.handsEquipped
            - GDVars.baseItems[cr^.equipped[C_Equip.SHIELD]^.itemType].hands;
    if it <> nil then
      ViewChar.ToggleReadyItem(it);
    changed := True;
  end;
  CharHlp.RecalcStats(cr);
  CbtActs.RecalcAttacksLeft(cr);
  needSwap := True;
  if cr^.equipped[C_Equip.SHIELD] <> nil then
    if (cr^.equipped[C_Equip.SHIELD] = bestShield) or (cr^.equipped[C_Equip.SHIELD]^.cursed <> 0) then
      needSwap := False;
  if cr^.handsEquipped > 2 then begin
    { over-handed: shed the shield, or the new weapon if it's stuck }
    if (cr^.equipped[C_Equip.SHIELD] = nil) or (cr^.equipped[C_Equip.SHIELD]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(it);
      changed := True;
    end else begin
      ViewChar.ToggleReadyItem(cr^.equipped[C_Equip.SHIELD]);
      changed := True;
    end;
  end else if (cr^.handsEquipped < 2) and needSwap then begin
    if cr^.equipped[C_Equip.SHIELD] <> nil then
      ViewChar.ToggleReadyItem(cr^.equipped[C_Equip.SHIELD]);
    CharHlp.RecalcStats(cr);
    if bestShield <> nil then
      ViewChar.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(cr);
  if changed then
    CharHlp.CombatPrintCreatureInfo(cr);
end;

begin
end.
