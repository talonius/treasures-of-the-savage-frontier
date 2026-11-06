{ EclVm -- the ECL script VM. GameLoop, the unit's export, runs the current area's scripts and the map-movement loop;
  CallEclScript fetches opcodes and DispatchEclCommand sends each to its handler. EclMenu holds the VM's operand and
  GBVM helpers.

  The dispatch covers every opcode from $00 to $44; each handler's comment gives its opcode. }
{$O+,F+,S+,R-,V-,B-,I-,A+}
unit EclVm;

interface

{ The export: run the current area's scripts and the map-movement loop until the party is defeated. A duel ends early,
  with its own teardown. }
procedure GameLoop;

{ Load script scriptId (ECL1.DAX) and start it: read its entry points, mark the loop running and the area left, and
  clear the monster-display flags. NEW ECL's second half; the unit init also installs it as finishHook. }
procedure FinishNewEcl;

implementation

uses Types, GDConsts, GDVars, C_Status, C_Class, C_Ecl, C_Ifc, C_Npc,
  Restart, Vault, Temple, PostCbt, Shop, EclMenu, Combat, Explore, SaveLoad, CharGen, ViewChar, GameTime, FxEngine,
  CharHlp, MapCurs, MenuCore, MapView, Portrait, View3D, MapTiles, Music, GameIo, Mouse, Border, Blit, TextRend, Crt,
  Camp;

const
  { the ECL opcodes only this unit names }
  OP_EXIT = $00;
  SUBTRACT = $05;
  DIVIDE = $06;
  APPROACH = $0D;
  OP_RETURN = $13;
  VERTICAL_MENU = $15;
  IF_EQ = $16;
  IF_NE = $17;
  IF_LT = $18;
  IF_GT = $19;
  IF_LE = $1A;
  IF_GE = $1B;
  CLEAR_MONSTERS = $1C;
  WAIT_KEY = $1D;
  YES_NO = $22;
  OP_COMBAT = $24;
  ON_GOTO = $25;
  ON_GOSUB = $26;
  TREASURE = $27;
  HORIZONTAL_MENU = $2B;
  PRINT_RETURN = $33;
  OP_DELAY = $3A;
  CLEAR_BOX = $3D;
  REMOVE_CHARACTER = $3E;

var
  { GDVars.curChar's own offset and segment words }
  curCharHalves: Types.TPtrRec absolute GDVars.curChar;

procedure CallEclScript(startPc: Word); forward;

procedure EclExit; forward;

procedure EclClock; forward;

{ EXIT, opcode $00: ends the script. Restores the character a LOAD CHARACTER replaced, clears the monster flags and the
  picture flag, stops the interpreter, empties the gosub stack and puts the text cursor back at the top of the message
  box. }
procedure EclExit;
var
  nxt: Pointer;
begin
  if GDVars.pendingCharSwap then begin
    GDVars.curChar := Types.PCharacter(Ptr(GDVars.pendingCharHalves.seg, GDVars.pendingCharHalves.ofs));
    GDVars.pendingCharSwap := False;
  end;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
  GDVars.eclPicShown := False;
  GDVars.loopRunning := 1;
  Inc(GDVars.vmBand.eclIp);
  while GDVars.eclStack <> nil do begin
    nxt := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TGosubNode));
    GDVars.eclStack := nxt;
  end;
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  GDVars.hardExitFlag := 0;
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  firstValue: Word;
  secondValue: Word;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.varTypes[1] >= $80) or (GDVars.varTypes[2] >= $80) then
    EclMenu.EclCompareStr(GDVars.gbStrings[1], GDVars.gbStrings[2])
  else begin
    firstValue := EclMenu.GetEclVar(1);
    secondValue := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(firstValue, secondValue);
  end;
end;

{ ADD, SUBTRACT, DIVIDE and MULTIPLY ($04 to $07) <value1> <value2> <address>: stores the result in the third operand.
  SUBTRACT gives the second value minus the first; DIVIDE also leaves the remainder in divRemainder. }
procedure EclArithmetic;
var
  dest: Word;
  secondValue: Word;
  firstValue: Word;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  result: Word;
begin
  EclMenu.LoadEclVars(3);
  firstValue := EclMenu.GetEclVar(1);
  secondValue := EclMenu.GetEclVar(2);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  case GDVars.curOpcode of
    C_Ecl.ADD: result := firstValue + secondValue;
    EclVm.SUBTRACT: result := secondValue - firstValue;
    EclVm.DIVIDE: begin
         result := firstValue div secondValue;
         GDVars.gameState^.divRemainder := Byte(firstValue mod secondValue);
       end;
    C_Ecl.MULTIPLY: result := firstValue * secondValue;
  end;
  EclMenu.WriteGbvm(dest, result, GDVars.varTypes[3]);
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var
  lim: Byte;
  roll: Byte; dest: Word;
