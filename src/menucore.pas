{ Horizontal and scrolling menu services, mouse/joystick hit testing, timed palette cycling, and allocation of the
  menu's compact string-list nodes. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit MenuCore;

interface

uses Types, Crt, GDConsts, GDVars, C_Keys, C_Ifc, C_Driver, Border, TextRend,
  GameIo, Mouse, Joystick, Portrait, CbtMap;

{ Finds a member of a string list by position.
  @param(targetIndex The member's position, counting from 0.)
  @param(list The list's first member.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(targetIndex: Integer; list: Types.PItemRec): Types.PItemRec;

{ Registers an option as the next choice of the coming menu. Note: slotCount is not checked; 20 or more writes past the
  menu slot table.
  @param(optionId The option's index in the menu string.)
  @param(slotCount The slot to fill; advanced past it.) }
procedure AppendSlot(optionId: Byte; var slotCount: Byte);

{ Clears the menu slots and registers choices 0..lastIdx. Note: lastIdx is not checked; 20 or more writes past the menu
  slot table.
  @param(lastIdx The last choice registered.) }
procedure ResetMenuSlots(lastIdx: Byte);

{ Shows a query and a menu on the bottom line (two lines when the menu holds '@') and waits for a choice. Each option is
  a word starting with a capital letter or digit, its hotkey; only the options registered in GDVars.menuSlots are shown.
  The cursor keys move the highlight, a hotkey or Enter chooses, and mouse clicks are handled for the menu, the party
  list and the game screen behind it. While waiting it cycles palette ranges and can time out to a preset key. With the
  editor and debug flags set, the free heap is shown on the top line.
  @param(query The text before the options.)
  @param(menu The options.)
  @param(reinterpret Nonzero turns keypad digits into the cursor keys they sit on.)
  @param(animate Nonzero also animates the portrait while waiting.)
  @returns(The chosen option's registered choice, or the key code of a special key with GDVars.menuReturnedKey set.) }
function MenuHorizontal(query: Types.TStr40; menu: Types.TStr255; reinterpret, animate: Byte): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Shows a string list in a window and lets the player highlight a line, with the menu below it extended by Next, Prev
  and (when addExit is set) Exit. Heading lines cannot be highlighted.
  @param(query The text before the menu.)
  @param(menu The menu's own options.)
  @param(ulCol The window's left column.)
  @param(ulRow Its top row.)
  @param(lrCol Its right column.)
  @param(lrRow Its bottom row.)
  @param(list The lines to show.)
  @param(addExit True adds Exit to the menu.)
  @param(initial The last registered choice, or $FF when menu has no registered options of its own.)
  @param(redraw True asks for a full repaint; cleared once done.)
  @param(selectionIndex The highlighted position, kept between calls.)
  @param(selection Receives the chosen line, or nil on Escape.)
  @returns(The key that ended the menu, or Escape.) }
function MenuVertical(query: Types.TStr40; menu: Types.TStr255; ulCol, ulRow, lrCol, lrRow: ShortInt; list: Pointer;
                      addExit: Boolean; initial: Byte; var redraw: Boolean; var selectionIndex: Integer;
                      var selection): Char;

{ Asks a question with Yes and No.
  @param(query The question.)
  @param(defaultChoice 0 to highlight Yes first, 1 for No.)
  @returns(0 for Yes, 1 for No.) }
function YesNoMenu(query: Types.TStr40; defaultChoice: Byte): Byte;

{ Allocates a list of empty members, as many as asked; the first is allocated before the count is read, so a count below
  1 gives one member.
  @param(nodeCount Members wanted.)
  @param(list Receives the first member.) }
procedure AllocStringList(nodeCount: Integer; var list: Pointer);

{ Frees each member of a string list; the caller's pointer is not set to nil.
  @param(list The list's first member, or nil.) }
procedure FreeStringList(var list: Pointer);

{ Wait for the continue prompt, then clear the bottom line. }
procedure WaitContinueClear;

implementation

const
  { Menu result meaning no selection: MenuVertical returns it for an empty list (Escape and Exit come back as an
    extended C_Keys.ESCAPE). }
  KEY_NONE = #0;

type
  TMenuSpan = record
    first: Byte;
    last: Byte;
  end;

function FindListMember(targetIndex: Integer; list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> targetIndex) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = targetIndex then
    FindListMember := p
  else
    FindListMember := nil;
end;

{ Counts the members of a string list.
  @param(list The list's first member, or nil.)
  @returns(The number of members.) }
function ListCount(list: Types.PItemRec): Integer;
var
  p: Types.PItemRec;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

procedure AppendSlot(optionId: Byte; var slotCount: Byte);
begin
  GDVars.menuSlots[slotCount].optionId := optionId;
  Inc(slotCount);
end;

procedure ResetMenuSlots(lastIdx: Byte);
var
  i: Byte;
begin
  FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), 255);
  for i := 0 to lastIdx do
    GDVars.menuSlots[i].optionId := i;
end;

{ Start the picture animation and the four palette-cycle timers from now. }
procedure InitializeAnimationTimers;
begin
  for GDVars.scratchIndex := 1 to 4 do
    GDVars.animationTicks[GDVars.scratchIndex] := TextRend.GetTicks;
  GDVars.animationTicks[0] := TextRend.GetTicks;
end;

{ Advance the menu picture's animation when its frame delay has passed (a delay of 99 stops it), and cycle each due
  palette range (Portrait.CyclePaletteRange), slower with input mode 2.
  @param(animate Nonzero animates the picture; cleared when a frame delay of 99 stops it.) }
procedure UpdateAnimation(var animate: Byte);
var
  paletteDue: Boolean;
begin
  if animate <> 0 then
    if GDVars.lastFrameIndex > 0 then
      if GDVars.menuAnimDelays[GDVars.curFrameIndex] * 10 <= TextRend.GetTicks - GDVars.animationTicks[0] then begin
        Inc(GDVars.curFrameIndex);
        if GDVars.curFrameIndex > GDVars.lastFrameIndex then
          GDVars.curFrameIndex := GDVars.firstFrameIndex;
        Portrait.DisplayImageBuf(3, 3, Boolean(animate), GDVars.curFrameIndex);
        GDVars.animationTicks[0] := TextRend.GetTicks;
        animate := Byte(not Boolean(GDVars.menuAnimDelays[GDVars.curFrameIndex] = 99));
      end;
  if GDVars.palettePresetOn <> 0 then
    for GDVars.scratchIndex := 1 to 4 do begin
      if GDVars.residentMode = C_Driver.MUSIC_INSTALLED then
        paletteDue := (GDVars.palettePreset[GDVars.scratchIndex][2] * 5 <
                       (TextRend.GetTicks - GDVars.animationTicks[GDVars.scratchIndex])) and
          (GDVars.palettePreset[GDVars.scratchIndex][2] <> 0)
      else
        paletteDue := (GDVars.palettePreset[GDVars.scratchIndex][2] <
                       (TextRend.GetTicks - GDVars.animationTicks[GDVars.scratchIndex])) and
          (GDVars.palettePreset[GDVars.scratchIndex][2] <> 0);
      if paletteDue then begin
        Portrait.CyclePaletteRange(GDVars.scratchIndex);
        GDVars.animationTicks[GDVars.scratchIndex] := TextRend.GetTicks;
      end;
    end;
end;

function MenuHorizontal(query: Types.TStr40; menu: Types.TStr255; reinterpret, animate: Byte): Char;
var
  ch: Char;
  mouseCellColumn: Integer;
  mouseCellRow: Integer;
  scan: Byte;
  { Unused in this version; see the other implementations of this routine. }
  columnIndex: Byte;
  done: Boolean;
  menuLen: Byte;
  queryLen: Byte;
  spans: array[0..20] of TMenuSpan;
  clickedCharacter: Pointer;
  buttons: Integer;
  releaseX: Integer;
  releaseY: Integer;
  hasAt: Boolean;
  displayRow: Byte;
  spanCount: Byte;
  workMenu: Types.TStr255;
  mappedKey: Char;
  mappedReady: Boolean;

  { Finds the first and last character of each option in workMenu, the option count and the first line's count. }
  procedure ParseMenu;
  var
    wordIdx: Byte;
    i: Byte;
    len: Byte;
  begin
    GameIo.ZeroFill(spans[1], SizeOf(spans) - SizeOf(spans[0]));
    wordIdx := 1;
    len := Length(workMenu);
    { More than 20 options overrun spans. }
    for i := 1 to len do
      if workMenu[i] in ['0'..'9', 'A'..'Z'] then
        if spans[wordIdx].first = 0 then
          spans[wordIdx].first := i
        else begin
          spans[wordIdx].last := i - 2;
          Inc(wordIdx);
          spans[wordIdx].first := i;
        end else if workMenu[i] = '@' then
        spanCount := wordIdx;
    spans[wordIdx].last := len;
    spans[0].last := wordIdx;
  end;

  { Draw the menu after the query with option cur highlighted and every hotkey in the highlight color. }
  procedure DisplayOption(cur: Byte);
  var
    col: Byte;
    row: Byte;
    i: Byte;
  begin
    Mouse.HideMouse;
    col := 1;
    row := displayRow;
    Border.EraseBox(queryLen, row, 39, row);
    if menuLen > 0 then
      for i := 1 to menuLen do begin
        if workMenu[i] = '@' then
        begin
          Border.EraseBox(queryLen + col - 1, row, 39, row);
          Inc(row);
          Border.EraseBox(1, row, 39, row);
          col := 1;
        end else begin
          if (spans[cur].first <= i) and (spans[cur].last >= i) and (GDVars.highlightColor <> 0) then
            TextRend.RenderChar(queryLen + col - 1, row, White, Black, 1, Ord(workMenu[i]), 1)
          else if (workMenu[i] in ['0'..'9', 'A'..'Z']) and (i < Byte(workMenu[0])) and
            not (workMenu[i + 1] in [' ', '@']) then
            TextRend.RenderChar(queryLen + col - 1, row, GDVars.highlightColor, Black, 1, Ord(workMenu[i]), 1)
          else
            TextRend.RenderChar(queryLen + col - 1, row, GDVars.menuTextColor, Black, 1, Ord(workMenu[i]), 1);
          Inc(col);
        end;
      end;
    if queryLen + col - 1 <= 39 then
      Border.EraseBox(queryLen + col - 1, row, 39, row);
    Mouse.ShowMouse;
  end;

  { Answers with the current option's key (Enter for an empty one) and finishes. }
  procedure AcceptCurrent;
  begin
    GDVars.menuReturnedKey := False;
    ch := workMenu[spans[GDVars.horizChoice].first];
    if ch = #0 then
      ch := C_Keys.ENTER;
    done := True;
  end;

  { Tells whether the click falls on the party list and party clicks are allowed on this screen. }
  function PartyClick: Boolean;
  begin
    PartyClick := (GDVars.partyClickMode <> 0) and
      not ((GDVars.locState.current = C_Ifc.AREA_MAP) and (GDVars.gameState^.layoutFlag = 1)) and
      ((GDVars.isMoveMode = 0) or (GDVars.locState.current <> C_Ifc.DUNGEON)) and
      (GDVars.locState.current <> C_Ifc.IN_COMBAT) and (GDVars.partyPanelLeft <= mouseCellColumn) and
      (GDVars.partyPanelRight >= mouseCellColumn) and (GDVars.partyPanelTop <= mouseCellRow) and
      (GDVars.partyPanelBottom >= mouseCellRow);
  end;

  { A party click picks another member (as a cursor-up key) or chooses the highlighted option on the current one. }
  procedure HandlePartyClick;
  var
    i: Byte;
  begin
    scan := mouseCellRow - GDVars.partyPanelTop;
    clickedCharacter := GDVars.partyHead;
    for i := 1 to scan do
      if clickedCharacter <> nil then
        clickedCharacter := Types.PCharacter(clickedCharacter)^.next;
    if clickedCharacter <> nil then
      if ((Types.PCharacter(clickedCharacter) <> GDVars.curChar) and (GDVars.selectionMode = 0)) or
          ((Types.PCharacter(clickedCharacter) <> GDVars.menuSelection) and (GDVars.selectionMode <> 0)) then begin
        if GDVars.selectionMode <> 0 then
          GDVars.menuSelection := Types.PCharacter(clickedCharacter)
        else
          GDVars.alternateChar := Types.PCharacter(clickedCharacter);
        ch := C_Keys.UP;
        GDVars.menuReturnedKey := True;
        done := True;
        Exit;
      end;
    if (clickedCharacter <> nil) and
        ((Types.PCharacter(clickedCharacter) = GDVars.curChar) or
         (Types.PCharacter(clickedCharacter) = GDVars.menuSelection)) then
      AcceptCurrent;
  end;

  { Tells whether, in combat, the click falls inside the arena while the player is moving a combatant or aiming. }
  function ArenaClick: Boolean;
  begin
    ArenaClick := ((GDVars.arenaClickA <> 0) or (GDVars.aimCursorActive <> 0)) and
      (GDVars.locState.current = C_Ifc.IN_COMBAT) and (mouseCellColumn >= 1) and (mouseCellColumn <= 21) and
      (mouseCellRow >= 1) and (mouseCellRow <= 21);
  end;

  { Turns an arena click into the movement key toward the clicked cell, from the aim cursor or the combatant. }
  procedure HandleArenaClick;
  begin
    GDVars.menuReturnedKey := True;
    if GDVars.aimCursorActive <> 0 then begin
      releaseX := GDVars.aimCursorX - GDVars.combatMap^.originX + 1;
      releaseY := GDVars.aimCursorY - GDVars.combatMap^.originY + 1;
    end else begin
      scan := CbtMap.CombatSlot(Pointer(GDVars.curChar));
      releaseX := GDVars.actor[scan].x - GDVars.combatMap^.originX + 1;
      releaseY := GDVars.actor[scan].y - GDVars.combatMap^.originY + 1;
    end;
    ch := Char(Mouse.MouseDirection(releaseX, releaseY, mouseCellColumn div 3 + 1, mouseCellRow div 3 + 1));
    done := True;
  end;

  { Tells whether the click falls inside the 3-D view and view clicks are enabled. }
  function ViewAreaClick: Boolean;
  begin
    ViewAreaClick := (GDVars.isMoveMode <> 0) and (mouseCellColumn >= 3) and (mouseCellColumn <= 13) and
      (mouseCellRow >= 3) and (mouseCellRow <= 13) and (GDVars.locState.current = C_Ifc.DUNGEON);
  end;

  { Turns a 3D-view or automap click into a movement key. }
  procedure HandleViewClick;
  var
    x: ShortInt;
    y: ShortInt;
    dir: Byte;
    face: Byte;
  begin
    GDVars.menuReturnedKey := True;
    if GDVars.automapShown then begin
      x := GDVars.partyPos.x - 5;
      y := GDVars.partyPos.y - 5;
      if x < 0 then x := 0;
      if x > 5 then x := 5;
      if y < 0 then y := 0;
      if y > 5 then y := 5;
      x := GDVars.partyPos.x - x + 3;
      y := GDVars.partyPos.y - y + 3;
      dir := CbtMap.DirectionBetween(x, y, mouseCellColumn, mouseCellRow) shr 1;
      face := GDVars.partyPos.facing shr 1;
      if (x = mouseCellColumn) and (y = mouseCellRow) then
        ch := C_Keys.UP
      else
        ch := Char(GDConsts.menuDirections[face, dir]);
    end else
      ch := GDConsts.directionGrid[mouseCellRow, mouseCellColumn];
    done := True;
  end;

  { True when the click falls on the outdoor area map and map clicks are enabled. }
  function WildernessClick: Boolean;
  begin
    WildernessClick := (GDVars.isMoveMode <> 0) and (GDVars.gameState^.layoutFlag = 1) and
      (GDVars.gameState^.location = 0) and (GDVars.locState.current = C_Ifc.AREA_MAP) and
      (mouseCellColumn >= 1) and (mouseCellColumn <= 38) and (mouseCellRow >= 1) and (mouseCellRow <= 15);
  end;

  { Turn an area-map click into the movement key that steps the party toward the clicked cell. }
  procedure HandleAreaMapClick;
  begin
    GDVars.menuReturnedKey := True;
    ch := Char(Mouse.MouseDirection(GDVars.gameState^.cursorX + 1, GDVars.gameState^.cursorY + 1,
                                    mouseCellColumn, mouseCellRow));
    done := True;
  end;

  { True when the click falls on the menu line or below it. }
  function MenuRowClick: Boolean;
  begin
    MenuRowClick := (displayRow <= mouseCellRow) and not done;
  end;

  { Chooses the option under the clicked column, recording whether it was not already highlighted. }
  procedure HandleMenuRowClick;
  var i: Byte;
  begin
    Inc(mouseCellColumn);
    if queryLen < mouseCellColumn then begin
      mouseCellColumn := mouseCellColumn - queryLen;
      if hasAt then
        if displayRow < mouseCellRow then
          Inc(mouseCellColumn, Pos('@', workMenu))
        else if Pos('@', workMenu) <= mouseCellColumn then
          Exit;
      for i := 1 to spans[0].last do
        if (spans[i].first <= mouseCellColumn) and (spans[i].last >= mouseCellColumn) then begin
          ch := workMenu[spans[i].first];
          if i = GDVars.horizChoice then
            GDVars.menuMouseActive := False
          else
            GDVars.menuMouseActive := True;
          GDVars.horizChoice := i;
          DisplayOption(GDVars.horizChoice);
          done := True;
        end;
    end;
  end;

  { True while the modify-character screen is up and no choice has been made. }
  function ModifyScreenClick: Boolean;
  begin
    ModifyScreenClick := (GDVars.modifyActive <> 0) and not done;
  end;

  { On the modify-character screen, reports the field clicked and returns the Home key. }
  procedure HandleModifyClick;
  begin
    done := True;
    case mouseCellRow of
      1:
        if (mouseCellColumn >= 1) and (mouseCellColumn <= 16) then
          GDVars.modifyMouseRow := 6;
      3:
        if (mouseCellColumn >= 31) and (mouseCellColumn <= 33) then
          GDVars.modifyMouseRow := 7;
      9..14:
        if (mouseCellColumn >= 5) and (mouseCellColumn <= 9) then
          GDVars.modifyMouseRow := mouseCellRow - 9;
    else
      done := False;
    end;
    GDVars.menuReturnedKey := True;
    ch := C_Keys.HOME;
  end;

  { True when the click falls within the columns of the scrolling list MenuVertical shows. }
  function HotspotClick: Boolean;
  begin
    HotspotClick := not done and (GDVars.menuKeyColLo <= mouseCellColumn) and
      (GDVars.menuKeyColHi >= mouseCellColumn);
  end;

  { Chooses the highlighted option on a click on a list row, and flags the click for the vertical menu. }
  procedure HandleHotspotClick;
  begin
    scan := 1;
    GDVars.menuMouseActive := True;
    while (scan <= 25) and (GDVars.menuHotRows[scan] <> 255) and not done do begin
      if GDVars.menuHotRows[scan] <= mouseCellRow then
        done := True;
      Inc(scan);
    end;
    if done then
      AcceptCurrent;
  end;

  { Highlights the previous option, wrapping to the last. }
  procedure MoveLeft;
  begin
    if GDVars.horizChoice = 1 then
      GDVars.horizChoice := spans[0].last
    else
      Dec(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
    done := False;
  end;

  { Highlights the next option, wrapping to the first. }
  procedure MoveRight;
  begin
    if GDVars.horizChoice = spans[0].last then
      GDVars.horizChoice := 1
    else
      Inc(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
    done := False;
  end;

  { Moves to the other line of a two-line menu, clamped to its options. }
  procedure MoveVertical;
  begin
    if GDVars.horizChoice <= spanCount then begin
      Inc(GDVars.horizChoice, spanCount);
      if GDVars.horizChoice > spans[0].last then
        GDVars.horizChoice := spans[0].last;
    end else begin
      Dec(GDVars.horizChoice, spanCount);
      if GDVars.horizChoice > spanCount then
        GDVars.horizChoice := spanCount;
    end;
    DisplayOption(GDVars.horizChoice);
    done := False;
  end;

  { Builds workMenu from a menu, keeping the registered options and recording each one's hotkey in the slot table. }
  procedure NormalizeMenu;
  var
    { Unused in this version; see the other implementations of this routine. }
    firstChar: Byte;
    ordinal: Byte;
    startAt: Byte;
    { Unused in this version; see the other implementations of this routine. }
    lastChar: Byte;
    i: Byte;
    slot: Byte;
    len: Byte;
  begin
    len := Length(menu);
    workMenu := '';
    slot := 0;
    ordinal := 0;
    i := 1;
    { A 21st registered option overruns menuSlots, and an option ending the string reads menu[len + 1], because the
      character test comes before i <= len. }
    while i <= len do begin
      if menu[i] in ['0'..'9', 'A'..'Z'] then
      begin
        if GDVars.menuSlots[slot].optionId = ordinal then begin
          GDVars.menuSlots[slot].keyCode := Ord(menu[i]);
          startAt := i;
          Inc(i);
          while not (menu[i] in ['0'..'9', 'A'..'Z']) and (i <= len) do
            Inc(i);
          workMenu := workMenu + Copy(menu, startAt, i - startAt);
          Inc(slot);
        end else
          Inc(i);
        Inc(ordinal);
      end else
        Inc(i);
    end;
    len := Length(workMenu);
    { Note: empty normalized input reads workMenu[0], its length byte. }
    if workMenu[len] = ' ' then
      Delete(workMenu, len, 1);
  end;

  { Returns the registered choice for the key pressed, a special key's own code, or $FF when no hotkey matches. }
  function MapMenuKey: Byte;
  var i: Byte;
  begin
    if GDVars.menuReturnedKey then
      MapMenuKey := Ord(ch)
    else begin
      i := 0;
      while (i < 20) and (GDVars.menuSlots[i].keyCode <> Ord(ch)) do
        Inc(i);
      if i < 20 then
        MapMenuKey := GDVars.menuSlots[i].optionId
      else
        MapMenuKey := 255;
    end;
  end;

begin
  GDVars.program5Flag := 1;
  if GDConsts.editorEnabled and (GDConsts.debugToggle) then
    TextRend.DisplayStringClear(18, 0, White, Black,
                                GDVars.intToStringHook(MemAvail) + ' ' + GDVars.intToStringHook(MaxAvail) + '  ');
  mappedReady := False;
  NormalizeMenu;
  if Pos('@', workMenu) > 0 then
  begin
    hasAt := True;
    displayRow := 23;
    Border.EraseBox(0, 23, 39, 24);
  end else begin
    hasAt := False;
    displayRow := 24;
  end;
  GDVars.menuReturnedKey := False;
  spans[0].first := Ord((GDVars.menuTextColor <> 0) or (GDVars.highlightColor <> 0));
  queryLen := Length(query) + 0;
  ParseMenu;
  if (GDVars.horizChoice > spans[0].last) or (GDVars.horizChoice = 0) then
    GDVars.horizChoice := 1;
  menuLen := Length(workMenu);
  ch := #0;
  done := False;
  MenuCore.InitializeAnimationTimers;
  if query <> '' then
    TextRend.DisplayStringClear(0, 24, GDVars.queryColor, Black, query);
  DisplayOption(GDVars.horizChoice);
  if GDVars.spriteArchive then
    animate := 0;
  if (animate <> 0) and (GDVars.curFrameIndex > 0) then begin
    Portrait.DisplayImageBuf(3, 3, Boolean(animate), GDVars.curFrameIndex);
    if GDVars.lastFrameIndex < 2 then animate := 0;
  end;
  repeat
    MenuCore.UpdateAnimation(animate);
    if (GDVars.menuAutoDelay > 0) and (TextRend.GetTicks - GDVars.animationTicks[0] >= GDVars.menuAutoDelay) then begin
      mappedKey := GDVars.menuAutoChoice;
      mappedReady := True;
      done := True;
    end;
    if GameIo.InputPending then begin
      ch := GameIo.ReadGameKey;
      if ch = #0 then begin
        ch := GameIo.ReadGameKey;
        GDVars.menuReturnedKey := True;
        done := True;
        if spans[0].last > 1 then
          case ch of
            C_Keys.LEFT: MoveLeft;
            C_Keys.RIGHT: MoveRight;
            C_Keys.UP, C_Keys.DOWN: if hasAt then MoveVertical;
          end;
      end else begin
        GDVars.menuReturnedKey := False;
        case ch of
          C_Keys.ESCAPE:
          begin
            GDVars.menuReturnedKey := True;
            done := True;
          end;
          C_Keys.ENTER:
            if GDVars.mouseClicked then begin
              mouseCellRow := GDVars.mouseY div 8;
              mouseCellColumn := GDVars.mouseX div 8;
              if PartyClick then HandlePartyClick
              else if ArenaClick then HandleArenaClick
              else if ViewAreaClick then HandleViewClick
              else if WildernessClick then HandleAreaMapClick
              else if MenuRowClick then HandleMenuRowClick
              else if ModifyScreenClick then HandleModifyClick
              else if HotspotClick then HandleHotspotClick
              else if (GDVars.locState.current = C_Ifc.IN_COMBAT) and (mouseCellRow <= 22) then begin
                if hasAt then begin
                  ch := 'T';
                  done := True;
                end else if query = 'Aim:' then
                begin
                  ch := 'M';
                  done := True;
                end;
              end else if spans[0].last > 1 then begin
                GDVars.menuReturnedKey := True;
                ch := C_Keys.ESCAPE;
              end else
                done := True;
            end else
              AcceptCurrent;
        else
          ch := UpCase(ch);
          mappedKey := Char(MapMenuKey);
          if Byte(mappedKey) <> 255 then
            for scan := 1 to menuLen do
              if workMenu[scan] = ch then begin
                done := True;
                mouseCellColumn := 1;
                while scan <> spans[mouseCellColumn].first do
                  Inc(mouseCellColumn);
                GDVars.horizChoice := mouseCellColumn;
                DisplayOption(GDVars.horizChoice);
              end;
          if not done and (spans[0].last > 1) then
            if ch = '4' then
              MoveLeft
            else if ch = '6' then
              MoveRight
            else if (ch in ['2', '8', 'H', 'P']) and hasAt then
              MoveVertical;
          if (reinterpret <> 0) and (ch in ['1'..'9', '\']) then
          begin
            if ch = '\' then ch := '7'
            else ch := GDConsts.modifyKeys[Ord(ch) - Ord('1')];
            mappedKey := ch;
            GDVars.menuReturnedKey := True;
            done := True;
          end;
        end;
      end;
    end;
  until done;
  if mappedReady then
    MenuHorizontal := mappedKey
  else
    MenuHorizontal := Char(MapMenuKey);
  GameIo.DrainKeys;
  if GDVars.mouseClicked then
    repeat Mouse.GetMouse(buttons, releaseX, releaseY) until buttons = 0
  else if GDVars.joystickPresent then
    repeat Joystick.GetJoystick(buttons, scan) until buttons = 0;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

function MenuVertical(query: Types.TStr40; menu: Types.TStr255; ulCol, ulRow, lrCol, lrRow: ShortInt; list: Pointer;
                      addExit: Boolean; initial: Byte; var redraw: Boolean; var selectionIndex: Integer;
                      var selection): Char;
var
  width: Byte;
  { hotspot-row counter (DrawPage + mouse test) }
  line: Byte;
  count: Integer;
  rows: Integer;
  ch: Char;
  prevCh: Char;
  hMenu: Types.TStr255;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PItemRec;
  headerCnt: Integer;
  total: Integer;
  mouseCellCol: Byte;
  mouseCellRow: Byte;
  registeredCount: Byte;
  optionCount: Byte;
  slotCursor: Byte;
  prevSlot: Byte;
  nextSlot: Byte;
  exitSlot: Byte;
  clickedIdx: Byte;

  { The last heading line before position n. DrawPage keeps the result but does not use it. }
  function LastLabelBefore(n: Integer; l: Types.PItemRec): Types.PItemRec;
  var
    pp: Types.PItemRec;
    found: Types.PItemRec;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.inUse <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Draw one window of lines starting at list position top, recording each line's screen row in GDVars.menuHotRows. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PItemRec;
    row: ShortInt;
  begin
    FillChar(GDVars.menuHotRows[1], SizeOf(GDVars.menuHotRows), 255);
    Border.EraseBox(ulCol, ulRow, lrCol, lrRow);
    Mouse.HideMouse;
    pp := MenuCore.FindListMember(top, Types.PItemRec(list));
    q := LastLabelBefore(top, Types.PItemRec(list));
    row := ulRow;
    line := 1;
    while (pp <> nil) and (row <= lrRow) do begin
      GDVars.menuHotRows[line] := row;
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, GDVars.queryColor, Black, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, GDVars.menuTextColor, Black, pp^.name);
      if Length(pp^.name) < width then
        TextRend.PrintSpaces(ulCol + Length(pp^.name), row, Black, width - Length(pp^.name));
      pp := pp^.next;
      Inc(row);
      Inc(line);
    end;
    Mouse.ShowMouse;
  end;

  { The position of the first non-blank character of s. }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { The position of the last non-blank character of s. }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Draw line n in white, clearing its cells first. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, Types.PItemRec(list));
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    Border.EraseBox(ulCol + a - 1, ulRow + (n - GDVars.vertTop), ulCol + a - 1 + Length(Copy(pp^.name, a, b)) - 1,
                    ulRow + (n - GDVars.vertTop));
    TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), White, Black, Copy(pp^.name, a, b));
  end;

  { Draw line n in the normal menu color, clearing its cells first; heading and plain lines are drawn alike. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, Types.PItemRec(list));
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    Border.EraseBox(ulCol + a - 1, ulRow + (n - GDVars.vertTop), ulCol + a - 1 + Length(Copy(pp^.name, a, b)) - 1,
                    ulRow + (n - GDVars.vertTop));
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), GDVars.menuTextColor, Black,
                             Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), GDVars.menuTextColor, Black,
                             Copy(pp^.name, a, b));
  end;

  { Move the selection off heading lines, in the given direction, wrapping within the page. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows) and
          ((MenuCore.FindListMember(selectionIndex, Types.PItemRec(list)) = nil) or
           (MenuCore.FindListMember(selectionIndex, Types.PItemRec(list))^.inUse <> 0)) do begin
        Inc(k);
        Inc(selectionIndex);
        if GDVars.vertTop + rows - 1 < selectionIndex then
          selectionIndex := GDVars.vertTop;
      end;
    end else
      while (k < rows) and
          ((MenuCore.FindListMember(selectionIndex, Types.PItemRec(list)) = nil) or
           (MenuCore.FindListMember(selectionIndex, Types.PItemRec(list))^.inUse <> 0)) do begin
        Inc(k);
        Dec(selectionIndex);
        if selectionIndex < GDVars.vertTop then
          selectionIndex := GDVars.vertTop + rows - 1;
      end;
  end;

  { Scroll one page down or up, keeping the selection at the same place on the page. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := selectionIndex - GDVars.vertTop;
    if down then begin
      Inc(GDVars.vertTop, rows);
      if count - rows < GDVars.vertTop then
        GDVars.vertTop := count - rows;
    end else begin
      Dec(GDVars.vertTop, rows);
      if GDVars.vertTop < 0 then
        GDVars.vertTop := 0;
    end;
    selectionIndex := GDVars.vertTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.vertTop);
  end;

  { Moves the selection one line down or up within the page, wrapping at its ends and skipping headings. }
  procedure MoveLine(down: Boolean);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down then begin
      Inc(selectionIndex);
      if GDVars.vertTop + rows - 1 < selectionIndex then
        selectionIndex := GDVars.vertTop;
    end else begin
      Dec(selectionIndex);
      if selectionIndex < GDVars.vertTop then
        selectionIndex := GDVars.vertTop + rows - 1;
    end;
    SkipLabels(down);
  end;

  { Returns the highlighted line as the selection, with the key that chose it. }
  procedure SelectLine;
  begin
    Pointer(selection) := MenuCore.FindListMember(selectionIndex, Types.PItemRec(list));
    MenuVertical := ch;
    GDVars.menuKeyColLo := 127;
    GDVars.menuKeyColHi := -128;
  end;

begin
  if list = nil then begin
    selectionIndex := 0;
    Pointer(selection) := nil;
    GDVars.menuKeyColLo := 127;
    GDVars.menuKeyColHi := -128;
    MenuVertical := MenuCore.KEY_NONE;
  end else begin
    GDVars.menuKeyColLo := ulCol;
    GDVars.menuKeyColHi := lrCol;
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(Types.PItemRec(list));
    rows := lrRow - ulRow + 1;
    p := Types.PItemRec(list);
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    p := Types.PItemRec(list);
    total := 0;
    while p <> nil do begin
      p := p^.next;
      Inc(total);
    end;
    if total <= rows then
      GDVars.vertTop := 0;
    if GDVars.vertTop > selectionIndex then begin
      GDVars.vertTop := selectionIndex;
      redraw := True;
    end;
    if GDVars.vertTop > total then begin
      GDVars.vertTop := 0;
      redraw := True;
    end;
    Inc(selectionIndex);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.vertTop);
    redraw := False;
    registeredCount := 0;
    if initial <> 255 then
      for line := 0 to 19 do
        if GDVars.menuSlots[line].optionId <> 255 then
          Inc(registeredCount);
    repeat
      GDVars.menuMouseActive := False;
      HighlightLine(selectionIndex);
      hMenu := menu;
      hasNext := False;
      hasPrev := False;
      optionCount := registeredCount;
      slotCursor := ShortInt(initial) + 1;
      if (not hasNext) and hasPrev and (GDVars.horizChoice > 1) then
        Inc(GDVars.horizChoice);
      if count - rows > GDVars.vertTop then begin
        hMenu := hMenu + GDConsts.nextText;
        nextSlot := slotCursor;
        MenuCore.AppendSlot(slotCursor, optionCount);
        Inc(slotCursor);
        hasNext := True;
      end;
      if GDVars.vertTop > headerCnt then begin
        hMenu := hMenu + GDConsts.prevText;
        prevSlot := slotCursor;
        MenuCore.AppendSlot(slotCursor, optionCount);
        Inc(slotCursor);
        hasPrev := True;
      end;
      if addExit then begin
        hMenu := hMenu + GDConsts.exitText;
        exitSlot := slotCursor;
        MenuCore.AppendSlot(slotCursor, optionCount);
        Inc(slotCursor);
      end;
      ch := MenuCore.MenuHorizontal(query, hMenu, Byte(True), Byte(False));
      prevCh := ch;
      if not GDVars.menuReturnedKey then
        if Ord(ch) > registeredCount - 1 then begin
          GDVars.menuReturnedKey := True;
          if (ch = Char(nextSlot)) and hasNext then
            prevCh := C_Keys.PAGE_DOWN
          else if (ch = Char(prevSlot)) and hasPrev then
            prevCh := C_Keys.PAGE_UP
          else if ch = Char(exitSlot) then
            prevCh := C_Keys.ESCAPE
          else
            GDVars.menuReturnedKey := False;
        end;
      UnhighlightLine(selectionIndex);
      if GDVars.menuReturnedKey then
        { 'P' is the DOWN key's code, so its label is never reached. }
        case prevCh of
          C_Keys.UP: MoveLine(False);
          C_Keys.DOWN: MoveLine(True);
          C_Keys.PAGE_UP: if hasPrev then MovePage(False);
          C_Keys.PAGE_DOWN: if hasNext then MovePage(True);
          'P': MovePage(False);
          'N': MovePage(True);
          C_Keys.ESCAPE, 'E', #0:
            begin
              Pointer(selection) := nil;
              MenuVertical := C_Keys.ESCAPE;
              GDVars.menuKeyColLo := 127;
              GDVars.menuKeyColHi := -128;
              Exit;
            end;
        end else if (GDVars.mouseClicked) and GDVars.menuMouseActive then begin
        mouseCellRow := GDVars.mouseY div 8;
        mouseCellCol := GDVars.mouseX div 8;
        if mouseCellCol >= GDVars.menuKeyColLo then
          if mouseCellCol <= GDVars.menuKeyColHi then begin
            line := 1;
            while (line <= 25) and (GDVars.menuHotRows[line] <> 255) do begin
              if GDVars.menuHotRows[line] = mouseCellRow then begin
                clickedIdx := line - 1 + GDVars.vertTop;
                if clickedIdx = selectionIndex then begin
                  SelectLine;
                  Exit;
                end else begin
                  UnhighlightLine(selectionIndex);
                  selectionIndex := line - 1 + GDVars.vertTop;
                  HighlightLine(selectionIndex);
                end;
              end;
              Inc(line);
            end;
          end;
      end else begin
        SelectLine;
        Exit;
      end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; defaultChoice: Byte): Byte;
var
  choice: Byte;
begin
  GDVars.horizChoice := defaultChoice + 1;
  MenuCore.ResetMenuSlots(1);
  repeat
    choice := Ord(MenuCore.MenuHorizontal(query, GDConsts.yesNoChoices, Byte(False), Byte(GDVars.eclPicShown)));
  until (choice >= 0) and (choice < 2);
  YesNoMenu := choice;
end;

procedure AllocStringList(nodeCount: Integer; var list: Pointer);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TItemRec));
  Types.PItemRec(list)^.next := nil;
  Types.PItemRec(list)^.inUse := 0;
  Types.PItemRec(list)^.name := '';
  p := Types.PItemRec(list);
  for i := 2 to nodeCount do begin
    GetMem(p^.next, SizeOf(Types.TItemRec));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Pointer);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := Types.PItemRec(list);
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TItemRec));
  end;
end;

{ Show the prompt on the bottom line and wait, animating, for Enter or Escape (at once with inputAbort); then wait for
  the mouse button's release.
  @param(fg The prompt's foreground color.)
  @param(bg The prompt's background color.)
  @param(query The prompt.) }
procedure WaitForContinue(fg, bg: Byte; query: Types.TStr40);
var
  animate: Byte;
  ch: Char;
  buttons: Integer;
  releaseX: Integer;
  releaseY: Integer;
begin
  GDVars.program5Flag := 1;
  TextRend.PrintSpaces(0, 24, Black, 40);
  if GDVars.inputAbort then Exit;
  TextRend.DisplayString(0, 24, fg, bg, query);
  animate := 1;
  MenuCore.InitializeAnimationTimers;
  ch := #0;
  repeat
    if GameIo.InputPending then
      ch := GameIo.ReadGameKey
    else
      MenuCore.UpdateAnimation(animate);
  until ch in [C_Keys.ENTER, C_Keys.ESCAPE];
  if GDVars.mouseClicked then
    repeat
      Mouse.GetMouse(buttons, releaseX, releaseY);
    until buttons = 0;
end;

procedure WaitContinueClear;
begin
  GameIo.DrainKeys;
  MenuCore.WaitForContinue(15, 0, GDConsts.pressButtonPrompt);
  GDVars.clearRectHook(0, 24, 39, 24);
end;

begin
end.
