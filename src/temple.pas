{ Temple -- the temple: the healer building's "Heal View Repair Exit" menu (TempleMainMenu). Heal offers the current
  character an 11-item cure menu (HealMenu); View is ViewCharMenu; Repair (RepairParty) restores the whole roster with
  no menu or prompt. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit Temple;

interface

{ Runs the temple: the money pool starts empty, and the menu offers Heal (HealMenu, the cure picker), View and Repair
  (RepairParty, which cures the whole party with no prompts) until Exit or Escape. The up and down arrow keys change the
  current character. }
procedure TempleMainMenu;

{ Cure the whole party unconditionally, with no menu and no prompts: blindness, feeblemind, disease, poison, death
  (spell 105), petrification and lost levels, then recompute the stats and restore full hit points to anyone not Dead or
  Gone. This repeats the cure helpers' work inline, so a change to one side needs the other. }
procedure RepairParty;

implementation

uses Types, ViewChar, Magic, FxEngine, CharHlp, MenuCore, Border, GameIo, TextRend, Crt, GDConsts, GDVars, C_Effect,
  C_Keys, C_Status, C_Stat, C_Class, C_Ifc, C_Race;

{ Reports that the current character does not need the cure and asks whether to cast it anyway, with No as the default.
  @param(msg The report, printed after the character's name.)
  @returns(The answer, Yes or No.) }
function ConfirmCureAnyway(msg: String): Byte;
begin
  CharHlp.PrintCreatureMessage(GDVars.curChar, msg, 0, Byte(False));
  ConfirmCureAnyway := MenuCore.YesNoMenu(GDConsts.cureAnywayPrompt, GDConsts.noChoice);
  CharHlp.ClearMessageWindow;
end;

{ Removes the character's blindness, asking first when the character is not blind. }
procedure CureBlindness;
var
  tmpEff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  s: String;
  save: Byte;
begin
  save := GDConsts.yesChoice;
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, tmpEff) then
    save := Temple.ConfirmCureAnyway(GDConsts.notBlindMsg);
  if save = GDConsts.yesChoice then
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
end;

{ Cures the current character's disease: removes the four disease effects with the effect lock set and recalculates its
  Strength, or says it is not diseased. }
procedure CureDisease;
var
  tmpEff: Pointer;
  i: Byte;
  found: Boolean;
  msg: Types.TStr40;
begin
  found := False;
  for i := 1 to 4 do begin
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.diseaseEffects[i], tmpEff) then begin
      found := True;
      i := 4;
    end;
  end;
  if not found then begin
    msg := 'is not Diseased';
  end else begin
    GDVars.effectBusy := 1;
    for i := 1 to 4 do
      FxEngine.RemoveEffect(GDVars.curChar, GDConsts.diseaseEffects[i], nil);
    FxEngine.RecalcAbility(GDVars.curChar, C_Stat.STRENGTH);
    GDVars.effectBusy := 0;
    msg := 'is cured';
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, msg, 0, Byte(True));
end;

{ The healing spells, by `mode`: 1 Cure Light Wounds (1d8), 2 Cure Serious Wounds (2d8+1), 3 Cure Critical Wounds
  (3d8+3), 4 Heal, which restores all but 1d4 hit points (nothing when that would pass the maximum), removes blindness
  and feeblemind and recalculates Intelligence and Wisdom.
  @param(mode The cure, 1..4.) }
procedure CureWounds(mode: Byte);
var
  amt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fill1: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fill2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  restored: Boolean;
begin
  case mode of
    1: begin
         amt := FxEngine.RollDice(1, 8);
         restored := FxEngine.RestoreHitPoints(GDVars.curChar, amt, False);
       end;
    2: begin
         amt := FxEngine.RollDice(2, 8) + 1;
         restored := FxEngine.RestoreHitPoints(GDVars.curChar, amt, False);
       end;
    3: begin
         amt := FxEngine.RollDice(3, 8) + 3;
         restored := FxEngine.RestoreHitPoints(GDVars.curChar, amt, False);
       end;
    4: begin
         amt := FxEngine.RollDice(1, 4);
         if (GDVars.curChar^.hpCur + amt) > GDVars.curChar^.hpMax then
           amt := 0
         else
           amt := GDVars.curChar^.hpMax - GDVars.curChar^.hpCur - amt;
         restored := FxEngine.RestoreHitPoints(GDVars.curChar, amt, False);
         FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
         FxEngine.RemoveEffect(GDVars.curChar, C_Effect.FEEBLEMIND, nil);
         FxEngine.RecalcAbility(GDVars.curChar, C_Stat.INTELLIGENCE);
         FxEngine.RecalcAbility(GDVars.curChar, C_Stat.WISDOM);
       end;
  end;
end;

{ Raise Dead: cast it on a Dead or Animated character of a real race who is not Gone; any other character gets the
  reason they cannot be raised and the confirmation prompt, which changes nothing. }
procedure RaiseDead;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: array[1..4] of Byte;
  save: Byte;
  isDead: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  fill2: array[1..4] of Byte;
  target: Types.PCharacter;
  isGone: Boolean;
  notInPlay: Boolean;
begin
  target := GDVars.curChar;
  isDead := False;
  notInPlay := False;
  save := GDConsts.yesChoice;
  if (target^.status = C_Status.DEAD_STATUS) or (target^.status = C_Status.ANIMATED) then
    isDead := True;
  isGone := (target^.status = C_Status.GONE);
  if target^.race < 1 then
    notInPlay := True;
  if not (isDead and (not notInPlay)) then begin
    if notInPlay then
      save := Temple.ConfirmCureAnyway(GDConsts.cannotRaiseMsg)
    else if isGone then
      save := Temple.ConfirmCureAnyway(GDConsts.beyondHelpMsg)
    else
      save := Temple.ConfirmCureAnyway(GDConsts.notDeadMsg);
  end;
  if (save = GDConsts.yesChoice) and isDead and (not notInPlay) and (not isGone) then begin
    GDVars.spellTargets[1] := target;
    GDVars.opMode := 75;
    GDVars.spellFns.spells[75];
  end;
end;

{ Neutralizes poison: clears the poison effects of a poisoned character and brings it back into play with at least one
  hit point, asking first when the character is not poisoned (a Yes then changes nothing). }
procedure NeutralizePoison;
var
  tmpEff: Pointer;
  save: Byte;
  found: Boolean;
begin
  found := False;
  save := GDConsts.yesChoice;
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, tmpEff) then
    found := True;
  if not found then
    save := Temple.ConfirmCureAnyway('is not poisoned.');
  if (save = GDConsts.yesChoice) and found then begin
    if GDVars.curChar^.hpCur = 0 then
      GDVars.curChar^.hpCur := 1;
    GDVars.effectBusy := 1;
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectBusy := 0;
    GDVars.curChar^.inPlay := 1;
    GDVars.curChar^.status := C_Status.OKAY;
  end;