begin
  EclMenu.LoadEclVars(2);
  lim := Byte(EclMenu.GetEclVar(1));
  if lim < $FF then Inc(lim);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  roll := Trunc(Random(lim));
  EclMenu.WriteGbvm(dest, roll, GDVars.varTypes[2]);
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var v: Word; dest: Word;
begin
  EclMenu.LoadEclVars(2);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  if GDVars.varTypes[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(dest, v, GDVars.varTypes[2]);
  end else
    EclMenu.WriteGbvmString(dest, GDVars.gbStrings[1]);
end;

{ LOAD CHARACTER, opcode $0A: makes the party member its argument names (low seven bits, counted from 0) the current
  character until the script ends, and sets the not-found flag when there is no such member, clearing it otherwise. }
procedure EclLoadCharacter;
var
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  savedIdx: Byte;
  idx: Byte;
  i: Byte;
begin
  GDVars.pendingCharSwap := True;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := Byte(EclMenu.GetEclVar(1));
  p := GDVars.partyHead;
  idx := idx and $7F;
  if idx > 0 then begin
    while (i < idx) and (p <> nil) do begin
      p := p^.next;
      Inc(i);
    end;
  end;
  if p <> nil then begin
    GDVars.curChar := p;
    GDVars.combatMsgFlag := 0;
  end else
    GDVars.combatMsgFlag := 1;
end;

{ SETUP MONSTER, opcode $0C: takes the monster's sprite, its greatest distance, its picture and the combat direction
  flags from its four arguments, and shows the monster at the nearer of that distance and the clear distance ahead. }
procedure EclSetupMonster;
begin
  EclMenu.LoadEclVars(4);
  GDVars.monsterSprId := Byte(EclMenu.GetEclVar(1));
  GDVars.gameState^.placementLimit := Byte(EclMenu.GetEclVar(2));
  GDVars.monsterPicId := Byte(EclMenu.GetEclVar(3));
  GDVars.hostileFacingMask := Byte(EclMenu.GetEclVar(4));
  GDVars.gameState^.placementDist := EclMenu.MaxMonsterDist(GDVars.partyPos.x, GDVars.partyPos.y,
                                                              GDVars.partyPos.facing);
  if GDVars.gameState^.placementLimit < GDVars.gameState^.placementDist then
    GDVars.gameState^.placementDist := GDVars.gameState^.placementLimit;
  EclMenu.DisplayMonster(GDVars.monsterSprId, GDVars.monsterPicId, GDVars.gameState^.placementDist,
                         GDVars.monsterFlags);
end;

{ LOAD MONSTER, opcode $0B: appends the monster its first argument names to the party list, with the icon for the
  picture in its third, then clones of it up to the count in its second; each clone deep-copies the first's item and
  effect lists, which come out reversed. }
procedure EclLoadMonster;
var
  monId: Byte;
  countReq: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharacter;
  clone: Types.PCharacter;
  cr: Types.PCharacter;
  savedCurChar: Types.PCharacter;
  inv: Pointer;
  savedItems: Types.PItem;
  savedInv: Pointer;
  eff: Pointer;
  savedEffN: Types.PEffect;
  savedEff: Pointer;
begin
  Portrait.FreeAnimation;
  Blit.FreePic(Types.PImage(GDConsts.extraPictureA));
  Blit.FreePic(Types.PImage(GDVars.bigPicture));
  Blit.FreePic(Types.PImage(GDVars.backdropImage));
  Blit.FreePic(Types.PImage(GDVars.skyImage));
  Blit.FreePic(Types.PImage(GDVars.banks[0]));
  Blit.FreePic(Types.PImage(GDVars.banks[1]));
  Blit.FreePic(Types.PImage(GDVars.banks[2]));
  savedCurChar := GDVars.curChar;
  i := 1;
  EclMenu.LoadEclVars(3);
  if GDVars.cloneCount2 < 48 then begin
    p := nil;
    clone := nil;
    monId := Byte(EclMenu.GetEclVar(1));
    EclMenu.InitCreature(monId, Pointer(cr), inv, eff);
    if cr^.side = 1 then begin
      if (GDVars.gameState^.gameLevel > 0) and (GDVars.gameState^.gameLevel < 6) then begin
        cr^.hpCur := Byte((Word(cr^.hpCur) * (GDVars.gameState^.gameLevel + 1)) div 4);
        cr^.hpMax := Byte((Word(cr^.hpMax) * (GDVars.gameState^.gameLevel + 1)) div 4);
        if (cr^.hpCur = 0) or (cr^.hpMax = 0) then begin
          cr^.hpCur := 1;
          cr^.hpMax := 1;
        end;
      end;
    end;
    if cr^.levelUndead <> 0 then Inc(GDVars.undeadCount);
    savedInv := inv;
    savedEff := eff;
    countReq := Byte(EclMenu.GetEclVar(2));
    if countReq <= 0 then countReq := 1;
    picId := Byte(EclMenu.GetEclVar(3));
    p := GDVars.partyHead;
    cr^.icon := MapTiles.FindMonsterIcon(picId);
    if (cr^.status = C_Status.OKAY) and (GDVars.gameState^.monsterLoadStatus <> 0) then begin
      if GDVars.gameState^.monsterLoadStatus > 9 then
        cr^.status := 19
      else
        cr^.status := GDVars.gameState^.monsterLoadStatus + 10;
      cr^.inPlay := 0;
    end;
    while p^.next <> nil do p := p^.next;
    p^.next := cr;
    p := p^.next;
    p^.next := nil;
    Inc(GDVars.cloneCount2);
    Inc(i);
    while (i <= countReq) and (GDVars.cloneCount2 < 63) do begin
      GetMem(clone, SizeOf(Types.TCharacter));
      if clone = nil then GDVars.fatalMessageHook('Out of ram');
      p^.next := clone;
      p := p^.next;
      p^ := cr^;
      p^.next := nil;
      p^.effects := nil;
      p^.items := nil;
      Inc(i);
      Inc(GDVars.cloneCount2);
      while inv <> nil do begin
        if p^.items = nil then begin
          GetMem(p^.items, SizeOf(Types.TItem));
          if p^.items = nil then GDVars.fatalMessageHook('Out of ram');
          Types.PItem(p^.items)^ := Types.PItem(inv)^;
          Types.PItem(p^.items)^.next := nil;
        end else begin
          savedItems := p^.items;
          GetMem(p^.items, SizeOf(Types.TItem));
          if p^.items = nil then GDVars.fatalMessageHook('Out of ram');
          Types.PItem(p^.items)^ := Types.PItem(inv)^;
          Types.PItem(p^.items)^.next := savedItems;
        end;
        inv := Types.PItem(inv)^.next;
      end;
      inv := savedInv;
      while eff <> nil do begin
        if p^.effects = nil then begin
          GetMem(p^.effects, SizeOf(Types.TEffect));
          if p^.effects = nil then GDVars.fatalMessageHook('Out of ram');
          Types.PEffect(p^.effects)^ := Types.PEffect(eff)^;
          Types.PEffect(p^.effects)^.next := nil;
        end else begin
          savedEffN := p^.effects;
          GetMem(p^.effects, SizeOf(Types.TEffect));
          if p^.effects = nil then GDVars.fatalMessageHook('Out of ram');
          Types.PEffect(p^.effects)^ := Types.PEffect(eff)^;
          Types.PEffect(p^.effects)^.next := savedEffN;
        end;
        eff := Types.PEffect(eff)^.next;
      end;
      eff := savedEff;
    end;
    GDVars.wallDirty[0] := 1;
    GDVars.curChar := savedCurChar;
  end;
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.gameState^.placementDist > 0 then begin
    Dec(GDVars.gameState^.placementDist);
    EclMenu.DisplayMonster(GDVars.monsterSprId, GDVars.monsterPicId, GDVars.gameState^.placementDist,
                           GDVars.monsterFlags);
  end;
  Inc(GDVars.vmBand.eclIp);
end;

{ PICTURE's body: $FE clears the picture, $FF restores the view, $F0 and up draw a full backdrop, anything else a 'PIC'
  image.
  @param(pictureId The picture: $FE clears it, $FF restores the view, 240 and up is a full backdrop.) }
procedure ShowPicture(pictureId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  loadedPicture: LongInt;
begin
  if pictureId = $FE then begin
    Portrait.FreeAnimation;
    Border.BlankBox(3, 3, 13, 13);
    GDVars.monsterFlags[0] := False;
    GDVars.monsterFlags[1] := False;
    GDVars.eclPicShown := True;
  end else if pictureId <> $FF then begin
    GDVars.palettePending := 1;
    GDVars.monsterFlags[1] := True;
    GDVars.eclPicShown := True;
    if pictureId >= 240 then begin
      if (GDVars.gameState^.layoutFlag = 1) and (GDVars.gameState^.location = 0) then begin
        Blit.FreePic(Types.PImage(GDVars.skyImage));
        Blit.FreePic(Types.PImage(GDVars.backdropImage));
        GameIo.ZeroFill(GDVars.backdropImage, 8);
        GDVars.currentSkyId := 0;
      end;
      Portrait.LoadBigPic(pictureId);
      Portrait.DisplayBigPic;
      GDVars.palettePending := 1;
      if GDVars.locState.current = C_Ifc.AREA_MAP then
        MapCurs.DrawCursor
      else
        GDVars.partyShown := 1;
      GDVars.pendingRefresh := 0;
    end else begin
      Portrait.LoadAnimation('PIC', pictureId, 0);
      Portrait.DisplayImageBuf(3, 3, True, 0);
      GDVars.palettePending := 1;
    end;
  end else begin
    if (GDVars.locState.previous <> C_Ifc.DUNGEON) or (GDVars.locState.current = C_Ifc.DUNGEON) then begin
      if (GDVars.eclPicShown) or (GDVars.sprShown <> 0) then begin
        GDVars.palettePresetOn := 0;
        GDVars.palettePending := 1;
        GDVars.pendingRefresh := 1;
        MapView.DisplayMapView;
        GDVars.eclPicShown := False;
        GDVars.sprShown := 0;
      end;
    end;
    GDVars.monsterFlags[0] := False;
    GDVars.monsterFlags[1] := False;
  end;
end;

{ PICTURE, opcode $0E: shows the picture its argument names. }
procedure EclPicture;
begin
  EclMenu.LoadEclVars(1);
  EclVm.ShowPicture(Byte(EclMenu.GetEclVar(1)));
end;

{ Opcode $0F, INPUT NUMBER: prompts in light green for a number, limited by its first operand, and stores it at the
  operand address. }
procedure EclInputNumber;
var result: Word; dest: Word; maxDigits: Word;
begin
  EclMenu.LoadEclVars(2);
  maxDigits := EclMenu.GetEclVar(1);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  result := TextRend.ReadNumber('', LightGreen, Black, maxDigits);
  EclMenu.WriteGbvm(dest, result, GDVars.varTypes[2]);
end;

{ INPUT STRING, opcode $10: reads a line from the player, up to the length in its first argument, into the address in
  its second; an empty line is stored as a single space. }
procedure EclInputString;
var dest: Word; s: String[40]; maxLen: Word;
begin
  EclMenu.LoadEclVars(2);
  maxLen := EclMenu.GetEclVar(1);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  s := TextRend.ReadString('', LightGreen, Black, maxLen);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(dest, s);
end;

{ PRINT and PRINT CLEAR, opcodes $11 and $12: prints its argument, a string or a number, in the message box in the
  area's print color; PRINT CLEAR first clears the box and starts at its top. }
procedure EclPrint;
var idx: Byte;
begin
  idx := GDVars.gameState^.printColor;
  if (idx > 15) or (idx = 0) then idx := 10;
  EclMenu.LoadEclVars(1);
  GDVars.bottomCleared := 0;
  GDVars.msgDelayFlag := 1;
  if GDVars.varTypes[1] < $80 then
    GDVars.gbStrings[1] := CharHlp.Uint16Str(EclMenu.GetEclVar(1));
  if GDVars.curOpcode = C_Ecl.PRINT then
    TextRend.DisplayMessageWindow(1, 25, 38, 29, idx, Black, False, GDVars.gbStrings[1])
  else begin
    GDVars.curRow := 17;
    GDVars.curCol := 1;
    TextRend.DisplayMessageWindow(1, 25, 38, 29, idx, Black, True, GDVars.gbStrings[1]);
  end;
  GDVars.msgDelayFlag := 0;
end;

{ RETURN, opcode $13: pops the gosub stack and returns to its address, or ends the script like EXIT when the stack is
  empty. }
procedure EclReturn;
var nxt: Pointer;
begin
  Inc(GDVars.vmBand.eclIp);
  if GDVars.eclStack <> nil then begin
    GDVars.vmBand.eclIp := GDVars.eclStack^.ip;
    nxt := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(Types.TGosubNode));
    GDVars.eclStack := nxt;
  end else
    EclVm.EclExit;
end;

{ COMPARE AND ($14) <value1> <value2> <value3> <value4>: sets the equal flag when the first value equals the second and
  the third equals the fourth, and the not-equal flag otherwise. }
procedure EclCompareAnd;
var
  eq1: Boolean;
  eq2: Boolean;
begin
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  EclMenu.LoadEclVars(4);
  if GDVars.varTypes[1] >= $80 then begin
    eq1 := (GDVars.gbStrings[1] = GDVars.gbStrings[2]);
    if GDVars.varTypes[3] >= $80 then
      eq2 := (GDVars.gbStrings[3] = GDVars.gbStrings[4])
    else
      eq2 := (EclMenu.GetEclVar(3) = EclMenu.GetEclVar(4));
  end else begin
    eq1 := (EclMenu.GetEclVar(1) = EclMenu.GetEclVar(2));
    if GDVars.varTypes[3] >= $80 then
      { Note: this compares the first pair of strings again, not the second. }
      eq2 := (GDVars.gbStrings[1] = GDVars.gbStrings[2])
    else
      eq2 := (EclMenu.GetEclVar(3) = EclMenu.GetEclVar(4));
  end;
  if eq1 and eq2 then
    GDVars.compareFlags[1] := 1
  else
    GDVars.compareFlags[2] := 1;
end;

{ The six IF opcodes ($16 to $1B): skip the next command unless the comparison flag for this test is set. }
procedure EclIf;
begin
  Inc(GDVars.vmBand.eclIp);
  if GDVars.compareFlags[GDVars.curOpcode - $15] = 0 then
    EclMenu.SkipEclCmd;
end;

procedure FinishNewEcl;
begin
  EclMenu.LoadEclScript(GDVars.environmentId);
  EclMenu.EclInit;
  GDVars.loopRunning := 1;
  GDVars.areaExitFlag := True;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
end;

{ NEW ECL, opcode $20: records the running script as the one to return to and switches to the script its argument
  names. }
procedure EclNewEcl;
var newId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.gameState^.areaScriptId := GDVars.environmentId;
  newId := Byte(EclMenu.GetEclVar(1));
  GDVars.environmentId := newId;
  EclVm.FinishNewEcl;
end;

{ LOAD FILES, opcode $21: loads the map its first argument names (below $7F, indoors only) and the wall set its second
  names, unless that is $FF or already loaded, then redraws the frame when coming from the overland map. }
procedure EclLoadFiles;
var
  mapId: Byte;
  suppress: Byte;
  { Unused in this version; see the other implementations of this routine. }
  thirdOperand: Byte;
begin
  EclMenu.LoadEclVars(2);
  mapId := Byte(EclMenu.GetEclVar(1));
  suppress := Byte(EclMenu.GetEclVar(2));
  if (mapId < $7F) and (GDVars.gameState^.location <> 0) then begin
    GDVars.gameState^.currentMap := mapId;
    View3D.Load3DMap(mapId);
    GDVars.gameState^.movementState := 0;
  end;
  if (suppress <> $FF) and (suppress <> GDVars.wallSetCache[1].wallDefId) then begin
    GDVars.wallSetCache[2].wallDefId := 0;
    GDVars.wallSetCache[3].wallDefId := 0;
    Blit.FreePic(Types.PImage(GDVars.banks[2]));
    Blit.FreePic(Types.PImage(GDVars.banks[1]));
    Blit.FreePic(Types.PImage(GDVars.bigPicture));
    GDVars.bigPicId := 0;
    View3D.LoadWallSet(suppress, 0);
  end;
  if (GDVars.locState.previous = C_Ifc.AREA_MAP) and (GDVars.locState.current <> C_Ifc.AREA_MAP) and
      (GDVars.mapDirtyFlag <> 0) then begin
    Border.DrawExploreFrame;
    CharHlp.DisplayParty(GDVars.curChar);
    CharHlp.PrintPositionAndTime;
    GDVars.mapDirtyFlag := 0;
  end;
end;

{ Opcode $42, LOAD FILES with three wall sets: loads the map its first argument names (below $7F, indoors only) and the
  wall sets its other three name, freeing a slot whose set is 0 or $FF, then redraws the frame when coming from the
  overland map. }
procedure EclLoadWallSets;
var
  i: Byte;
  mapId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mapIdTail: array[0..3] of Byte;
  files: array[0..2] of Byte;
begin
  EclMenu.LoadEclVars(4);
  mapId := Byte(EclMenu.GetEclVar(1));
  files[0] := Byte(EclMenu.GetEclVar(2));
  files[1] := Byte(EclMenu.GetEclVar(3));
  files[2] := Byte(EclMenu.GetEclVar(4));
  if (mapId < $7F) and (GDVars.gameState^.location <> 0) then begin
    GDVars.gameState^.currentMap := mapId;
    View3D.Load3DMap(mapId);
    GDVars.gameState^.movementState := 0;
  end;
  for i := 0 to 2 do begin
    if (files[i] = $FF) or (files[i] = 0) then begin
      Blit.FreePic(Types.PImage(GDVars.banks[i]));
      GDVars.wallSetCache[i + 1].wallDefId := 0;
    end else begin
      Blit.FreePic(Types.PImage(GDVars.bigPicture));
      GDVars.bigPicId := 0;
      View3D.LoadWallSet(files[i], i);
    end;
  end;
  if (GDVars.locState.previous = C_Ifc.AREA_MAP) and (GDVars.locState.current <> C_Ifc.AREA_MAP) and
      (GDVars.mapDirtyFlag <> 0) then begin
    Border.DrawExploreFrame;
    CharHlp.DisplayParty(GDVars.curChar);
    CharHlp.PrintPositionAndTime;
    GDVars.mapDirtyFlag := 0;
  end;
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var
  dest: Word;
  secondValue: Word;
  firstValue: Word; result: Byte;
begin
  EclMenu.LoadEclVars(3);
  firstValue := EclMenu.GetEclVar(1);
  secondValue := EclMenu.GetEclVar(2);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  if GDVars.curOpcode = C_Ecl.OP_AND then
    result := Byte(firstValue and secondValue)
  else
    result := Byte(firstValue or secondValue);
  EclMenu.EclCompareInt(0, result);
  EclMenu.WriteGbvm(dest, result, GDVars.varTypes[3]);
end;

{ GET TABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var
  base: Word;
  dest: Word;
  address: Word;
  v: Word; idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  base := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  idx := Byte(EclMenu.GetEclVar(2));
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  address := base + idx;
  v := EclMenu.ReadGbvm(address, GDVars.varTypes[3]);
  EclMenu.WriteGbvm(dest, v, GDVars.varTypes[3]);
end;

{ SAVE TABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var
  idx: Word;
  base: Word;
  value: Word;
  address: Word;
begin
  EclMenu.LoadEclVars(3);
  value := EclMenu.GetEclVar(1);
  base := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  idx := EclMenu.GetEclVar(3);
  address := base + idx;
  EclMenu.WriteGbvm(address, value, GDVars.varTypes[1]);
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  idx: Byte;
  query: String;
  list: Pointer;
  savedList: Pointer;
  outIdx: Integer;
  redraw: Boolean;
  dest: Word; kind: Byte;
  { list's own words, passed as the row arguments }
  listHalves: Types.TPtrRec absolute list;
begin
  GDVars.horizChoice := 1;
  GDVars.bottomCleared := 0;
  redraw := True;
  idx := 1;
  EclMenu.LoadEclVars(3);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  kind := GDVars.varTypes[1];
  query := GDVars.gbStrings[1];
  count := Byte(EclMenu.GetEclVar(3));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  savedList := list;
  GDVars.curCol := 1;
  GDVars.curRow := 17;
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, query);
  while list <> nil do begin
    Types.PItemRec(list)^.name := GDVars.gbStrings[idx];
    Types.PItemRec(list)^.inUse := 0;
    list := Types.PItemRec(list)^.next;
    Inc(idx);
  end;
  list := savedList;
  outIdx := 0;
  EclMenu.EclVerticalMenu('', '', 1, GDVars.curRow + 1, 38, 22, listHalves.seg, listHalves.ofs, 0, redraw, outIdx,
                          list);
  EclMenu.WriteGbvm(dest, Word(outIdx), kind);
  MenuCore.FreeStringList(list);
  Border.EraseBox(1, 17, 38, 22);
end;

{ HORIZONTAL MENU, opcode $2B, and opcode $31: offers the options that follow across the bottom line and stores the
  chosen index at the address operand.
  @param(showMenu True for opcode $31, which first asks 'what do you do?'.) }
procedure EclHMenu(showMenu: Boolean);
var
  count: Byte;
  result: Byte;
  i: Byte;
  opts: String[80];
  dest: Word;
  kind: Byte;
begin
  if showMenu then
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, False, 'what do you do?');
  GDVars.horizChoice := 1;
  opts := '';
  EclMenu.LoadEclVars(2);
  dest := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  kind := GDVars.varTypes[1];
  count := Byte(EclMenu.GetEclVar(2));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(count);
  opts := '';
  for i := 1 to count - 1 do
    opts := opts + '~' + GDVars.gbStrings[i] + ' ';
  opts := opts + '~' + GDVars.gbStrings[count];
  result := EclMenu.MenuHorizontalCharacterSelect('', opts, False, Byte(GDVars.eclPicShown));
  EclMenu.WriteGbvm(dest, result, kind);
  Border.EraseBox(0, 24, 39, 24);
end;

{ CLEAR MONSTERS ($1C): clears the encounter. }
procedure EclClearMonsters;
begin
  Inc(GDVars.vmBand.eclIp);
  CharHlp.ClearEncounterState;
end;

{ CHECK PARTY ($1E): reads its six operands and does nothing with them; the check is not used in this game. }
procedure EclCheckParty;
var
  { Unused in this version; see the other implementations of this routine. }
  v: Word;
  { Unused in this version; see the other implementations of this routine. }
  sum: Word;
  { Unused in this version; see the other implementations of this routine. }
  effectId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  found: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partyTotals: array[0..6] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  maxValue: Byte;
  { Unused in this version; see the other implementations of this routine. }
  minValue: Byte;
  { Unused in this version; see the other implementations of this routine. }
  addr1: Word;
  { Unused in this version; see the other implementations of this routine. }
  addr2: Word;
  { Unused in this version; see the other implementations of this routine. }
  addr3: Word;
  { Unused in this version; see the other implementations of this routine. }
  addr4: Word;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
begin
  EclMenu.LoadEclVars(6);
  p := GDVars.partyHead;
  found := 0;
  if GDVars.varTypes[1] = 1 then
    v := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1])
  else
    v := Word(EclMenu.GetEclVar(1));
  effectId := Byte(EclMenu.GetEclVar(2));
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  addr3 := EclMenu.CombineBytesToWord(GDVars.varLo[5], GDVars.varHi[5]);
  addr4 := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  sum := 0;
  count := 0;
  minValue := $FF;
  maxValue := 0;
end;

{ COMBAT, opcode $24: with no monster loaded, opens the vault or the healer when a script asked for one, else runs
  PostCbt.PostCombat; otherwise runs the encounter (Combat.CombatMain, unless combat is disabled) and its aftermath. }
procedure EclCombat;
var maxDist: Word; launch: Boolean; savedSave: Byte;
begin
  GDVars.partyShown := 0;
  savedSave := GDVars.isMoveMode;
  GDVars.isMoveMode := 0;
  Inc(GDVars.vmBand.eclIp);
  launch := True;
  GDVars.palettePending := 1;
  if GDVars.wallDirty[0] = 0 then begin
    if GDVars.gameState^.vaultRequest = 1 then begin
      GDVars.gameState^.vaultRequest := 0;
      Vault.PoolVault;
    end else if GDVars.gameState^.healerRequest = 1 then begin
      Temple.TempleMainMenu;
      GDVars.gameState^.healerRequest := 0;
      if GDVars.gameState^.location = 0 then launch := False;
    end else
      PostCbt.PostCombat;
  end else begin
    Portrait.FreeAnimation;
    maxDist := EclMenu.MaxMonsterDist(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
    if GDVars.gameState^.placementDist > maxDist then GDVars.gameState^.placementDist := maxDist;
    if GDConsts.combatDisabled = 0 then Combat.CombatMain;
    PostCbt.PostCombat;
    GameIo.RebuildLists;
    EclMenu.LoadEclScript(GDVars.environmentId);
    Border.LoadBorderBackdrop;
    if GDVars.gameState^.location = 0 then
      Portrait.LoadBigPic(GDConsts.areaPictureIds[GDVars.gameState^.pictureIndex]);
  end;
  if GDVars.gameState^.location = 0 then
    GDVars.locState.current := C_Ifc.AREA_MAP
  else
    GDVars.locState.current := C_Ifc.DUNGEON;
  GDVars.gameState^.searchFlags := GDVars.gameState^.searchFlags and 1;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
  GDVars.eclPicShown := False;
  if launch then begin
    CharHlp.DisplayNoncombatInterface;
    if (GDVars.gameState^.location = 0) and (not GDVars.partyDefeated) and (GDVars.gameState^.layoutFlag = 1) then
      MapCurs.DrawCursor;
  end;
  GDVars.isMoveMode := savedSave;
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var
  selector: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  matched: Boolean;
begin
  matched := False;
  EclMenu.LoadEclVars(2);
  selector := Byte(EclMenu.GetEclVar(1));
  count := Byte(EclMenu.GetEclVar(2));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (not matched) do begin
    if selector = i then begin
      if GDVars.curOpcode = EclVm.ON_GOTO then
        GDVars.vmBand.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[i + 1], GDVars.varHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      matched := True;
    end else
      Inc(i);
  end;
end;

{ TREASURE, opcode $27: adds its first three arguments to the pooled coins and prepends a treasure node for each item of
  the list whose length its fourth gives. Item $FF is a random scroll from EclMenu.EclBuildRandomScroll; an item whose
  definition's type is $FF is skipped. }
procedure EclTreasure;
var
  treasureId: Byte;
  i: Byte;
  itemId: Byte;
  rawBuf: Types.TItemDef;
  node: Types.TItem;
  savedHead: Pointer;
begin
  EclMenu.LoadEclVars(4);
  Inc(GDVars.pooledMoney[0], EclMenu.GetEclVar(1));
  Inc(GDVars.pooledMoney[1], EclMenu.GetEclVar(2));
  Inc(GDVars.pooledMoney[2], EclMenu.GetEclVar(3));
  treasureId := Byte(EclMenu.GetEclVar(4));
  Dec(GDVars.vmBand.eclIp);
  EclMenu.LoadEclVars(treasureId);
  for i := 1 to treasureId do begin
    itemId := Byte(EclMenu.GetEclVar(i));
    if (itemId = $FF) or (GDVars.itemDefs^[itemId].itemType <> $FF) then begin
      if itemId = $FF then begin
        EclMenu.EclBuildRandomScroll(rawBuf);
        Move(rawBuf, node.itemType, SizeOf(rawBuf));
      end else
        Move(GDVars.itemDefs^[itemId], node.itemType, SizeOf(Types.TItemDef));
      node.next := nil;
      node.inUse := 0;
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        if GDVars.treasureItems = nil then GDVars.fatalMessageHook('Out of ram');
        GDVars.treasureItems^ := node;
      end else begin
        savedHead := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        if GDVars.treasureItems = nil then GDVars.fatalMessageHook('Out of ram');
        GDVars.treasureItems^ := node;
        GDVars.treasureItems^.next := savedHead;
      end;
    end;
  end;
end;

{ ROB, opcode $28: takes the percentage of money in its second argument and, with the chance in its third, items from
  the current character, or from every member when its first is non-zero. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  inv: Pointer;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := Byte(EclMenu.GetEclVar(1));
  pct := Byte(EclMenu.GetEclVar(2));
  fraction := (100 - pct) / 100;
  chance := Byte(EclMenu.GetEclVar(3));
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.curChar);
    EclMenu.RobItems(chance, GDVars.curChar);
  end else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      inv := p^.items;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      p := p^.next;
    end;
  end;
end;

{ Offers the continue menu and waits. }
procedure EclContinuePrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  result: Byte;
begin
  Inc(GDVars.vmBand.eclIp);
  result := EclMenu.MenuHorizontalCharacterSelect('', GDConsts.tildePressButtonPrompt, True,
                                                  Byte(GDVars.eclPicShown));
  MenuCore.ClearBottomLine;
end;

{ YES NO, opcode $22: asks a yes or no question; yes sets the equal flag, no the not-equal flag. }
procedure EclYesNo;
var
  { Unused in this version; see the other implementations of this routine. }
  answer: Word;
begin
  Inc(GDVars.vmBand.eclIp);
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  if MenuCore.YesNoMenu(GDConsts.emptyQuery, GDConsts.yesChoice) = GDConsts.yesChoice then
    GDVars.compareFlags[1] := 1
  else
    GDVars.compareFlags[2] := 1;
  MenuCore.ClearBottomLine;
end;

{ FIND ITEM ($32) <item type>: sets the equal flag if anyone in the party carries an item of that type, and the
  not-equal flag otherwise. }
procedure EclFindItem;
var
  itemId: Byte;
  p: Types.PCharacter;
  it: Types.PItem;
  found: Boolean;
begin
  EclMenu.LoadEclVars(1);
  found := False;
  itemId := Byte(EclMenu.GetEclVar(1));
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  GDVars.compareFlags[2] := 1;
  p := GDVars.partyHead;
  while (p <> nil) and (not found) do begin
    it := Types.PItem(p^.items);
    while (it <> nil) and (not found) do begin
      if itemId = it^.itemType then begin
        GDVars.compareFlags[1] := 1;
        GDVars.compareFlags[2] := 0;
        found := True;
      end;
      it := it^.next;
    end;
    p := p^.next;
  end;
end;

{ The item-filter predicate shared by opcodes $43 and $44.
  @param(a The name parts to match.)
  @param(b An item's name parts.)
  @returns(True when all three are equal.) }
function ItemMatches(a, b: Types.TNameIds): Boolean;
var i: Byte;
begin
  ItemMatches := False;
  for i := 1 to 3 do
    if a[i] <> b[i] then
      Exit;
  ItemMatches := True;
end;

{ FIND ITEM <itemID> <part3> <part2> <part1>: scans each party member's inventory for an item of that id (0: any) whose
  three name parts match (ItemMatches; <part3> 0: any). All compare flags are cleared first; a hit sets the equal flag,
  otherwise the not-equal flag is set. }
procedure EclFindMatchingItem;
var
  target: Byte;
  p: Types.PCharacter;
  item: Types.PItem;
  match: Types.TNameIds;
begin
  EclMenu.LoadEclVars(4);
  target := Byte(EclMenu.GetEclVar(1));
  match[3] := Byte(EclMenu.GetEclVar(2));
  match[2] := Byte(EclMenu.GetEclVar(3));
  match[1] := Byte(EclMenu.GetEclVar(4));
  FillChar(GDVars.compareFlags, SizeOf(GDVars.compareFlags), 0);
  GDVars.compareFlags[2] := 1;
  p := GDVars.partyHead;
  while p <> nil do begin
    item := p^.items;
    while item <> nil do begin
      if ((target = 0) or (target = item^.itemType)) and
          ((match[3] = 0) or EclVm.ItemMatches(match, item^.nameIds)) then begin
        GDVars.compareFlags[1] := 1;
        GDVars.compareFlags[2] := 0;
        Exit;
      end;
      item := item^.next;
    end;
    p := p^.next;
  end;
end;

{ DELAY, opcode $3A: pauses for 600 milliseconds; in a duel a pressed key stops the interpreter. }
procedure EclDelay;
var
  { Unused in this version; see the other implementations of this routine. }
  delayTime: Word;
begin
  MenuCore.ClearBottomLine;
  Inc(GDVars.vmBand.eclIp);
  Delay(600);
  if (GDVars.inputAbort) and KeyPressed then begin
    GameIo.DrainKeys;
    GDVars.loopRunning := 1;
  end;
end;

{ DAMAGE ($2E) <attack> <dice> <sides> <bonus> <value>: rolls dice x sides + bonus of damage. With attack bit $80 set,
  the low four bits of attack are the saving-throw modifier and the low three bits of value the save type: bit $40 hits
  the whole party (bit $20 with no save), otherwise one target, the current character when value bit $80 is set (save
  type value - 1, none at 0) or else a random member. A made save halves the damage when attack bit $10 is set and
  cancels it when it is not. With bit $80 clear, attack is a number of separate attacks on random members, each rolled
  to hit against value and each with fresh damage. If that leaves the whole party out of play, the party is lost. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  thac0Arg: Byte;
  varIdx: Byte;
  bonus: Byte;
  rollResult: Byte;
  saveArg: Byte;
  j: Byte;
  dmg: Word;
  p: Types.PCharacter;
  scanCursor: Types.PCharacter;
  savedChar: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  flag1a: Boolean;
  flagA: Byte;
begin
  savedChar := GDVars.curChar;
  damageType := 0;
  flag1a := False;
  p := GDVars.partyHead;
  EclMenu.LoadEclVars(5);
  attack := Byte(EclMenu.GetEclVar(1));
  dice := Byte(EclMenu.GetEclVar(2));
  sides := Byte(EclMenu.GetEclVar(3));
  bonus := Byte(EclMenu.GetEclVar(4));
  varIdx := Byte(EclMenu.GetEclVar(5));
  dmg := Word(FxEngine.RollDice(dice, sides)) + bonus;
  flagA := attack and $10;
  if (attack and $40) <> 0 then
    flag1a := True
  else
    rollResult := FxEngine.RollDice(1, GDVars.gameState^.partySize);
  if (attack and $80) <> 0 then begin
    thac0Arg := attack and $F;
    saveArg := varIdx and $7;
    if flag1a then begin
      while p <> nil do begin
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else begin
          if not Boolean(FxEngine.RollSavingThrow(p, saveArg, thac0Arg)) then
            EclMenu.EclInflictDamage(dmg, p)
          else if flagA <> 0 then
            EclMenu.EclInflictDamage(dmg div 2, p);
        end;
        p := p^.next;
      end;
    end else begin
      if (varIdx and $80) <> 0 then begin
        if (saveArg = 0) or (not Boolean(FxEngine.RollSavingThrow(GDVars.curChar, saveArg - 1, thac0Arg))) then
          EclMenu.EclInflictDamage(dmg, GDVars.curChar)
        else if flagA <> 0 then
          EclMenu.EclInflictDamage(dmg div 2, GDVars.curChar);
      end else begin
        for i := 2 to rollResult do
          p := p^.next;
        if not Boolean(FxEngine.RollSavingThrow(p, saveArg, thac0Arg)) then
          EclMenu.EclInflictDamage(dmg, p)
        else if flagA <> 0 then
          EclMenu.EclInflictDamage(dmg div 2, p);
      end;
    end;
  end else begin
    for i := 1 to attack do begin
        p := GDVars.partyHead;
        rollResult := FxEngine.RollDice(1, GDVars.gameState^.partySize);
        j := 1;
        while j < rollResult do begin
          p := p^.next;
          Inc(j);
        end;
        if Boolean(FxEngine.AttackRollNoAttacker(p, varIdx)) then
          EclMenu.EclInflictDamage(dmg, p);
        dmg := Word(FxEngine.RollDice(dice, sides)) + bonus;
    end;
  end;
  scanCursor := GDVars.partyHead;
  GDVars.partyDefeated := True;
  while scanCursor <> nil do begin
    if scanCursor^.inPlay <> 0 then GDVars.partyDefeated := False;
    scanCursor := scanCursor^.next;
  end;
  if GDVars.partyDefeated then begin
    Border.DrawWindowFrame(0);
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, Black, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.curChar := savedChar;
  TextRend.PauseContinue;
end;

{ CLOCK, opcode $34: advances the game time by the hours and minutes in its two arguments and redraws the status line. }
procedure EclClock;
var
  hours: Byte;
  minutes: Byte;
begin
  EclMenu.LoadEclVars(2);
  hours := Byte(EclMenu.GetEclVar(1));
  minutes := Byte(EclMenu.GetEclVar(2));
  GameTime.AdvanceTime(hours, minutes);
  CharHlp.PrintPositionAndTime;
end;

{ Opcode $33, PRINT RETURN: moves the text cursor to column 1 of the next line and clears the pending-return flag. }
procedure EclPrintReturn;
begin
  Inc(GDVars.vmBand.eclIp);
  if GDVars.msgLineFlag <> 0 then begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
    GDVars.msgLineFlag := 0;
  end else begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
  end;
end;

{ CLEAR BOX ($3D): redraws the screen frame, the party list and the status line. }
procedure EclClearBox;
begin
  Inc(GDVars.vmBand.eclIp);
  GDVars.partyShown := 0;
  Border.DrawExploreFrame;
  CharHlp.DisplayParty(GDVars.curChar);
  CharHlp.PrintPositionAndTime;
  CharHlp.PrintPositionAndTime;
  GDVars.mapDirtyFlag := 0;
  GDVars.hardExitFlag := 1;
end;

{ WHO, opcode $39: asks the player to pick a party member, with its argument as the prompt, and makes that member
  current. }
procedure EclWho;
var query: String; saved: Byte;
begin
  saved := GDVars.isMoveMode;
  GDVars.isMoveMode := 0;
  GDVars.combatMsgFlag := 0;
  EclMenu.LoadEclVars(1);
  query := GDVars.gbStrings[1];
  CharHlp.SelectChar(query, False, 0, GDVars.curChar);
  GDVars.isMoveMode := saved;
end;

{ ADD NPC, opcode $36: adds the monster its first argument names to the party as a non-player character whose morale is
  half its second argument. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: LongInt;
  monId: Byte;
  morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  monId := Byte(EclMenu.GetEclVar(1));
  SaveLoad.AddCreatureToParty(monId);
  morale := Byte(EclMenu.GetEclVar(2));
  morale := morale shr 1;
  morale := morale or C_Npc.NON_PLAYER;
  GDVars.curChar^.npc := morale;
  CharHlp.RecalcStats(GDVars.curChar);
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ Opcode $37 <name> <address>: looks for the party NPC with the given name and stores its place in the party (counted
  from 0, plus $80 if it is out of play), or $FF if there is none. }
procedure EclFindNpc;
var
  tempName: String[40];
  p: Types.PCharacter;
  wsSlot: Word;
  found: Boolean;
  slot: Byte;
begin
  EclMenu.LoadEclVars(2);
  tempName := GDVars.gbStrings[1];
  wsSlot := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  p := GDVars.partyHead;
  found := False;
  slot := 0;
  while (p <> nil) and (not found) do begin
    if (p^.name = tempName) and (p^.npc > $7F) then
      found := True
    else begin
      p := p^.next;
      Inc(slot);
    end;
  end;
  if not found then
    slot := $FF
  else if p^.inPlay = 0 then
    slot := slot or $80;
  EclMenu.WriteGbvm(wsSlot, slot, GDVars.varTypes[1]);
end;

{ SPELL ($3B) <spell> <address1> <address2>: finds the first party member in play who has the spell memorized. Stores
  its position in that member's spell list, or $FF if nobody has it, and the member's place in the party. }
procedure EclSpell;
var
  spellId: Byte;
  idx: Byte;
  idx2: Byte;
  p: Types.PCharacter;
  doneFlag: Boolean;
  exhausted: Boolean;
  firstAddress: Word;
  secondAddress: Word;
begin
  exhausted := False;
  doneFlag := False;
  EclMenu.LoadEclVars(3);
  spellId := Byte(EclMenu.GetEclVar(1));
  firstAddress := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  secondAddress := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  idx := 1;
  idx2 := 0;
  p := GDVars.partyHead;
  while (p <> nil) and (not doneFlag) do begin
    idx := 0;
    if p^.inPlay <> 0 then begin
      repeat
        if p^.memorized[idx] = spellId then
          doneFlag := True
        else begin
          if idx < 140 then
            Inc(idx)
          else
            exhausted := True;
        end;
      until exhausted or doneFlag;
    end;
    exhausted := False;
    p := p^.next;
    if (p <> nil) and (not doneFlag) then
      Inc(idx2);
  end;
  if not doneFlag then
    idx := $FF;
  EclMenu.WriteGbvm(firstAddress, idx, GDVars.varTypes[2]);
  EclMenu.WriteGbvm(secondAddress, idx2, GDVars.varTypes[3]);
end;

{ CALL, opcode $2D: runs the built-in routine its argument names: 1 refreshes the display and the status line, 2 moves
  the party forward, 3 shows the next animation frame. }
procedure EclCall;
var address: Word;
begin
  EclMenu.LoadEclVars(1);
  address := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  case address of
    1: begin
         EclMenu.UpdateEclDisplay;
         CharHlp.PrintPositionAndTime;
       end;
    2: EclMenu.EclMoveForward;
    3: begin
         Mouse.HideMouse;
         Portrait.DisplayImageBuf(3, 3, True, GDVars.curFrameIndex);
         Mouse.ShowMouse;
         Inc(GDVars.curFrameIndex);
         if GDVars.curFrameIndex > GDVars.lastFrameIndex then
           GDVars.curFrameIndex := GDVars.firstFrameIndex;
         TextRend.PauseOnly;
       end;
  end;
end;

{ Runs the before-camp script entry (entry point 3) and the camp menu; if the rest was interrupted, repaints the
  non-combat interface and runs the camp-interrupted entry (entry point 4). Then requests a map redraw, redraws the map
  view, clears the recently-saved flag, and, when not in a dungeon and the map pane is on, draws the map cursor. }
procedure EnterCamp;
var interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GDVars.vmBand.vmRun[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.vmBand.vmRun[4]);
  end;
  GDVars.pendingRefresh := 1;
  MapView.DisplayMapView;
  GDVars.recentlySaved := 0;
  if (GDVars.gameState^.location = 0) and (GDVars.gameState^.layoutFlag = 1) then
    MapCurs.DrawCursor;
end;

{ PROGRAM, opcode $38: runs the program its argument names: 0 the character main menu, 1 the restart, 2 the exit to DOS,
  3 the next luck text, 4 the Fix menu, 5 the party repair and 9 the camp. }
procedure EclProgram;
var
  prog: Byte;
  saved: Word;
  { Unused in this version; see the other implementations of this routine. }
  deadFiller: array[0..3] of Byte;
    { Unused in this version; see the other implementations of this routine. }
    preFlag: Byte;
    savedFlag: Byte;
    program4Out: Byte;
begin
  savedFlag := GDVars.isMoveMode;
  GDVars.isMoveMode := 0;
  if GDVars.pendingCharSwap then begin
    GDVars.curChar := Types.PCharacter(Ptr(GDVars.pendingCharHalves.seg, GDVars.pendingCharHalves.ofs));
    GDVars.pendingCharSwap := False;
  end;
  EclMenu.LoadEclVars(1);
  prog := Byte(EclMenu.GetEclVar(1));
  case prog of
    0: begin
         CharGen.MainMenu;
         if (GDVars.resourceCurrentId <> 9) and (GDVars.gameState^.location = 0) and
             (GDVars.gameState^.layoutFlag = 1) and
             (GDVars.scriptAbortFlag = 0) then begin
           CharHlp.DisplayNoncombatInterface;
           MapCurs.DrawCursor;
         end;
       end;
    1: Restart.RequestRestart;
    2: begin
         GameIo.ExitGame(0);
         Halt(0);
       end;
    3: Camp.ShowNextLuckText;
    4: Camp.CampFixMenu(Boolean(program4Out));
    5: begin
         GDVars.program5Flag := 0;
         Temple.RepairParty;
         if GDVars.program5Flag = 0 then
           MenuCore.WaitContinueClear;
       end;
    9: begin
         saved := GDVars.vmBand.eclIp;
         EclVm.EnterCamp;
         GDVars.vmBand.eclIp := saved;
         if GDVars.gameState^.layoutFlag = 1 then
           EclVm.EclExit;
       end;
  end;
  GDVars.isMoveMode := savedFlag;
end;

{ REMOVE CHARACTER, opcode $3E: removes the current character from the party, keeps the character that becomes current
  as the saved character to restore, and redraws the party. }
procedure EclDump;
begin
  Inc(GDVars.vmBand.eclIp);
  CharGen.RemoveCreature(False, True);
  GDVars.pendingCharHalves := curCharHalves;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ HAS EFFECT, opcode $3F: clears the compare flags, then sets the equal flag when the current character has the effect
  in its argument, the not-equal flag otherwise. }
procedure EclFindSpecial;
var eff: Pointer; idx: Byte;
begin
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  EclMenu.LoadEclVars(1);
  idx := Byte(EclMenu.GetEclVar(1));
  if CharHlp.HasEffect(GDVars.curChar, idx, eff) then
    GDVars.compareFlags[1] := 1
  else
    GDVars.compareFlags[2] := 1;
end;

{ Opcode $40 <item type>: takes every item of that type away from the whole party, unreadying it first. With bit $80 set
  only magical items are taken. }
procedure EclDestroyItems;
var
  idx: Byte;
  p: Types.PCharacter;
  savedChar: Types.PCharacter;
  it: Types.PItem;
  nextIt: Types.PItem;
  flag80: Byte;
begin
  EclMenu.LoadEclVars(1);
  idx := Byte(EclMenu.GetEclVar(1));
  flag80 := idx and $80;
  idx := idx and $7F;
  savedChar := GDVars.curChar;
  p := GDVars.partyHead;
  while p <> nil do begin
    it := Types.PItem(p^.items);
    while it <> nil do begin
      nextIt := it^.next;
      if idx = it^.itemType then begin
        if (flag80 = 0) or (it^.plus <> 0) then begin
          GDVars.curChar := p;
          if it^.equipped <> 0 then
            ViewChar.ToggleReadyItem(it);
          CharHlp.RemoveItem(p, it);
        end;
      end;
      it := nextIt;
    end;
    CharHlp.RecalcStats(p);
    p := p^.next;
  end;
  GDVars.curChar := savedChar;
end;

{ Opcode $44: takes the first party item that matches as for opcode $43, unreadying it first when it is readied, and
  recomputes its owner. }
procedure EclTakeItem;
var
  target: Byte;
  p: Types.PCharacter;
  item: Types.PItem;
  nextItem: Types.PItem;
  match: Types.TNameIds;
begin
  EclMenu.LoadEclVars(4);
  target := Byte(EclMenu.GetEclVar(1));
  match[3] := Byte(EclMenu.GetEclVar(2));
  match[2] := Byte(EclMenu.GetEclVar(3));
  match[1] := Byte(EclMenu.GetEclVar(4));
  p := GDVars.partyHead;
  while p <> nil do begin
    item := p^.items;
    while item <> nil do begin
      nextItem := item^.next;
      if ((target = 0) or (target = item^.itemType)) and
          ((match[3] = 0) or EclVm.ItemMatches(match, item^.nameIds)) then begin
        if item^.equipped <> 0 then
          ViewChar.ToggleReadyItem(item);
        CharHlp.RemoveItem(p, item);
        CharHlp.RecalcStats(p);
        Exit;
      end;
      item := nextItem;
    end;
    p := p^.next;
  end;
end;

{ Runs the award-experience command, whose operands are a whole-party flag and an amount: awards the amount x 100
  experience points, divided by the member's number of non-zero class levels (cleric to thief), to every party member in
  play when the flag is non-zero, otherwise to the current character if it is in play. It announces the award and marks
  whether each recipient can now level up, and after a party award redraws the party. }
procedure EclAwardExperience;
var
  xpRaw: LongInt; share: LongInt; scaledPct: LongInt; ask: Byte;
  p: Types.PCharacter; i: ShortInt; eligibleCount: Byte;
begin
  EclMenu.LoadEclVars(2);
  xpRaw := EclMenu.GetEclVar(2);
  scaledPct := xpRaw * 100;
  ask := Byte(EclMenu.GetEclVar(1));
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  if ask <> 0 then begin
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
                                  'Congratulations the party gains experience!');
    TextRend.PauseOnly;
    p := GDVars.partyHead;
    while p <> nil do begin
      if p^.inPlay <> 0 then begin
        eligibleCount := 0;
        for i := C_Class.CLERIC to C_Class.THIEF do
          if p^.classLevels[i] > 0 then Inc(eligibleCount);
        share := scaledPct div eligibleCount;
        p^.experience := p^.experience + share;
        p^.displayHighlight := Byte(CharHlp.CanLevelUp(p));
      end;
      p := p^.next;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  end else begin
    p := GDVars.curChar;
    if p^.inPlay <> 0 then begin
      TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
                                    'Congratulations ' + p^.name + ' gains experience!');
      TextRend.PauseOnly;
      eligibleCount := 0;
      for i := C_Class.CLERIC to C_Class.THIEF do
        if p^.classLevels[i] > 0 then Inc(eligibleCount);
      share := scaledPct div eligibleCount;
      p^.experience := p^.experience + share;
      p^.displayHighlight := Byte(CharHlp.CanLevelUp(p));
    end;
  end;
end;

{ Opcode $1F <number>: tells the party which journal entry to read, then waits for a key or button. }
procedure EclJournalEntry;
var
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  result: Byte;
  v: Word;
begin
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(1);
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  s := 'This is recorded as journal entry ' + CharHlp.Uint8Str(Byte(v)) + '.';
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, s);
  result := EclMenu.MenuHorizontalCharacterSelect('', GDConsts.tildePressButtonPrompt, True,
                                                  Byte(GDVars.eclPicShown));
  MenuCore.ClearBottomLine;
end;

{ Opcode $23: clears the message window, updates the display and ends the script. }
procedure EclRedrawExit;
begin
  Border.EraseBox(1, 17, 38, 22);
  EclMenu.UpdateEclDisplay;
  EclVm.EclExit;
end;

{ PLAY SOUND, opcode $2C: an argument with bit $80 set switches the music to piece (argument and $7F); 2 to 14 plays
  that sound. }
procedure EclPlaySound;
var attitude: Byte;
begin
  EclMenu.LoadEclVars(1);
  attitude := Byte(EclMenu.GetEclVar(1));
  if attitude > $7F then
    Music.StartMusic(attitude and $7F)
  else if (attitude < 15) and (attitude > 1) then
    Music.SendSoundCommand(attitude);
end;

{ Opcode $29: skipped. }
procedure EclEncounter;
begin
  Inc(GDVars.vmBand.eclIp);
end;

{ STORE, opcode $3C: prepends a treasure node for each item of wardTable's run for the category in its argument (1 to
  16, else 1; runs end in $FF; item 0 is skipped and item $FF is a random scroll from EclMenu.EclBuildRandomScroll),
  each with its name parts identified, then runs the shop and clears the encounter. }
