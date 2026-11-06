{ Combat -- the combat round driver (CombatMain, the unit's only export): initiative order, each creature's turn, the
  player's combat menus, end-of-round upkeep, and deaths from old age after the battle. }
{$O+,F+,S+,R-,V-,B-,I-}
unit Combat;

interface

uses Types, GDConsts, GDVars, C_Dir, C_Keys, C_Status, C_Cond, C_Class, C_Ifc, C_Npc,
  C_Spell, C_Terr, Blit, TextRend, Border, GameIo, Crt, CombatAi, CombatSt, EffHndlr, CbtActs, ViewChar, GameTime,
  Magic, FxEngine, CharHlp, ClassCal, MenuCore, CbtMap, MapTiles;

{ Runs a whole fight. Frees the border backdrop, sets up the arena and fires each creature's start-of-combat effects
  (trigger condition 24), then plays rounds until one side has no one left standing or the round limit is reached;
  within a round each combatant acts in initiative order, and in a duel (GDVars.inputAbort) a key ends the fight.
  Afterwards it ages the survivors when the fight aged them and tears the fight down. }
procedure CombatMain;

implementation

const
  { scan codes of the combat menu's Alt keys, read after the #0 of an extended key }
  KEY_ALT_Q = #16;
  KEY_ALT_R = #19;
  KEY_ALT_A = #30;

procedure AgingDeaths; forward;

procedure OrderCreatures; forward;

procedure CreatureAction(cr: Types.PCharacter); forward;

procedure ManualControl(cr: Types.PCharacter); forward;

procedure CombatMenu(cr: Types.PCharacter; var ch: Char); forward;

procedure JoinDelayedCombatants; forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(cr: Types.PCharacter; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PCharacter; var done: Boolean); forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(cr: Types.PCharacter); forward;

{ Tears down the fight: frees the arena's cloud list, strips every creature of the effects lost at zero hit points and
  fires its end-of-combat effects (trigger condition 26), frees the arena and its images and icons, and restores the
  noncombat spell target picker. }
procedure CombatDoneCleanup;
var
  { reused by the free loop }
  nx: Types.PCloudNode;
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  i: Byte;
begin
  while GDVars.cloudHead <> nil do begin
    nx := GDVars.cloudHead^.next;
    FreeMem(GDVars.cloudHead, SizeOf(Types.TCloudNode));
    GDVars.cloudHead := nx;
  end;
  p := GDVars.partyHead;
  while p <> nil do begin
    FxEngine.RemoveEffectsHp0(p);
    FxEngine.TriggerEffectsWithCondition(26, p);
    p := p^.next;
  end;
  FreeMem(GDVars.combatMap, SizeOf(Types.TCombatMap));
  GDVars.combatMap := nil;
  Blit.FreePic(GDVars.combatImage);
  Blit.FreePic(GDVars.icon24Bank);
  for i := 0 to 21 do
    MapTiles.FreeIconAnim(i + 13);
  GDVars.spellFns.selectTarget := Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  flagA: Boolean;
  flagB: Boolean;
  cr: Types.PCharacter;
begin
  Border.FreeBorderBackdrop;
  flagA := False;
  GDVars.locState.current := C_Ifc.IN_COMBAT;
  GDVars.spellFns.selectTarget := CbtActs.SelectCombatTargets;
  CbtActs.UseLeadership;
  CombatSt.CombatStart;
  flagB := False;
  if (GDVars.sideTally[0] = 0) or (GDVars.sideTally[1] = 0) then
    flagB := True;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    FxEngine.TriggerEffectsWithCondition(24, cr);
    cr := cr^.next;
  end;
  while not flagB do begin
    CharHlp.CountTeams;
    cr := GDVars.partyHead;
    while cr <> nil do begin
      CbtActs.BeginRound(cr);
      cr := cr^.next;
    end;
    GDVars.gameState^.initPenaltyMask := 0;
    Combat.OrderCreatures;
    cr := GDVars.initQueue[1];
    GDVars.initQueueCount := 1;
    while (cr <> nil) and (flagB = False) do begin
      Combat.CreatureAction(cr);
      Inc(GDVars.initQueueCount);
      if GDVars.initQueueCount > 72 then
        cr := nil
      else
        cr := GDVars.initQueue[GDVars.initQueueCount];
      CharHlp.CountTeams;
      if (GDVars.sideTally[0] = 0) or (GDVars.sideTally[1] = 0) or
          (GDVars.cbRoundCounter >= GDVars.cbNewFlag) then
        if not flagA then begin
          flagB := True;
          flagA := True;
        end;
      EffHndlr.ShowCrystalSmash;
      if GDVars.inputAbort then
        if KeyPressed then begin
          GameIo.DrainKeys;
          flagB := True
        end;
    end;
    Combat.EndOfRound(flagB);
  end;
  MenuCore.ClearBottomLine;
  if GDVars.agingFlag <> 0 then
    Combat.AgingDeaths;
  Combat.CombatDoneCleanup;
  GDVars.msgDelayFlag := 1;
end;

{ After a fight that aged its combatants: anyone within ten years of their race's age limit is warned that they look
  very old, and anyone past it dies of old age, mourned according to how many able party members witness it. Note: warn
  keeps its previous value for a creature that dies, and count is never cleared, so the warning and the choice of grief
  message can come from stale values. }
procedure AgingDeaths;
var
  p: Types.PCharacter;
  q: Types.PCharacter;
  witness: Types.PCharacter;
  { warn is not reset when diesOfAge is True }
  diesOfAge: Boolean;
  warn: Boolean;
  row: Byte;
  { never initialized: only Inc'd and tested }
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  countTail: Byte;
  he: String[4];
  msg: Types.TStr255;
begin
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.status < C_Status.DEAD_STATUS) and (p^.combatAddr^.notPcNpc <> 1) then
      with p^ do begin
        diesOfAge := age > GDConsts.ageThreshold[race];
        if not diesOfAge then
          warn := age > GDConsts.ageThreshold[race] - 10;
        if warn then
          CharHlp.PrintCreatureMessage(p, 'is looking very old', 10, 1);
        if diesOfAge then begin
          row := 14;
          Border.EraseBox(23, row, 38, 21);
          TextRend.DisplayMessageWindow(23, row, 38, 21, White, Black, True,
                                  'The strain of this last battle has worn heavily on ' + name + '.  ');
          TextRend.DisplayAndPause(LightMagenta, Black, GDConsts.pressButtonPrompt);
          Border.EraseBox(23, row, 38, 21);
          if gender = 0 then
            he := 'He'
          else
            he := 'She';
          TextRend.DisplayMessageWindow(23, row, 38, 21, White, Black, True,
                                  he + ' breathes deeply one last time and crumples to the ground.');
          TextRend.DisplayAndPause(LightMagenta, Black, GDConsts.pressButtonPrompt);
          Border.EraseBox(23, row, 38, 21);
          FxEngine.KillCreature(p, C_Status.GONE, 'dies from age');
          q := GDVars.partyHead;
          while q <> nil do begin
            if (q^.inPlay = 1) and (q^.status = C_Status.OKAY) and (q^.side <> 1) then begin
              Inc(count);
              witness := q;
            end;
            q := q^.next;
          end;
          case count of
            0: msg := 'Sadly, no party member witnesses the passing of the champion.';
            1: msg := witness^.name + ' weeps at the loss of such a venerable companion.';
          else
            msg := ' The remaining party members are overcome with grief as they search '
                 + name + '''s body for valuables.';
          end;
          Border.EraseBox(23, row, 38, 21);
          TextRend.DisplayMessageWindow(23, row, 38, 21, Yellow, Black, True, msg);
          TextRend.DisplayAndPause(LightMagenta, Black, GDConsts.pressButtonPrompt);
        end;
      end;
    p := p^.next;
  end;
  GDVars.agingFlag := 0;
end;

{ Insertion-sorts the combatants into the initiative queue by initiative, highest first; a tie goes either way on a coin
  flip, and an empty slot counts as initiative -1. Note: the insertion scan looks at the first 64 slots, while the shift
  that makes room runs to the end of the queue. }
procedure OrderCreatures;
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  okTail: Byte;
  p: Types.PCharacter;
  cur: Types.PCharacter;
  nxt: Types.PCharacter;
  ins: ShortInt;
  other: ShortInt;
  slot: Byte;
  j: Byte;
begin
  p := GDVars.partyHead;
  GameIo.ZeroFill(GDVars.initQueue, SizeOf(GDVars.initQueue));
  while p <> nil do begin
    slot := 1;
    ok := True;
    ins := p^.combatAddr^.initiative;
    while (slot < 65) and ok do begin
      if GDVars.initQueue[slot] <> nil then
        other := GDVars.initQueue[slot]^.combatAddr^.initiative
      else
        other := -1;
      if (ins > other) or ((ins = other) and (FxEngine.RollDice(1, 2) = 1)) then
        ok := False
      else
        Inc(slot);
    end;
    cur := GDVars.initQueue[slot];
    GDVars.initQueue[slot] := p;
    if cur <> nil then begin
      j := slot;
      ok := True;
      while (j < 72) and ok do begin
        Inc(j);
        nxt := GDVars.initQueue[j];
        GDVars.initQueue[j] := cur;
        cur := nxt;
        if nxt = nil then
          ok := False;
      end;
    end;
    p := p^.next;
  end;
end;

{ One creature's turn: dumps the party when debugging, fires its start-of-turn effects, centers the view on it, shows
  its details, and hands it to the AI on quick fight or to the player otherwise.
  @param(cr The creature whose turn it is.) }
procedure CreatureAction(cr: Types.PCharacter);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Integer;
begin
  CharHlp.DebugDumpParty;
  cr^.combatAddr^.flankCount := 0;
  cr^.combatAddr^.flankSpread := 0;
  cr^.combatAddr^.guarding := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.TURN_START, cr);
  if cr^.combatAddr^.initiative > 0 then begin
    if cr^.combatAddr^.initiative = 20 then
      cr^.combatAddr^.initiative := 19;
    GDVars.curChar := cr;
    GDVars.combatGfxOn := Byte((cr^.side = 0) or CbtMap.CombatIconVisible(Pointer(cr), 0));
    CbtMap.DisplayMapViewCentered(Pointer(cr), 2, 1);
    CharHlp.RecalcStats(cr);
    GDVars.combatPanelDirty := 1;
    CharHlp.CombatPrintCreatureInfo(cr);
    FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, cr);
    if cr^.combatAddr^.spellCast = 0 then
      FxEngine.TriggerEffectsWithCondition(21, cr);
    if cr^.combatAddr^.initiative > 0 then
      if cr^.quickfight <> 0 then
        CombatAi.CombatAiControl(Types.PCharacter(cr))
      else
        Combat.ManualControl(cr);
    CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)));
  end;
end;

{ The player's turn for cr. A spell begun last round is finished first. Otherwise the command menu runs until an action
  ends the turn: Move, Aim, Use, Cast, Turn, Guard, Quick, Delay, Bandage, View, Speed, End and, with the editor
  enabled, the victory command. The extended keys are Space (take the whole party off quick fight), Alt-M (toggle quick
  magic), Alt-Q and Alt-A (put everyone on quick fight and give cr its turn again) and Alt-X (the victory command).
  @param(cr The creature whose turn it is.) }
procedure ManualControl(cr: Types.PCharacter);
var
  ch: Char;
  done: Boolean;
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  aimInfo: array[1..4] of Byte;
  aimTgt: Pointer;
  spell: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellTail: Byte;
begin
  if cr^.inPlay <> 0 then begin
    if cr^.combatAddr^.spellCast > 0 then begin
      spell := cr^.combatAddr^.spellCast;
      cr^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spell, 0, 1, done);
      done := CharHlp.EndActions(cr);
    end else begin
      done := False;
      while not done do begin
        GDVars.horizChoice := 1;
        Combat.CombatMenu(cr, ch);
        if not GDVars.menuReturnedKey then
          case ch of
            #0: Combat.MoveMenu(cr, done);
            #1: CbtActs.CombatAimMenu(cr, $FF, 1, 0, 1, done, aimTgt);
            #2: begin
                  GDVars.horizChoice := 2;
                  ViewChar.UseItemMenu(done);
                  CbtActs.RecalcAttacksLeft(cr);
                  if not done then
                    CharHlp.DisplayCombatInterface;
                end;
            #3: CbtActs.CastSpellCombat(0, 0, done);
            #4: begin
                  if (ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.CLERIC) > 0)
                     or (ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.PALADIN) > 2) then
                    if cr^.combatAddr^.turnAttempts < GDVars.undeadCount then begin
                      CbtActs.CombatTurnUndead(cr);
                      done := CharHlp.EndActions(cr);
                    end;
                end;
            #5: done := CharHlp.Guard(cr);
            #6: begin
                  Combat.TurnOnAuto(cr);
                  MenuCore.ClearBottomLine;
                  GameIo.DrainKeys;
                  Delay(200);
                  done := True;
                  CombatAi.CombatAiControl(Types.PCharacter(cr));
                end;
            #7: begin
                  cr^.combatAddr^.initiative := 1;
                  GDVars.scratchIndex := GDVars.initQueueCount;
                  p := GDVars.initQueue[GDVars.scratchIndex + 1];
                  while (p <> nil) and (GDVars.scratchIndex < 72) do begin
                    GDVars.initQueue[GDVars.scratchIndex] := p;
                    Inc(GDVars.scratchIndex);
                    p := GDVars.initQueue[GDVars.scratchIndex + 1];
                  end;
                  GDVars.initQueue[GDVars.scratchIndex] := cr;
                  Dec(GDVars.initQueueCount);
                  done := True;
                end;
            #8: begin
                  done := CharHlp.BandageDying(True);
                  done := CharHlp.EndActions(cr);
                end;
            #9: begin
                  ViewChar.ViewCharMenu(done);
                  CbtActs.RecalcAttacksLeft(cr);
                  if not done then
                    CharHlp.DisplayCombatInterface;
                end;
            #10: Combat.SpeedMenu;
            #11: done := CharHlp.EndActions(cr);
            #12: if CbtActs.VictoryCheat then begin
                   CbtMap.DisplayMapViewCentered(Pointer(cr), 3, 0);
                   done := True
                 end else
                   CharHlp.PrintBottomLine('That doesn''t work');
          end else
          case ch of
            ' ': begin
                   p := GDVars.partyHead;
                   while p <> nil do begin
                     if p^.npc < C_Npc.NON_PLAYER then
                       p^.quickfight := 0;
                     p := p^.next;
                   end;
                 end;
            C_Keys.ALT_M: begin
                    GDVars.quickMagic := Byte(GDVars.quickMagic = 0);
                    if GDVars.quickMagic <> 0 then
                      CharHlp.PrintBottomLine(GDConsts.magicOnText)
                    else
                      CharHlp.PrintBottomLine(GDConsts.magicOffText);
                  end;
            Combat.KEY_ALT_Q, Combat.KEY_ALT_A: begin
                    Dec(GDVars.initQueueCount);
                    cr^.combatAddr^.initiative := 20;
                    p := GDVars.partyHead;
                    while p <> nil do begin
                      Combat.TurnOnAuto(p);
                      p := p^.next;
                    end;
                    MenuCore.ClearBottomLine;
                    Delay(200);
                    done := True;
                  end;
            C_Keys.ALT_X: if CbtActs.VictoryCheat then begin
                    CbtMap.DisplayMapViewCentered(Pointer(cr), 3, 0);
                    done := True;
                  end else
                    CharHlp.PrintBottomLine('That doesn''t work');
          end;
        if not done then begin
          CbtMap.DisplayMapViewCentered(Pointer(cr), 2, 1);
          GDVars.combatPanelDirty := 1;
          CharHlp.CombatPrintCreatureInfo(cr);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(cr);
end;

{ Shows the combat command menu with only the commands cr can use enabled (the victory command with the editor enabled),
  and waits for one, or for one of the extended keys ManualControl handles.
  @param(cr The creature whose commands are offered.)
  @param(ch Receives the command's index, or the extended key.) }
procedure CombatMenu(cr: Types.PCharacter; var ch: Char);
var
  count: Byte;
  i: Byte;
  hasSpell: Boolean;
begin
  count := 0;
  if cr^.combatAddr^.movement > 0 then
    MenuCore.AppendSlot(0, count);
  MenuCore.AppendSlot(1, count);
  if cr^.numberOfItems > 0 then
    MenuCore.AppendSlot(2, count);
  hasSpell := False;
  for i := 0 to 140 do
    if (cr^.memorized[i] and C_Spell.ID_MASK) > 0 then
      hasSpell := True;
  if hasSpell then
    if cr^.combatAddr^.castAllowed <> 0 then
      if GDVars.gameState^.antiMagic = 0 then
        MenuCore.AppendSlot(3, count);
  if (ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.CLERIC) > 0)
     or (ClassCal.EffectiveClassLevel(Pointer(cr), C_Class.PALADIN) > 2) then
    if cr^.combatAddr^.turnAttempts < GDVars.undeadCount then
      MenuCore.AppendSlot(4, count);
  if not (CharHlp.HasRangedWeapon(cr) and not CharHlp.HasThrowableWeapon(cr)) then
    MenuCore.AppendSlot(5, count);
  MenuCore.AppendSlot(6, count);
  MenuCore.AppendSlot(7, count);
  if CharHlp.BandageDying(False) then
    MenuCore.AppendSlot(8, count);
  for i := 9 to 11 do
    MenuCore.AppendSlot(i, count);
  if GDConsts.editorEnabled then
    MenuCore.AppendSlot(12, count);
  repeat
    ch := MenuCore.MenuHorizontal('', GDConsts.combatMenu, 1, 0);
    if GDVars.menuReturnedKey then
      if not (ch in
              [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, ' ', C_Keys.ALT_X, C_Keys.ALT_M]) then
        ch := #255;
  until (Ord(ch) < $D) or
      (GDVars.menuReturnedKey and (ch in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, ' ', C_Keys.ALT_X,
                                            C_Keys.ALT_M]));
  Border.EraseBox(0, 23, 39, 24);
end;

{ Brings into the fight each creature waiting to arrive (statuses 11 to 19) whose round, its status less 10, has come. }
procedure JoinDelayedCombatants;
var
  p: Types.PCharacter;
begin
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.status in [11..19] then
      if p^.status <= GDVars.cbRoundCounter + 10 then
        CombatSt.JoinBattle(p);
    p := p^.next
  end
end;

{ Ends a round: advances the clock, expires cell patches, fires the end-of-round and terrain effects, and lets the dying
  bleed, a dying creature dying outright after ten rounds. The fight is over when a side is empty or the round limit is
  reached; when only the hostiles are gone, the player may choose to continue the battle. A fight that goes on brings in
  the creatures whose arrival round has come.
  @param(done Set when the fight is over; left alone otherwise, unless the player continues the battle.) }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  { incremented, never read }
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cntTail: Byte;
begin
  GameTime.AdvanceTime(1, 1);
  FxEngine.CountDownAreaEffects(0);
  Inc(GDVars.cbRoundCounter);
  CbtActs.UpdateHostileHpPercent;
  p := GDVars.partyHead;
  cnt := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.ROUND_END, p);
    FxEngine.ConsiderTerrainEffects(p, False, True);
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then
        p^.status := C_Status.DEAD_STATUS;
    end;
    Inc(cnt);
    p := p^.next;
  end;
  if CharHlp.BandageDying(False) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.combatMap^.originX + 3, GDVars.combatMap^.originY + 3, $FF, C_Dir.CENTER);
  if (GDVars.sideTally[0] = 0) or (GDVars.sideTally[1] = 0) or (GDVars.cbRoundCounter >= GDVars.cbNewFlag) then
    done := True;
  if (GDVars.sideTally[0] > 0) and (GDVars.sideTally[1] = 0) and (not GDVars.inputAbort) then
    if MenuCore.YesNoMenu(GDConsts.continueText, GDConsts.noChoice) = GDConsts.yesChoice then
      done := False;
  if not done then
    Combat.JoinDelayedCombatants;
end;

{ The player's Move command: each arrow key turns cr and steps it one cell, attacking a creature in the way or offering
  to flee off the map edge. Diagonal steps cost half again as much. Esc puts cr back where it started with its movement
  restored.
  @param(cr The creature moving.)
  @param(done Set when the move ends the creature's turn.) }
procedure MoveMenu(cr: Types.PCharacter; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: Byte;
  startY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  ch: Byte;
  cost: Byte;
  adjSpecial: Byte;

  { Esc: puts the creature back where it started. }
  procedure UndoMove;
  begin
    cr^.combatAddr^.movement := savedMove;
    CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Pointer(cr)));
    done := CbtMap.IsValidCreatureLoc(Pointer(cr), startX, startY, False) = False;
    CbtMap.ScrollView(CbtMap.CombatCellX(Pointer(cr)), CbtMap.CombatCellY(Pointer(cr)), 0, C_Dir.CENTER);
    cr^.combatAddr^.direction := savedDir;
    dir := C_Dir.CENTER;
  end;

begin
  GDVars.arenaClickA := 1;
  savedMove := cr^.combatAddr^.movement;
  savedDir := cr^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(Pointer(cr));
  startY := CbtMap.CombatCellY(Pointer(cr));
  ch := $FF;
  done := False;
  dir := C_Dir.CENTER;
  repeat
    while (ch <> 0) and (ch <> Ord(C_Keys.ESCAPE)) and not done do begin
      MenuCore.ResetMenuSlots(0);
      Border.EraseBox(24, 24, 39, 24);
      if ch = $FF then
        ch := Ord(MenuCore.MenuHorizontal(GDConsts.moveLeftText + CharHlp.Uint8Str(cr^.combatAddr^.movement div 2) +
                                          ' ', GDConsts.doneMenu, 1, 0));
      dir := C_Dir.CENTER;
      if GDVars.menuReturnedKey then
        case ch of
          Ord(C_Keys.ESCAPE): UndoMove;
          Ord(C_Keys.UP): dir := C_Dir.NORTH;
          Ord(C_Keys.PAGE_UP): dir := C_Dir.NORTHEAST;
          Ord(C_Keys.RIGHT): dir := C_Dir.EAST;
          Ord(C_Keys.PAGE_DOWN): dir := C_Dir.SOUTHEAST;
          Ord(C_Keys.DOWN): dir := C_Dir.SOUTH;
          Ord(C_Keys.END_KEY): dir := C_Dir.SOUTHWEST;
          Ord(C_Keys.LEFT): dir := C_Dir.WEST;
          Ord(C_Keys.HOME): dir := C_Dir.NORTHWEST;
        end;
      if dir < C_Dir.CENTER then begin
        CbtMap.SetCreatureFacing(Pointer(cr), dir, 0, 0);
        CbtMap.ProbeDirection(Pointer(cr), dir, Types.PShortInt(@crIdx)^, Types.PShortInt(@terrIdx)^,
                              Types.PShortInt(@adjSpecial)^);
        if crIdx > 0 then
          Combat.MeleeAttack(cr, GDVars.creatureArr[crIdx], done)
        else if terrIdx = 0 then begin
          case MenuCore.YesNoMenu(GDConsts.fleeText, GDConsts.noChoice) of
            0: done := CbtActs.AttemptFlee(cr);
            1: done := False;
          end;
        end else begin
          if Odd(dir) then
            cost := GDConsts.terrain[terrIdx].cost * 3
          else
            cost := GDConsts.terrain[terrIdx].cost * 2;
          if GDConsts.terrain[terrIdx].cost = C_Terr.TERRAIN_IMPASSABLE then
            cost := C_Terr.TERRAIN_IMPASSABLE;
          if cost > cr^.combatAddr^.movement then
            CharHlp.PrintBottomLine(GDConsts.cantGoText)
          else begin
            CbtActs.AttacksOfOpportunity(cr, dir);
            if cr^.inPlay = 0 then
              done := CharHlp.EndActions(cr)
            else begin
              if cr^.combatAddr^.movement > 0 then
                CbtActs.CombatMoveCreature(cr, dir);
              if cr^.inPlay = 0 then
                done := CharHlp.EndActions(cr);
              FxEngine.ConsiderTerrainEffects(cr, False, False);
              if CharHlp.IsHelpless(cr) or (cr^.inPlay = 0) then
                done := CharHlp.EndActions(cr);
            end;
          end;
        end;
      end;
      if (ch <> $1B) or (not GDVars.menuReturnedKey) then
        if GDVars.menuReturnedKey or (ch <> 0) then
          ch := $FF;
    end;
  until (ch <> $FF) or done;
  if cr^.combatAddr^.movement < 2 then
    cr^.combatAddr^.movement := 0;
  GDVars.arenaClickA := 0;
end;

{ att attacks def in melee after stepping into it, unless att holds a missile weapon it cannot swing, or declines to
  attack an ally.
  @param(att The attacker.)
  @param(def The creature stepped into.)
  @param(done Set by the attack when it ends the attacker's turn.) }
procedure MeleeAttack(att, def: Types.PCharacter; var done: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  canAttack: Byte;
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    CbtActs.NoteAttackDirection(att, def);
    CbtActs.MakeAttack(att, def, False, nil, done);
  end;
end;

{ The Speed command: adjusts the game-speed setting, 0 to 9, until Exit. }
procedure SpeedMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  queryLead: Byte;
  query: Types.TStr40;
  count: Byte;
  sel: Byte;
begin
  sel := $FF;
  while sel <> 2 do begin
    query := GDConsts.speedQuery + '(' + CharHlp.Uint8Str(GDVars.gameState^.gameDelay) + ') ';
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
    count := 0;
    if GDVars.gameState^.gameDelay > 0 then
      MenuCore.AppendSlot(0, count);
    if GDVars.gameState^.gameDelay < 9 then
      MenuCore.AppendSlot(1, count);
    MenuCore.AppendSlot(2, count);
    sel := Ord(MenuCore.MenuHorizontal(query, GDConsts.speedMenuItems, 0, 0));
    case sel of
      0: Dec(GDVars.gameState^.gameDelay);
      1: Inc(GDVars.gameState^.gameDelay);
    end;
  end;
end;

{ Puts a creature on quick fight and drops a locked target on its own side.
  @param(cr The creature to hand to the AI.) }
procedure TurnOnAuto(cr: Types.PCharacter);
begin
  cr^.quickfight := 1;
  if (cr^.combatAddr^.other <> nil)
     and (cr^.combatAddr^.other^.side = cr^.side) then
    cr^.combatAddr^.other := nil;
end;

begin
end.