end;

{ Casts Remove Curse on the character, asking first when the character has no cursed item and no curse effect. }
procedure RemoveCurse;
var
  found: Boolean;
  it: Types.PItem;
  tmpEff: Pointer;
  save: Byte;
begin
  save := GDConsts.yesChoice;
  found := False;
  it := GDVars.curChar^.items;
  while (it <> nil) and (not found) do begin
    if it^.cursed <> 0 then
      found := True;
    it := it^.next;
  end;
  if not found then begin
    if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BESTOW_CURSE, tmpEff) then
      save := Temple.ConfirmCureAnyway(GDConsts.notCursedMsg);
  end;
  if save = GDConsts.yesChoice then begin
    GDVars.spellTargets[1] := GDVars.curChar;
    Magic.SpellRemoveCurse;
  end;
end;

{ Returns a petrified character to play with one hit point, asking first when the character is not petrified (a Yes then
  changes nothing). }
procedure StoneToFlesh;
var
  { Unused in this version; see the other implementations of this routine. }
  effect: array[1..4] of Byte;
  save: Byte;
begin
  save := GDConsts.yesChoice;
  if GDVars.curChar^.status <> C_Status.PETRIFIED then
    save := Temple.ConfirmCureAnyway(GDConsts.notStonedMsg);
  if (save = GDConsts.yesChoice) and (GDVars.curChar^.status = C_Status.PETRIFIED) then begin
    GDVars.curChar^.status := C_Status.OKAY;
    GDVars.curChar^.inPlay := 1;
    GDVars.curChar^.hpCur := 1;
  end;
end;

{ Casts Restoration on the current character through the spell table, first asking to confirm when none of its class
  levels is below its old peak. }
procedure Restoration;
var
  save: Byte;
  anyLoss: Boolean;
  i: ShortInt;
begin
  anyLoss := False;
  save := GDConsts.yesChoice;
  with GDVars.curChar^ do
    for i := C_Class.CLERIC to C_Class.THIEF do
      if classLevels[i] < classLevelCap[i] then
        anyLoss := True;
  if not anyLoss then
    save := Temple.ConfirmCureAnyway(GDConsts.noLostLevelsMsg);
  if save = GDConsts.yesChoice then begin
    GDVars.spellTargets[1] := GDVars.curChar;
    GDVars.opMode := 102;
    GDVars.spellFns.spells[102];
  end;
end;

{ Runs the cure menu for the current character, showing its hit points, with eleven entries named after the healing
  spells, until the player picks Exit or presses Escape. }
procedure HealMenu;
var
  list: Pointer;
  sel: Pointer;
  redraw: Boolean;
  i: Byte;
  idx: Integer;
  done: Boolean;
  promptMsg: Types.TStr40;
  ch: Char;
  hpShort: String[10];
  hpLen: Byte;
  hpFg: Byte;