procedure EclShop;
var
  rawBuf: Types.TItemDef;
  idx: Byte;
  itemIdx: Byte;
  node: Types.TItem;
  savedHead: Pointer;
  scan: Word;
  endScan: Word;
  wardPos: Byte;
begin
  EclMenu.LoadEclVars(1);
  CharHlp.ClearEncounterState;
  idx := Byte(EclMenu.GetEclVar(1));
  if (idx > 16) or (idx < 1) then idx := 1;
  wardPos := 1;
  scan := 1;
  while idx > wardPos do begin
    if GDConsts.wardTable[scan] = $FF then Inc(wardPos);
    Inc(scan);
  end;
  endScan := scan;
  while GDConsts.wardTable[endScan + 1] <> $FF do Inc(endScan);
  for wardPos := Byte(scan) to Byte(endScan) do begin
      itemIdx := GDConsts.wardTable[wardPos];
      if itemIdx = 0 then
        rawBuf.itemType := $FF
      else if itemIdx = $FF then
        EclMenu.EclBuildRandomScroll(rawBuf)
      else
        rawBuf := GDVars.itemDefs^[itemIdx];
      if rawBuf.itemType <> $FF then begin
        Move(rawBuf, node.itemType, SizeOf(rawBuf));
        node.unidMask := node.unidMask and $F8;
        node.next := nil;
        node.inUse := 0;
        if GDVars.treasureItems = nil then begin
          GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
          if GDVars.treasureItems = nil then GDVars.fatalMessageHook('Out of ram');
          GDVars.treasureItems^ := node;
        end else begin
          savedHead := GDVars.treasureItems;
          GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
          if GDVars.treasureItems = nil then GDVars.fatalMessageHook('Out of ram');
          GDVars.treasureItems^ := node;
          GDVars.treasureItems^.next := savedHead;
        end;
      end;
  end;
  Shop.ShopMainMenu;
  CharHlp.ClearEncounterState;
