{ GameIo -- keyboard, mouse and joystick input with the control-key toggles, the abort path, the overlay read retry, the
  138-entry item pool, and the rebuild that moves every character's items into the pool. ZeroFill is external
  (ZEROFILL.OBJ). }
{$F+,O-,S+,R-,V-,B-,I-}
unit GameIo;

interface

{ Returns the next key. A waiting key is read at once. Otherwise the mouse, or the joystick when there is no mouse, is
  polled until it gives input or a key is pressed: mouse button 1 or 2 gives Enter or Escape (and sets
  GDVars.mouseClicked), a joystick direction gives its key from GDConsts.joystickKeyMap, and joystick buttons 1 and 2
  give Enter and Escape; a key pressed meanwhile wins. With neither device it waits for a key, or returns #0 while
  GDVars.inputAbort is set. Then Ctrl-S mutes the sound or restores the saved mode (Tandy voices or the PC speaker
  only), Ctrl-R toggles the debug flag, Ctrl-U toggles the resident flag (shutting the music driver down when it
  clears), and Ctrl-C ends the game.
  @returns(The key, control keys included, or #0 while input is aborted and none was waiting.) }
function ReadGameKey: Char;

{ Tells whether input is waiting.
  @returns(True when a key is waiting, a mouse button is down, or -- without a mouse -- a joystick button is down or the
    stick is out of the center.) }
function InputPending: Boolean;

{ Discards every waiting key. }
procedure DrainKeys;

{ Reads and discards one waiting input through ReadGameKey, so its control-key commands still work. }
procedure DiscardPendingKeys;

{ Ends the program: hides and resets the mouse, shuts the music driver down, sends the reset request if the sound driver
  is in use, and halts. Note: the reset id is outside SoundDrv.SoundCommand's 2..12 range, so nothing is sent.
  @param(code The exit status.) }
procedure ExitGame(code: Byte);

{ Reads an overlay for the overlay manager, as installed by GameBoot: calls the saved reader until that succeeds,
  beeping (4000 Hz, 20 ms) after each failure.
  @param(size The overlay to read, passed to the saved reader.)
  @returns(0, success.) }
function OverlayReadWithBeep(size: Word): Integer;

{ Finds the first free item record in the pool (itemType 0). It is not marked taken here: the caller's record fills it.
  When the pool is full it reports 'Out of items' and allocates the record on the heap instead.
  @returns(The record.) }
function AllocSlot: Pointer;

{ Frees p: a pool record is zeroed in place and p set to nil; anything else is a heap block, freed at a record's size.
  Note: after FreeMem, p is left unchanged, pointing at the freed block.
  @param(p Record to free.) }
procedure FreeSlot(var p: Pointer);

{ Re-places every party member's items and effect nodes, compacting the heap: each item is moved into the first free
  pool record, the member's equipped references following it, and each effect node is freed and allocated again. }
procedure RebuildLists;

{ Fills a block with zero bytes.
  @param(dest The block.)
  @param(count Its size in bytes.) }
procedure ZeroFill(var dest; count: Word);

implementation

uses Types, Crt, GDConsts, GDVars, C_Keys, C_Joy, C_Sound, C_Driver, MusDrv,
  SoundDrv, Mouse, Joystick;

const
  { the control keys ReadGameKey acts on }
  KEY_CTRL_C = #3;
  KEY_CTRL_R = #18;
  KEY_CTRL_S = #19;
  KEY_CTRL_U = #21;
  { a mouse's left button, or a joystick's button 1: ENTER }
  FIRST_BUTTON = 1;
  { a mouse's right button, or a joystick's button 2: ESCAPE }
  SECOND_BUTTON = 2;

type
  TRebuildWorkspace = array[0..513] of Byte;

procedure ExitGame(code: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  videoMode: Word;
begin
  Mouse.HideMouse;
  Mouse.ResetMouse;
  MusDrv.StopHook;
  if GDVars.residentMode = C_Driver.SOUND_EFFECTS then SoundDrv.SoundCommand(GDConsts.resetSoundId);
  Halt(code)
end;

function ReadGameKey: Char;
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  deadPtr: Pointer;
  action: Integer;
  zone: Byte;
  got: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  paramIndex: Byte;

  { Waits for a key or for joystick input, turning a button into Enter or Escape and a stick zone into its keypad key. }
  procedure TranslateJoystick;
  begin
    action := 0;
    got := False;
    while (not KeyPressed) and not got do begin
      Joystick.GetJoystick(action, zone);
      if (zone < C_Joy.NO_ZONE) or ((action <> 0) <> False) then begin
        if zone < C_Joy.NO_ZONE then
          ch := GDConsts.joystickKeyMap[zone]
        else
          case action of
            GameIo.FIRST_BUTTON: ch := C_Keys.ENTER;
            GameIo.SECOND_BUTTON: ch := C_Keys.ESCAPE
          end;
        got := True
      end
    end
  end;

  { Waits for a key or a mouse button, turning the button into Enter or Escape and noting the mouse click. }
  procedure TranslateMouse;
  begin
    action := 0;
    got := False;
    while (not KeyPressed) and not got do begin
      Mouse.GetMouse(action, GDVars.mouseX, GDVars.mouseY);
      if action <> 0 then begin
        case action of
          GameIo.FIRST_BUTTON: ch := C_Keys.ENTER;
          GameIo.SECOND_BUTTON: ch := C_Keys.ESCAPE
        end;
        GDVars.mouseClicked := True;
        got := True
      end
    end
  end;

begin
  GDVars.mouseClicked := False;
  if KeyPressed then
    ch := ReadKey
  else if GDVars.joystickPresent or GDVars.mousePresent then begin
    if GDVars.mousePresent then TranslateMouse else TranslateJoystick;
    if KeyPressed then ch := ReadKey
  end else if GDVars.inputAbort then
    ch := #0
  else
    ch := ReadKey;

  if ch = GameIo.KEY_CTRL_S then begin
    if GDVars.displayMode <> C_Sound.MUTED then begin
      GDVars.savedDisplayMode := GDVars.displayMode;
      if GDVars.residentMode = C_Driver.SOUND_EFFECTS then SoundDrv.SoundCommand(GDConsts.soundOffId);
      GDVars.displayMode := C_Sound.MUTED
    end else if GDVars.savedDisplayMode in [C_Sound.TANDY_VOICES, C_Sound.PC_SPEAKER] then begin
      GDVars.displayMode := GDVars.savedDisplayMode;
      if GDVars.residentMode = C_Driver.SOUND_EFFECTS then SoundDrv.SoundCommand(GDConsts.soundOnId)
    end
  end;

  if ch = GameIo.KEY_CTRL_R then GDConsts.debugToggle := not GDConsts.debugToggle;
  if ch = GameIo.KEY_CTRL_U then begin
    GDVars.residentToggle := not GDVars.residentToggle;
    if not GDVars.residentToggle then MusDrv.StopHook
  end;
  if ch = GameIo.KEY_CTRL_C then GameIo.ExitGame(0);
  ReadGameKey := ch
end;

function InputPending: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  actionLead: Byte;
  action: Integer;
  zone: Byte;
begin
  InputPending := KeyPressed;
  if GDVars.joystickPresent or GDVars.mousePresent then begin
    if GDVars.mousePresent then begin
      Mouse.GetMouse(action, GDVars.mouseX, GDVars.mouseY);
      InputPending := KeyPressed or ((action <> 0) <> False)
    end else begin
      Joystick.GetJoystick(action, zone);
      InputPending := KeyPressed or ((action > 0) <> False) or ((zone < C_Joy.NO_ZONE) <> False)
    end
  end
end;

procedure DrainKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  while KeyPressed do ch := ReadKey
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if GameIo.InputPending then ch := GameIo.ReadGameKey
end;

function OverlayReadWithBeep(size: Word): Integer;
begin
  while GDVars.savedOvrReadBuf(size) <> 0 do begin
    Sound(4000);
    Delay(20);
    NoSound
  end;
  OverlayReadWithBeep := 0
end;

function AllocSlot: Pointer;
var i: Byte; found: Boolean; p: Pointer;
begin
  found := False;
  i := 1;
  p := nil;
  while (i <= SizeOf(GDVars.itemPool) div SizeOf(Types.TItem)) and not found do begin
    if GDVars.itemPool[i].itemType = 0 then begin
      p := @GDVars.itemPool[i];
      found := True
    end else
      Inc(i)
  end;
  if p = nil then begin
    GDVars.showMessage('Out of items');
    GetMem(p, SizeOf(Types.TItem))
  end;
  AllocSlot := p
end;

procedure FreeSlot(var p: Pointer);
var i: Byte;
begin
  i := 1;
  while (i <= SizeOf(GDVars.itemPool) div SizeOf(Types.TItem)) and (@GDVars.itemPool[i] <> p) do Inc(i);
  if i <= SizeOf(GDVars.itemPool) div SizeOf(Types.TItem) then begin
    GameIo.ZeroFill(GDVars.itemPool[i], SizeOf(GDVars.itemPool[i]));
    p := nil
  end else
    FreeMem(p, SizeOf(Types.TItem))
end;

procedure RebuildLists;
var
  i: ShortInt;
  itemCopy: Types.TItem;
  { Unused in this version; see the other implementations of this routine. }
  align: Byte;
  smallCopy: Types.TEffect;
  { Unused in this version; see the other implementations of this routine. }
  workspace: TRebuildWorkspace;
  root: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  rootLink: ^Pointer;
  oldItem: Types.PItem;
  item: Types.PItem;
  itemLink: ^Pointer;
  small: Types.PEffect;
  smallLink: ^Pointer;
begin
  root := GDVars.partyHead;
  rootLink := @GDVars.partyHead;
  root := GDVars.partyHead;
  while root <> nil do begin
    item := root^.items;
    itemLink := @root^.items;
    while item <> nil do begin
      itemCopy := item^;
      oldItem := item;
      GameIo.FreeSlot(Pointer(item));
      item := Types.PItem(GameIo.AllocSlot);
      if oldItem <> item then
        for i := 0 to 12 do
          if root^.equipped[i] = oldItem then
            root^.equipped[i] := item;
      item^ := itemCopy;
      itemLink^ := item;
      itemLink := @item^.next;
      item := item^.next
    end;

    small := root^.effects;
    smallLink := @root^.effects;
    while small <> nil do begin
      smallCopy := small^;
      FreeMem(small, SizeOf(Types.TEffect));
      GetMem(small, SizeOf(Types.TEffect));
      small^ := smallCopy;
      smallLink^ := small;
      smallLink := @small^.next;
      small := small^.next
    end;
    root := root^.next
  end
end;

{$L ZEROFILL.OBJ}
procedure ZeroFill(var dest; count: Word); external;

begin
end.