begin
  done := False;
  list := nil;
  sel := nil;
  MenuCore.AllocStringList(11, list);
  sel := list;
  i := 1;
  while list <> nil do begin
    Types.PItemRec(list)^.name := GDConsts.spellNames[GDConsts.nameIdxTable[i]];
    Types.PItemRec(list)^.inUse := 0;
    list := Pointer(Types.PItemRec(list)^.next);
    Inc(i);
  end;
  list := sel;
  Border.EraseBox(0, 24, 39, 24);
  redraw := True;
  Border.ScreenText;
  idx := 0;
  repeat
    Border.EraseBox(1, 19, 38, 19);
    TextRend.DisplayString(1, 19, White, Black, GDVars.curChar^.name);
    hpShort := CharHlp.Uint16Str(GDVars.curChar^.hpCur);
    hpLen := Length(hpShort);
    if GDVars.curChar^.hpCur <> GDVars.curChar^.hpMax then
      hpFg := 13
    else
      hpFg := 15;
    TextRend.DisplayString(18, 19, hpFg, Black, hpShort);
    hpShort := '/' + CharHlp.Uint16Str(GDVars.curChar^.hpMax);
    TextRend.DisplayString(hpLen + 18, 19, White, Black, hpShort);
    promptMsg := GDVars.curChar^.name + GDConsts.howCanWeHelpPrompt;
    TextRend.DisplayString(1, 1, White, Black, promptMsg);
    MenuCore.ResetMenuSlots(0);
    ch := MenuCore.MenuVertical(GDConsts.emptyQuery, GDConsts.healHeading, 2, 3, 38, 15, list, True, 0, redraw, idx,
                                sel);
    if GDVars.menuReturnedKey then begin
      if ch = C_Keys.ESCAPE then
        done := True;
    end else case ch of
      #0: begin
        case idx of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.CureWounds(4);
          6: Temple.NeutralizePoison;
          7: Temple.RaiseDead;
          8: Temple.RemoveCurse;
          9: Temple.StoneToFlesh;
          10: Temple.Restoration;
          11: done := True;
        end;
      end;
      #1: done := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
end;

procedure RepairParty;
var
  i: Byte;
  k: Byte;
  cr: Types.PCharacter;
  j: ShortInt;
  anyLoss: Boolean;
  tmpEff: Pointer;
begin
  cr := GDVars.partyHead;
  while cr <> nil do begin
    FxEngine.RemoveEffect(cr, C_Effect.FEEBLEMIND, nil);
    FxEngine.RemoveEffect(cr, C_Effect.BLIND, nil);
    for i := 1 to 4 do
      FxEngine.RemoveEffect(cr, GDConsts.diseaseEffects[i], nil);
    if CharHlp.HasEffect(cr, C_Effect.POISONED, tmpEff) then begin
      if cr^.hpCur = 0 then
        cr^.hpCur := 1;
      GDVars.effectBusy := 1;
      FxEngine.RemoveEffect(cr, C_Effect.POISONED, nil);
      FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_END, nil);
      FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_HIT, nil);
      GDVars.effectBusy := 0;
      cr^.inPlay := 1;
      cr^.status := C_Status.OKAY;
    end;
    if (cr^.status = C_Status.DEAD_STATUS) and (cr^.status <> C_Status.GONE) and
        (cr^.race <> C_Race.ELF) then begin
      GDVars.spellTargets[1] := cr;
      GDVars.opMode := 105;
      GDVars.spellFns.spells[105];
    end;
    if cr^.status = C_Status.PETRIFIED then begin
      cr^.status := C_Status.OKAY;
      cr^.inPlay := 1;
    end;
    repeat
      anyLoss := False;
      with cr^ do
        for j := C_Class.CLERIC to C_Class.THIEF do
          if classLevels[j] < classLevelCap[j] then
            anyLoss := True;
      if anyLoss then begin
        GDVars.spellTargets[1] := cr;
        GDVars.opMode := 102;
        GDVars.spellFns.spells[102];
      end;
    until not anyLoss;
    for k := C_Stat.STRENGTH to C_Stat.CHARISMA do
      FxEngine.RecalcAbility(cr, k);
    if (cr^.status <> C_Status.DEAD_STATUS) and (cr^.status <> C_Status.GONE) then
      cr^.hpCur := cr^.hpMax;
    if cr^.status = C_Status.UNCONSCIOUS then begin
      cr^.status := C_Status.OKAY;
      cr^.inPlay := 1;
    end;
    cr := cr^.next;
  end;
end;

procedure TempleMainMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  submenu: Word;
  ch: Char;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  hotkeys: array[1..6] of Byte;
begin
  GDVars.locState.current := C_Ifc.IN_SHOP;
  GDVars.splitFrameGate := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.splitFrameGate := 1;
  CharHlp.DisplayParty(GDVars.curChar);
  GameIo.ZeroFill(GDVars.pooledMoney, SizeOf(GDVars.pooledMoney));
  GDVars.poolHasMoney := False;
  done := False;
  repeat
    MenuCore.ResetMenuSlots(3);
    ch := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.healBuildingMenu, Byte(True), Byte(False));
    if GDVars.menuReturnedKey then begin
      case ch of
        C_Keys.ESCAPE: ch := #3;
        C_Keys.UP, C_Keys.DOWN: begin
          ViewChar.SelectPrevNextChar(ch);
          ch := #255;
        end;
      end;
    end;
    case ch of
      #0: Temple.HealMenu;
      #1: ViewChar.ViewCharMenu(GDVars.menuReturnedKey);
      #2: Temple.RepairParty;
      #3: done := True;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
end;

begin
end.