end;

{ Runs the handler for the current opcode. }
procedure DispatchEclCommand;
begin
  case GDVars.curOpcode of
    EclVm.OP_EXIT: EclVm.EclExit;
    C_Ecl.OP_GOTO: EclVm.EclGoto;
    C_Ecl.GOSUB: EclVm.EclGosubCmd;
    C_Ecl.COMPARE: EclVm.EclCompare;
    C_Ecl.ADD, EclVm.SUBTRACT, EclVm.DIVIDE, C_Ecl.MULTIPLY: EclVm.EclArithmetic;
    C_Ecl.OP_RANDOM: EclVm.EclRandom;
    C_Ecl.SAVE: EclVm.EclSave;
    C_Ecl.LOAD_CHARACTER: EclVm.EclLoadCharacter;
    C_Ecl.LOAD_MONSTER: EclVm.EclLoadMonster;
    C_Ecl.SETUP_MONSTER: EclVm.EclSetupMonster;
    EclVm.APPROACH: EclVm.EclApproach;
    C_Ecl.PICTURE: EclVm.EclPicture;
    C_Ecl.INPUT_NUMBER: EclVm.EclInputNumber;
    C_Ecl.INPUT_STRING: EclVm.EclInputString;
    C_Ecl.PRINT, C_Ecl.PRINT_CLEAR: EclVm.EclPrint;
    EclVm.OP_RETURN: EclVm.EclReturn;
    C_Ecl.COMPARE_AND: EclVm.EclCompareAnd;
    EclVm.VERTICAL_MENU: EclVm.EclVMenu;
    EclVm.IF_EQ, EclVm.IF_NE, EclVm.IF_LT, EclVm.IF_GT, EclVm.IF_LE,
        EclVm.IF_GE: EclVm.EclIf;
    EclVm.CLEAR_MONSTERS: EclVm.EclClearMonsters;
    EclVm.WAIT_KEY: EclVm.EclContinuePrompt;
    $1E: EclVm.EclCheckParty;
    C_Ecl.JOURNAL_ENTRY: EclVm.EclJournalEntry;
    C_Ecl.NEW_ECL: EclVm.EclNewEcl;
    C_Ecl.LOAD_FILES: EclVm.EclLoadFiles;
    EclVm.YES_NO: EclVm.EclYesNo;
    $23: EclVm.EclRedrawExit;
    EclVm.OP_COMBAT: EclVm.EclCombat;
    EclVm.ON_GOTO, EclVm.ON_GOSUB: EclVm.EclOnGoto;
    EclVm.TREASURE: EclVm.EclTreasure;
    C_Ecl.ROB: EclVm.EclRob;
    $29: EclVm.EclEncounter;
    C_Ecl.GET_TABLE: EclVm.EclGetTable;
    EclVm.HORIZONTAL_MENU: EclVm.EclHMenu(False);
    C_Ecl.PLAY_SOUND: EclVm.EclPlaySound;
    C_Ecl.CALL: EclVm.EclCall;
    C_Ecl.DAMAGE: EclVm.EclDamage;
    C_Ecl.OP_AND, C_Ecl.OP_OR: EclVm.EclAndOr;
    $31: EclVm.EclHMenu(True);
    C_Ecl.FIND_ITEM: EclVm.EclFindItem;
    EclVm.PRINT_RETURN: EclVm.EclPrintReturn;
    C_Ecl.CLOCK: EclVm.EclClock;
    C_Ecl.SAVE_TABLE: EclVm.EclSaveTable;
    C_Ecl.ADD_NPC: EclVm.EclAddNpc;
    C_Ecl.FIND_NPC: EclVm.EclFindNpc;
    C_Ecl.OP_PROGRAM: EclVm.EclProgram;
    C_Ecl.WHO: EclVm.EclWho;
    EclVm.OP_DELAY: EclVm.EclDelay;
    C_Ecl.SPELL: EclVm.EclSpell;
    C_Ecl.STORE: EclVm.EclShop;
    EclVm.CLEAR_BOX: EclVm.EclClearBox;
    EclVm.REMOVE_CHARACTER: EclVm.EclDump;
    C_Ecl.HAS_EFFECT: EclVm.EclFindSpecial;
    C_Ecl.TAKE_ITEMS: EclVm.EclDestroyItems;
    C_Ecl.AWARD_EXPERIENCE: EclVm.EclAwardExperience;
    $42: EclVm.EclLoadWallSets;
    $43: EclVm.EclFindMatchingItem;
    $44: EclVm.EclTakeItem;
  end;
