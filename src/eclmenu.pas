{ EclMenu -- the ECL script machine's helpers. It loads a command's arguments and the scripts, reads and writes GBVM
  variables by zone (1..$400 the game state, $401..$800 the current character, $8000..$B6B0 the loaded script), decodes
  the scripts' packed strings, and holds the script menus, comparisons, gosub, movement, robbery, damage and the
  encounter's monster display. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit EclMenu;

interface

uses Types, Crt, GDConsts, GDVars, C_Dir, C_Status, C_Ecl, C_Effect, C_Ifc,
  C_Spell, ZeroFree, GameIo, DaxIo, TextRend, Border, SaveLoad, ViewChar, FxEngine, CharHlp, MenuCore, MapView,
  Portrait, View3D;

{ Returns the value of an operand: a literal byte (type 0), the GBVM value at its address (1, 3, $80), or its two bytes
  as a word (2, $81).
  @param(idx Operand number, from 1.)
  @returns(The operand's value.) }
function GetEclVar(idx: ShortInt): Word;

{ Decodes the arguments of the current script command: each has a type byte and a low byte, and types 1..3 add a high
  byte. Type $80 is an inline packed string of that length and $81 the address of a string; both go to the next script
  string. Leaves the instruction pointer on the next command.
  @param(count The number of arguments.) }
procedure LoadEclVars(count: Byte);

{ Resets the interpreter for a newly loaded script and reads the five entry addresses at its head. The area state is
  cleared too, unless a saved game has just been restored. }
procedure EclInit;

{ Loads a script block from ECL1.DAX into script memory, allocating it on first use, retrying until it reads, and drops
  the block's two-byte header. A script too big for script memory is truncated with 'Ecl too large'.
  @param(scriptId The block.) }
procedure LoadEclScript(scriptId: Byte);

{ Allocates and loads a monster.
  @param(id The monster's record.)
  @param(cr Receives the monster.)
  @param(inv Receives the head of its item list.)
  @param(eff Receives the head of its effect list.) }
procedure InitCreature(id: Byte; var cr, inv, eff: Pointer);

{ Finds how far away an encounter can stand in the facing direction before a wall blocks the view. Outdoors or on the
  overland map it is always 2, and the placement limit is set to match.
  @param(x The party's map column.)
  @param(y The party's map row.)
  @param(facing The party's facing.)
  @returns(The distance, 0 to 2 squares.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Shows an encounter: the monster's 3D sprite in a dungeon off the overland map, closing the automap first, and its
  picture once it is adjacent or has no sprite.
  @param(sprId The sprite, $FF for none.)
  @param(picId The picture, $FF for none.)
  @param(dist The monster's distance.)
  @param(flags Records what is already shown.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lower The low byte.)
  @param(upper The high byte.)
  @returns(The word.) }
function CombineBytesToWord(lower, upper: Byte): Word;

{ Write value (1 or 2 bytes by kind) to a GBVM address. Zone 0 also updates the cells some addresses mirror (automap,
  party x/y and facing, location and interface state, wall set).
  @param(address The script address.)
  @param(value The value.)
  @param(kind The width: below 2 one byte, 2 and up two.) }
procedure WriteGbvm(address, value: Word; kind: Byte);

{ Reads a script variable. A few game-state addresses are computed: the place of the first member in play with effect
  19, the current character's place, whether anyone in the party is detecting magic, the party's position and facing,
  and the wall and event ahead.
  @param(address The script address.)
  @param(kind The width: below 2 one byte, 2 and up two.)
  @returns(The value.) }
function ReadGbvm(address: Word; kind: Byte): Word;

{ Stores a string at a script address: zero-terminated in game state, or as the current character's name.
  @param(address The script address.)
  @param(s The string.) }
procedure WriteGbvmString(address: Word; s: String);

{ Runs a script's horizontal menu. In a dungeon an extended key switches the current character without leaving the menu.
  @param(query The text before the menu.)
  @param(menu The script menu string, prepared by MenuToOptions.)
  @param(enterOk True lets Escape end the menu.)
  @param(hlCol Passed to MenuCore.MenuHorizontal as its animate flag.)
  @returns(The chosen option, from 0, or 0 on Escape.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; enterOk: Boolean; hlCol: Byte): Byte;

{ A script's vertical list menu, through MenuCore.MenuVertical. ulRow and lrRow together carry the far pointer to the
  list, which listArg reads as one.
  @param(query The text before the menu.)
  @param(menu The script menu string, prepared by MenuToOptions.)
  @param(qCol The window's left column.)
  @param(mCol Its top row.)
  @param(hlCol Its right column.)
  @param(ulCol Its bottom row.)
  @param(ulRow Unused by name: it is the list pointer's segment.)
  @param(lrRow The list pointer's offset.)
  @param(lrCol Nonzero adds Exit to the menu.)
  @param(redraw As MenuVertical's.)
  @param(idx As MenuVertical's selectionIndex.)
  @param(sel Receives the chosen line.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol, ulCol: Byte; ulRow, lrRow: Word;
                          lrCol: Byte; var redraw: Boolean; var idx: Integer; var sel: Pointer);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the instruction pointer on the script return stack and jumps to the address in a loaded argument.
  @param(varIdx The argument holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Moves the party one square forward, wrapping around the 16x16 map, and refreshes the event and the wall ahead. }
procedure EclMoveForward;

{ Leaves a character with a fraction of each kind of coin.
  @param(fraction The fraction kept.)
  @param(cr The character.) }
procedure RobMoney(fraction: Real; cr: Pointer);

{ Steals each of a character's items on a 1d100 roll within the chance, unreadying a readied item before removing it; an
  item heavier than 255 takes 90 off the chance and one heavier than 24 takes 50. Note: the reductions come off the
  chance itself, so they lower the chance for each item after it too.
  @param(chance The chance, in percent.)
  @param(cr The character.) }
procedure RobItems(chance: Byte; cr: Pointer);

{ Steps eclIp over the current command, reading as many operands as it takes. }
procedure SkipEclCmd;

{ Deals script damage to a creature with a message, then redraws the party panel; a creature out of play is skipped. The
  message says it dies when the damage is more than 10 above its hit points; otherwise it gives the damage, at most
  three digits. When the message window is full it waits for a key first.
  @param(dmg The damage.)
  @param(cr The character.) }
procedure EclInflictDamage(dmg: Word; cr: Pointer);

{ Refreshes the event under the party and, if a script picture or sprite was shown, clears it and redraws the view. }
procedure UpdateEclDisplay;

{ Builds a random-treasure item record carrying three spells, each rolled until it hits a magic-user spell.
  @param(def Receives the record.) }
procedure EclBuildRandomScroll(var def: Types.TItemDef);

implementation

type
  TReadBuf = array[0..599] of Byte;

procedure ConvGbString(len, strIdx: Byte); forward;

procedure DerefGbString(strIdx: Byte; address: Word); forward;

function DecodeGameCharacter(c: Byte): Char; forward;

function GbvmZone(address: Word): Byte; forward;

function FindCurCharIdx(cr: Types.PCharacter): Byte; forward;

function SpecialReadZ1(address: Word; kind: Byte): Word; forward;

procedure SpecialWriteZ1(address, value: Word); forward;

function FindEffectCharIndex(effectId: Byte): Byte; forward;

procedure MenuToOptions(var menu: String; var opts: Types.TStr40; var cnt: Byte); forward;

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.varTypes[i] := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp + 1];
    GDVars.varLo[i] := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp + 2];
    GDVars.vmBand.eclIp := GDVars.vmBand.eclIp + 2;
    case GDVars.varTypes[i] of
      1, 2, 3: begin
        Inc(GDVars.vmBand.eclIp);
        GDVars.varHi[i] := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp];
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.varLo[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.gbStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.vmBand.eclIp);
        GDVars.varHi[i] := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp];
        v := EclMenu.CombineBytesToWord(GDVars.varLo[i], GDVars.varHi[i]);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
  end;
  Inc(GDVars.vmBand.eclIp);
end;

function GetEclVar(idx: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  vHi: Byte;
  vLo: Byte;
begin
  vHi := GDVars.varLo[idx];
  vLo := GDVars.varHi[idx];
  case GDVars.varTypes[idx] of
    0: GetEclVar := vHi;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(vLo * 256 + vHi, GDVars.varTypes[idx]);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(vHi, vLo);
  end;
end;

procedure EclInit;
begin
  GDVars.eclPicShown := False;
  GDVars.picState.width := 1;
  GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
  GDVars.monsterCount := 8;
  GDVars.vmBand.eclIp := $8000;
  GDVars.targetSelected := False;
  GDVars.eclStack := nil;
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  GDVars.gameState^.restPeriod := 0;
  GDVars.gameState^.interruptPct := 0;
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[1] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[2] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[3] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[4] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmBand.vmRun[5] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  if GDVars.loadedSavedGameFlag = 0 then
    { GBVM addresses $97..$C8 }
    GameIo.ZeroFill(GDVars.gameState^.gbvm[$97], 50);
end;

procedure LoadEclScript(scriptId: Byte);
var
  sizeRead: Word;
  data: Types.PByteBuffer;
begin
  if GDVars.vmBand.zone2 = nil then
    GetMem(GDVars.vmBand.zone2, SizeOf(Types.TZone2));
  GameIo.ZeroFill(GDVars.vmBand.zone2^, SizeOf(Types.TZone2));
  GDVars.suppressDiskPrompt := 0;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
    DaxIo.LoadDax('ECL1', '.dax', scriptId, sizeRead, Types.PByteBuffer(data));
  until sizeRead >= 2;
  if sizeRead - 2 > SizeOf(Types.TZone2) then begin
    GDVars.showMessage('Ecl too large');
    Move(data^[2], GDVars.vmBand.zone2^, SizeOf(Types.TZone2))
  end else
    Move(data^[2], GDVars.vmBand.zone2^, sizeRead - 2);
  ZeroFree.PrefixFree(data, sizeRead);
  MenuCore.ClearBottomLine;
end;

procedure InitCreature(id: Byte; var cr, inv, eff: Pointer);
begin
  cr := nil;
  GetMem(cr, SizeOf(Types.TCharacter));
  SaveLoad.LoadCreatureData(id, False, cr);
  inv := Types.PCharacter(cr)^.items;
  eff := Types.PCharacter(cr)^.effects;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if (GDVars.gameState^.location = 0) or (GDVars.gameState^.overMap = 1) then begin
    MaxMonsterDist := 2;
    GDVars.gameState^.placementLimit := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  spriteDist: Byte;
begin
  spriteDist := dist + 1;
  if (not flags[1]) and (sprId <> $FF) then begin
    if (GDVars.automapShown) or (GDConsts.overViewTransition = 1) then
      GDConsts.overViewTransition := 2;
    if not flags[0] then begin
      if GDVars.automapShown then begin
        GDVars.automapShown := False;
        GDVars.pendingRefresh := 1;
        GDVars.palettePending := 1;
        MapView.DisplayMapView;
      end;
      if (GDVars.gameState^.location <> 0) and (GDVars.gameState^.overMap = 0) then begin
        Portrait.LoadAnimation('SPRIT', sprId, 1);
        flags[0] := True;
        GDVars.sprShown := 1;
      end;
    end else begin
      GDVars.automapShown := False;
      GDVars.palettePending := 1;
      GDVars.pendingRefresh := 1;
      MapView.DisplayMapView;
    end;
    if GDVars.locState.current = C_Ifc.DUNGEON then
      Portrait.Show3DSprite(spriteDist);
  end;
  if (not flags[1]) and (picId <> $FF) and ((dist = 0) or (sprId = $FF)) and
      (GDVars.locState.current = C_Ifc.DUNGEON) then begin
    GDVars.eclPicShown := True;
    Portrait.LoadAnimation('PIC', picId, 0);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, 0);
    GDVars.palettePending := 1;
  end;
end;

function CombineBytesToWord(lower, upper: Byte): Word;
begin CombineBytesToWord := Word(upper) * 256 + lower end;

{ Turns a 6-bit game character into ASCII: 0 to 31 become @ to _, higher codes stay as they are.
  @param(c The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

{ Which zone a script address falls in: 0 = game state ($0001..$0400), 1 = the current character ($0401..$0800), 2 =
  script memory ($8000..$B6B0), 4 = none.
  @param(address The script address.)
  @returns(The zone.) }
function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= 1) and (address <= $400) then
    GbvmZone := 0
  else if (address >= $401) and (address <= $800) then
    GbvmZone := 1
  else if (address >= $8000) and (address <= $B6B0) then
    GbvmZone := 2;
end;

{ Finds a creature's place in the creature list.
  @param(cr The creature.)
  @returns(Its place from 0; the list's length when it is not there.) }
function FindCurCharIdx(cr: Types.PCharacter): Byte;
var
  idx: Byte;
  p: Types.PCharacter;
  found: Boolean;
begin
  p := GDVars.partyHead;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = cr then
      found := True
    else begin
      Inc(idx);
      p := p^.next
    end
  end;
  FindCurCharIdx := idx
end;

{ Reads the current character's record at its zone 1 address.
  @param(address The script address.)
  @param(kind The width in bytes.)
  @returns(The value.) }
function SpecialReadZ1(address: Word; kind: Byte): Word;
var
  buf: TReadBuf;
  v: Word;
begin
  v := 0;
  address := address - $401;
  Move(GDVars.curChar^, buf, SizeOf(GDVars.curChar^));
  Move(buf[address], v, kind);
  SpecialReadZ1 := v;
end;

{ Writes the current character's record at its zone 1 address. Only the fields a script may change are written:
  memorized spells, age, base movement, coins, alignment, base armor class, magic resistance, status, side and hit
  points.
  @param(address The script address.)
  @param(value The value.) }
procedure SpecialWriteZ1(address, value: Word);
var
  i: ShortInt;
begin
  address := address - $401;
  with GDVars.curChar^ do
    case address of
      $1E..$AA: memorized[address - $1E] := Byte(value);
      $B0: age := value;
      $137: movementBase := Byte(value);
      $14B..$150: begin
        i := (address - $14B) div 2;
        coins[i] := value;
      end;
      $167: alignment := Byte(value);
      $170: acBase := Byte(value);
      $1EB: spellResistance := Byte(value);
      $1ED: begin
        status := Byte(value);
        inPlay := Byte(status = C_Status.OKAY);
      end;
      $1EF: side := Byte(value);
      $1FC: hpCur := Byte(value);
    end;
end;

procedure WriteGbvm(address, value: Word; kind: Byte);
var
  zone: Byte;
  ok: Boolean;
  width: Byte;
begin
  if kind > 1 then width := 2 else width := 1;
  zone := EclMenu.GbvmZone(address);
  case zone of
    0: begin
      case address - 1 of
        $19:
          if (GDVars.automapShown) and (value <> 0) then begin
            GDVars.automapShown := False;
            MapView.DisplayMapView
          end;
        $33: begin GDVars.partyPos.x := value; GDVars.picState.dirty := 1 end;
        $34: begin GDVars.partyPos.y := value; GDVars.picState.dirty := 1 end;
        $10: begin
          repeat
            ok := True;
            case value of
              0: GDVars.partyPos.facing := C_Dir.NORTH;
              1: GDVars.partyPos.facing := C_Dir.EAST;
              2: GDVars.partyPos.facing := C_Dir.SOUTH;
              3: GDVars.partyPos.facing := C_Dir.WEST
            else
              ok := False;
              Dec(value, 4)
            end
          until ok = True;
          GDVars.picState.dirty := 1
        end;
        $21:
          if GDVars.gameState^.location <> value then begin
            GDVars.automapShown := False;
            GDVars.locState.previous := GDVars.locState.current;
            if value = 0 then begin
              GDVars.locState.current := C_Ifc.AREA_MAP;
              GDVars.wallSetCache[1].wallDefId := 0
            end else
              GDVars.locState.current := C_Ifc.DUNGEON
          end;
        $39: ;
        $41:
          begin
            GDVars.picState.width := 1;
            Move(value, GDVars.gameState^.gbvm[address], width);
            View3D.LoadOverPalette
          end
      end;
      Move(value, GDVars.gameState^.gbvm[address], width)
    end;
    1: EclMenu.SpecialWriteZ1(address, value);
    2: Move(value, GDVars.vmBand.zone2^[address], width)
  end
end;

{ Finds the first party member in play who carries an effect.
  @param(effectId The effect.)
  @returns(The member's place, from 1, or 0 for none.) }
function FindEffectCharIndex(effectId: Byte): Byte;
var
  p: Types.PCharacter;
  eff: Pointer;
  idx: Byte;
begin
  p := GDVars.partyHead;
  idx := 1;
  while p <> nil do begin
    if (p^.inPlay <> 0) and CharHlp.HasEffect(p, effectId, eff) then begin
      FindEffectCharIndex := idx;
      Exit
    end;
    p := p^.next;
    Inc(idx)
  end;
  FindEffectCharIndex := 0
end;

function ReadGbvm(address: Word; kind: Byte): Word;
var
  zone: Byte;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  zoneIndex: Byte;
  value: Word;
  width: Byte;
  p: Types.PCharacter;
  eff: Pointer;
begin
  if kind > 1 then width := 2 else width := 1;
  zone := EclMenu.GbvmZone(address);
  found := False;
  value := 0;
  case zone of
    0:
      case address - 1 of
        $50: value := EclMenu.FindEffectCharIndex($13);
        $0C: value := EclMenu.FindCurCharIdx(GDVars.curChar);
        $0F: begin
          p := GDVars.partyHead;
          while (p <> nil) and not CharHlp.HasEffect(p, C_Effect.DETECT_MAGIC, eff) do
            p := p^.next;
          if p = nil then value := 0 else value := 1
        end;
        $22: value := GDVars.partyPos.facing;
        $33: value := GDVars.partyPos.x;
        $34: value := GDVars.partyPos.y;
        $10:
          if GDVars.gameState^.location = 0 then
            value := GDVars.partyPos.facing
          else
            value := GDVars.partyPos.facing div 2;
        $31: value := GDVars.partyPos.wallAhead;
        $2C: value := GDVars.partyPos.eventAtCell
      else
        Move(GDVars.gameState^.gbvm[address], value, width)
      end;
    1: value := EclMenu.SpecialReadZ1(address, width);
    2: Move(GDVars.vmBand.zone2^[address], value, width)
  end;
  ReadGbvm := value
end;

procedure WriteGbvmString(address: Word; s: String);
var
  zone: Byte;
  len: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  len := Length(s);
  case zone of
    0: begin
      Move(s[1], GDVars.gameState^.gbvm[address], len);
      { past the bank when addr + len > $400 }
      GDVars.gameState^.gbvm[address + len] := 0
    end;
    1:
      if address = $401 then GDVars.curChar^.name := s
  end
end;

{ Decodes packed 6-bit game characters at the script's instruction pointer into a script string, four characters to
  three bytes; zero characters are dropped. The instruction pointer ends on the last byte read.
  @param(len The number of packed bytes.)
  @param(strIdx The script string to fill.) }
procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  sixBitCode: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.vmBand.eclIp);
      prev := cur;
      cur := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        sixBitCode := cur shr 2;
      2: begin
        sixBitCode := Byte(prev shl 6) + Byte(cur shr 2);
        sixBitCode := sixBitCode shr 2;
      end;
      3: begin
        sixBitCode := Byte(prev shl 4) + Byte(cur shr 4);
        sixBitCode := sixBitCode shr 2;
      end;
      4:
        sixBitCode := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if sixBitCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(sixBitCode);
      GDVars.gbStrings[strIdx] := GDVars.gbStrings[strIdx] + ch;
    end;
  end;
  if phase = 4 then begin
    sixBitCode := cur and $3F;
    if sixBitCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(sixBitCode);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
end;

{ Copies the zero-terminated string at a script address, or the current character's name, into a script string.
  @param(strIdx The string slot.)
  @param(address The script address.) }
procedure DerefGbString(strIdx: Byte; address: Word);
var
  zone: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(address);
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.gameState^.gbvm[address + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := GDVars.gbStrings[strIdx] + Char(GDVars.gameState^.gbvm[address + i]);
        Inc(i);
      end;
    1:
      if address = $401 then
        GDVars.gbStrings[strIdx] := GDVars.curChar^.name;
    2:
      while GDVars.vmBand.zone2^[address + i] <> 0 do begin
        GDVars.gbStrings[strIdx] := GDVars.gbStrings[strIdx] + Char(GDVars.vmBand.zone2^[address + i]);
        Inc(i);
      end;
  end;
end;

{ Prepares a script menu string: capitals are lower-cased, and each '~' is removed and the letter after it upper-cased
  as that option's hotkey. Note: digits are shifted along with the capitals, which turns them into letters.
  @param(menu The menu string, prepared in place.)
  @param(opts Receives the hotkeys in order.)
  @param(cnt Receives their count.) }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40; var cnt: Byte);
var
  i: Byte;
begin
  opts := '';
  cnt := 0;
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
      Inc(cnt);
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; enterOk: Boolean; hlCol: Byte): Byte;
var
  opts: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  idx: Byte;
  key: Byte;
  cnt: Byte;
begin
  EclMenu.MenuToOptions(menu, opts, cnt);
  MenuCore.ResetMenuSlots(cnt - 1);
  repeat
    key := Ord(MenuCore.MenuHorizontal(query, menu, Byte(True), hlCol));
    if GDVars.menuReturnedKey and (GDVars.locState.current <> C_Ifc.AREA_MAP) and
        (GDVars.gameState^.location = 1) then begin
      CharHlp.PrintMiscInfo(GDVars.curChar, Byte(False));
      ViewChar.SelectPrevNextChar(Char(key));
      CharHlp.PrintMiscInfo(GDVars.curChar, Byte(True));
      key := $FF;
    end;
  until (key < cnt) or ((key = $1B) and enterOk);
  if key = $1B then
    MenuHorizontalCharacterSelect := 0
  else
    MenuHorizontalCharacterSelect := key;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol, ulCol: Byte; ulRow, lrRow: Word;
                          lrCol: Byte; var redraw: Boolean; var idx: Integer; var sel: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  discard: Byte;
  opts: Types.TStr40;
  cnt: Byte;
  listArg: Pointer absolute lrRow;
begin
  EclMenu.MenuToOptions(menu, opts, cnt);
  MenuCore.ResetMenuSlots(1);
  discard := Ord(MenuCore.MenuVertical(query, GDConsts.selectMenu, ShortInt(qCol), ShortInt(mCol), ShortInt(hlCol),
                                       ShortInt(ulCol), listArg, Boolean(lrCol), Byte(False), redraw, idx, sel));
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  if leftOperand = rightOperand then GDVars.compareFlags[1] := 1;
  if leftOperand <> rightOperand then GDVars.compareFlags[2] := 1;
  if leftOperand < rightOperand then GDVars.compareFlags[3] := 1;
  if leftOperand > rightOperand then GDVars.compareFlags[4] := 1;
  if leftOperand <= rightOperand then GDVars.compareFlags[5] := 1;
  if leftOperand >= rightOperand then GDVars.compareFlags[6] := 1;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  if leftOperand = rightOperand then GDVars.compareFlags[1] := 1;
  if leftOperand <> rightOperand then GDVars.compareFlags[2] := 1;
  if leftOperand < rightOperand then GDVars.compareFlags[3] := 1;
  if leftOperand > rightOperand then GDVars.compareFlags[4] := 1;
  if leftOperand <= rightOperand then GDVars.compareFlags[5] := 1;
  if leftOperand >= rightOperand then GDVars.compareFlags[6] := 1;
end;

procedure EclGosub(varIdx: Byte);
var
  old: Pointer;
begin
  if GDVars.eclStack = nil then begin
    GetMem(GDVars.eclStack, SizeOf(Types.TGosubNode));
    GDVars.eclStack^.next := nil;
  end else begin
    old := GDVars.eclStack;
    GetMem(GDVars.eclStack, SizeOf(Types.TGosubNode));
    GDVars.eclStack^.next := old;
  end;
  GDVars.eclStack^.ip := GDVars.vmBand.eclIp;
  GDVars.vmBand.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[varIdx], GDVars.varHi[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.partyPos.facing of
    C_Dir.NORTH:
      if GDVars.partyPos.y > 0 then
        Dec(GDVars.partyPos.y)
      else
        GDVars.partyPos.y := 15;
    C_Dir.EAST:
      if GDVars.partyPos.x < 15 then
        Inc(GDVars.partyPos.x)
      else
        GDVars.partyPos.x := 0;
    C_Dir.SOUTH:
      if GDVars.partyPos.y < 15 then
        Inc(GDVars.partyPos.y)
      else
        GDVars.partyPos.y := 0;
    C_Dir.WEST:
      if GDVars.partyPos.x > 0 then
        Dec(GDVars.partyPos.x)
      else
        GDVars.partyPos.x := 15;
  end;
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y);
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
  GDVars.picState.dirty := 1;
end;

procedure RobMoney(fraction: Real; cr: Pointer);
begin
  Types.PCharacter(cr)^.coins[0] := Trunc(Types.PCharacter(cr)^.coins[0] * fraction);
  Types.PCharacter(cr)^.coins[1] := Trunc(Types.PCharacter(cr)^.coins[1] * fraction);
  Types.PCharacter(cr)^.coins[2] := Trunc(Types.PCharacter(cr)^.coins[2] * fraction);
end;

procedure RobItems(chance: Byte; cr: Pointer);
var
  roll: Byte;
  item: Types.PItem;
  next: Types.PItem;
begin
  item := Types.PItem(Types.PCharacter(cr)^.items);
  while item <> nil do begin
    if item^.weight > 255 then begin
      if chance > 90 then chance := chance - 90 else chance := 0;
    end else if item^.weight > 24 then begin
      if chance > 50 then chance := chance - 50 else chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    next := item^.next;
    if roll <= chance then begin
      if item^.equipped <> 0 then
        ViewChar.ToggleReadyItem(item);
      CharHlp.RemoveItem(cr, item);
    end;
    item := next;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.curOpcode := GDVars.vmBand.zone2^[GDVars.vmBand.eclIp];
  case GDVars.curOpcode of
    C_Ecl.OP_GOTO, C_Ecl.GOSUB, C_Ecl.LOAD_CHARACTER, C_Ecl.PICTURE, C_Ecl.PRINT, C_Ecl.PRINT_CLEAR,
    C_Ecl.JOURNAL_ENTRY, C_Ecl.NEW_ECL, C_Ecl.PLAY_SOUND, C_Ecl.CALL, C_Ecl.FIND_ITEM, C_Ecl.CLOCK,
    C_Ecl.ADD_NPC, C_Ecl.OP_PROGRAM, C_Ecl.WHO, C_Ecl.STORE,
    C_Ecl.HAS_EFFECT, C_Ecl.TAKE_ITEMS:
      EclMenu.LoadEclVars(1);
    C_Ecl.COMPARE, C_Ecl.OP_RANDOM, C_Ecl.SAVE, C_Ecl.INPUT_NUMBER, C_Ecl.INPUT_STRING, C_Ecl.AWARD_EXPERIENCE,
        C_Ecl.LOAD_FILES, C_Ecl.FIND_NPC:
      EclMenu.LoadEclVars(2);
    C_Ecl.ADD..C_Ecl.MULTIPLY, C_Ecl.LOAD_MONSTER, C_Ecl.ROB, C_Ecl.GET_TABLE, C_Ecl.OP_AND,
        C_Ecl.OP_OR, C_Ecl.SAVE_TABLE, C_Ecl.SPELL:
      EclMenu.LoadEclVars(3);
    C_Ecl.SETUP_MONSTER, C_Ecl.COMPARE_AND, $42, $43, $44:
      EclMenu.LoadEclVars(4);
    C_Ecl.DAMAGE:
      EclMenu.LoadEclVars(5);
    $1E:
      EclMenu.LoadEclVars(6);
  else
    Inc(GDVars.vmBand.eclIp);
  end;
end;

procedure EclInflictDamage(dmg: Word; cr: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  hpBefore: Integer;
  finalMsg: String[80];
  dmgStr: String[3];
  pause: Boolean;
begin
  if Types.PCharacter(cr)^.inPlay <> 0 then begin
    pause := False;
    Str(dmg, dmgStr);
    if Types.PCharacter(cr)^.hpCur + 10 < dmg then
      finalMsg := Concat(Types.PCharacter(cr)^.name, ' dies. ')
    else
      finalMsg := Concat(Types.PCharacter(cr)^.name, ' is hit FOR ', dmgStr, ' points of Damage.');
    if GDVars.curRow > 22 then begin
      GDVars.curRow := 17;
      pause := True;
      TextRend.DisplayAndPause(White, Black, GDConsts.pressButtonPrompt);
    end else
      pause := False;
    GDVars.curCol := 38;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, White, Black, pause, finalMsg);
    CharHlp.InflictDamage(cr, dmg);
    Border.EraseBox(17, 1, 38, 15);
    CharHlp.DisplayParty(GDVars.curChar);
  end;
end;

procedure UpdateEclDisplay;
begin
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y);
  if (GDVars.eclPicShown) or (GDVars.sprShown <> 0) or (GDVars.picState.width <> 0) or
      (GDVars.picState.dirty <> 0) or (GDVars.wallDirty[1] <> 0) then begin
    GameIo.ZeroFill(GDVars.monsterFlags, SizeOf(GDVars.monsterFlags));
    GDVars.pendingRefresh := 1;
    MapView.DisplayMapView;
    CharHlp.PrintPositionAndTime;
    GDVars.wallDirty[1] := 0;
    GDVars.picState.width := 0;
    GDVars.picState.dirty := 0;
    GDVars.eclPicShown := False;
    GDVars.sprShown := 0;
    GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                      GDVars.partyPos.facing);
  end;
end;

procedure EclBuildRandomScroll(var def: Types.TItemDef);
var
  roll: Byte;
  matched: Boolean;
begin
  GameIo.ZeroFill(def, SizeOf(def));
  with def do begin
    itemType := 39;
    nameIds[3] := 40;
    nameIds[2] := 39;
    nameIds[1] := 102;
    plus := 1;
    weight := 1;
    value := 3000;
    for GDVars.scratchIndex := 1 to 3 do begin
      matched := False;
      repeat
        roll := FxEngine.RollDice(1, 126);
        if GDConsts.spellTable[roll].spellBand = C_Spell.MAGIC_USER_LIST then matched := True;
      until matched;
      spells[GDVars.scratchIndex] := roll;
    end;
  end;
end;
begin
end.