end;

{ Runs the loaded script until a command stops it, the party is defeated or the script is aborted.
  @param(startPc The address to start at.) }
procedure CallEclScript(startPc: Word);
var
  { Unused in this version; see the other implementations of this routine. }
  savedIp: Word;
begin
  GDVars.scratchIndex := 1;
  GDVars.vmBand.eclIp := startPc;
  GDVars.loopRunning := 0;
  while (GDVars.loopRunning = 0) and (not GDVars.partyDefeated) and (GDVars.scriptAbortFlag = 0) do begin
    GDVars.lastOpcode := GDVars.curOpcode;
    GDVars.curOpcode := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp];
    EclVm.DispatchEclCommand;
  end;
  GDVars.loopRunning := 0;
end;

{ Runs the script for the party's new position: from its fifth entry point, then (unless that moved the party again) its
  first and second, repeating as long as a script moves the party on. }
procedure NewEclDone;
begin
  repeat
    Portrait.FreeAnimation;
    GDVars.resourceSavedName[0] := #0;
    GDVars.resourceSavedId := $FF;
    GDVars.areaExitFlag := False;
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y);
    GDVars.gameState^.leaveMap := 0;
    GDVars.pendingCharHalves := curCharHalves;
    EclVm.CallEclScript(GDVars.vmBand.vmRun[5]);
    if not GDVars.areaExitFlag then
      GDVars.gameState^.areaScriptId := GDVars.environmentId;
    if not GDVars.areaExitFlag then begin
      if (GDVars.locState.previous <> C_Ifc.DUNGEON) or (GDVars.locState.current = C_Ifc.DUNGEON) or
          ((GDVars.locState.previous = C_Ifc.DUNGEON) and (GDVars.locState.current = C_Ifc.DUNGEON)) then
        MapView.DisplayMapView;
      GDVars.areaExitFlag := False;
      EclVm.CallEclScript(GDVars.vmBand.vmRun[1]);
      if not GDVars.areaExitFlag then begin
        EclVm.CallEclScript(GDVars.vmBand.vmRun[2]);
        if not GDVars.areaExitFlag then begin
          curCharHalves := GDVars.pendingCharHalves;
          CharHlp.DisplayParty(GDVars.curChar);
        end;
      end;
    end;
  until not GDVars.areaExitFlag;
  GDVars.locState.previous := GDVars.locState.current;
end;

procedure GameLoop;
var
  moveResult: Byte;
  p: Types.PCharacter;
  savedFlag: Byte;
begin
  GameIo.DrainKeys;
  repeat
    GDVars.scriptAbortFlag := 0;
    GDVars.pendingCharHalves := curCharHalves;
    GDVars.pendingRefresh := 1;
    GDVars.pendingCharSwap := False;
    GDVars.locState.current := C_Ifc.DUNGEON;
    GDVars.areaExitFlag := False;
    if GDVars.gameState^.areaScriptId = 0 then begin
      if GDVars.inputAbort then
        GDVars.environmentId := 4
      else begin
        GDVars.environmentId := 16;
        CharHlp.DisplayParty(GDVars.curChar);
      end;
    end else
      GDVars.environmentId := GDVars.gameState^.areaScriptId;
    if GDVars.gameState^.location = 0 then
      GDVars.locState.current := C_Ifc.AREA_MAP;
    EclMenu.LoadEclScript(GDVars.environmentId);
    EclMenu.EclInit;
    EclVm.CallEclScript(GDVars.vmBand.vmRun[5]);
    if GDVars.inputAbort then begin
      p := GDVars.partyHead;
      while p <> nil do begin
        GDVars.curChar := p;
        p := p^.next;
        CharGen.RemoveCreature(True, True);
      end;
      Portrait.FreeAnimation;
      Blit.FreePic(Types.PImage(GDConsts.extraPictureA));
      Blit.FreePic(Types.PImage(GDVars.backdropImage));
      Blit.FreePic(Types.PImage(GDVars.skyImage));
      Blit.FreePic(Types.PImage(GDVars.banks[0]));
      Blit.FreePic(Types.PImage(GDVars.banks[1]));
      Blit.FreePic(Types.PImage(GDVars.banks[2]));
      Blit.FreePic(Types.PImage(GDVars.bigPicture));
      Exit;
    end;
    if not GDVars.areaExitFlag then
      GDVars.gameState^.areaScriptId := GDVars.environmentId
    else
      EclVm.NewEclDone;
    if (GDVars.locState.current <> C_Ifc.AREA_MAP) and (GDVars.loadedSavedGameFlag <> 0) then begin
      if GDVars.mapDirtyFlag = 1 then
        CharHlp.DisplayNoncombatInterface;
      GDVars.pendingRefresh := 1;
      MapView.DisplayMapView;
    end;
    GDVars.loadedSavedGameFlag := 0;
    GDVars.isMoveMode := 0;
    savedFlag := 1;
    repeat
      GDVars.horizChoice := savedFlag;
      moveResult := Byte(Explore.MapMainMenu);
      savedFlag := GDVars.horizChoice;
      GDVars.pendingCharHalves := curCharHalves;
      if not GDVars.areaExitFlag then
        GDVars.gameState^.areaScriptId := GDVars.environmentId;
      while ((GDVars.gameState^.searchFlags > 1) or (moveResult = 4)) and (not GDVars.partyDefeated) and
          (GDVars.scriptAbortFlag = 0) do begin
        if moveResult = 4 then
          EclVm.EnterCamp
        else begin
          GDVars.combatSideByte := GDVars.gameState^.searchFlags and 1;
          GDVars.gameState^.searchFlags := 1;
          GDVars.pendingRefresh := 1;
          MapView.DisplayMapView;
          EclVm.CallEclScript(GDVars.vmBand.vmRun[2]);
          if GDVars.areaExitFlag then
            EclVm.NewEclDone;
          GDVars.gameState^.searchFlags := GDVars.combatSideByte;
        end;
        if (not GDVars.partyDefeated) and (GDVars.scriptAbortFlag = 0) then begin
          GDVars.horizChoice := savedFlag;
          moveResult := Byte(Explore.MapMainMenu);
          savedFlag := GDVars.horizChoice;
          GDVars.pendingCharHalves := curCharHalves;
        end;
      end;
      if (not GDVars.partyDefeated) and (GDVars.scriptAbortFlag = 0) then
        EclVm.CallEclScript(GDVars.vmBand.vmRun[1]);
      if GDVars.areaExitFlag then
        EclVm.NewEclDone
      else if (not GDVars.partyDefeated) and (GDVars.scriptAbortFlag = 0) then begin
        GDVars.gameState^.savedX := GDVars.partyPos.x;
        GDVars.gameState^.savedY := GDVars.partyPos.y;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        GDVars.eclPicShown := False;
        EclVm.CallEclScript(GDVars.vmBand.vmRun[2]);
        if GDVars.areaExitFlag then
          EclVm.NewEclDone;
      end;
    until GDVars.partyDefeated or (GDVars.scriptAbortFlag <> 0);
  until GDVars.partyDefeated;
  GDVars.partyDefeated := False;
  p := GDVars.partyHead;
  while p <> nil do begin
    GDVars.curChar := p;
    p := p^.next;
    CharGen.RemoveCreature(False, True);
  end;
  Portrait.FreeAnimation;
  Blit.FreePic(Types.PImage(GDConsts.extraPictureA));
  Blit.FreePic(Types.PImage(GDVars.backdropImage));
  Blit.FreePic(Types.PImage(GDVars.skyImage));
  Blit.FreePic(Types.PImage(GDVars.banks[0]));
  Blit.FreePic(Types.PImage(GDVars.banks[1]));
  Blit.FreePic(Types.PImage(GDVars.banks[2]));
  Blit.FreePic(Types.PImage(GDVars.bigPicture));
end;

begin
  GDVars.finishHook := EclVm.FinishNewEcl;
end.
